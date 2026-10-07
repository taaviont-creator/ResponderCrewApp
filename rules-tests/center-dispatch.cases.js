const {test}=require('node:test');
const assert=require('node:assert/strict');
const {assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,collection,query,where,getDocs}=require('firebase/firestore');
module.exports=({getEnv,serverDb,serverRequire})=>{
  const request=(uid,data)=>({auth:{uid},data});
  async function setup(){
    const db=serverDb(),{FieldValue}=serverRequire('firebase-admin/firestore');
    const h=serverRequire('./center-dispatch').createCenterDispatch({db,timestamp:()=>FieldValue.serverTimestamp()});
    await db.doc('centers/merevalvekeskus').set({active:true,services:['sar']});
    await db.doc('centerAccess/dispatcher/grants/merevalvekeskus').set({active:true,services:['sar'],validUntil:null,canDispatch:true});
    for(const org of ['approved-org','other-org','third-org']){
      await db.doc(`commands/${org}`).set({status:'approved',name:org});
      await db.doc(`organizationCenterPublication/${org}_merevalvekeskus`).set({organizationId:org,centerId:'merevalvekeskus',requested:true,approved:true});
      await db.doc(`organizationResponseSettings/${org}`).set({services:{sar:{enabled:true}}});
    }
    const data={action:'create',requestId:'dispatch-test',centerId:'merevalvekeskus',title:'Lapsed madratsil',description:'Aa rannast läksid lapsed merele. Asukoht teadmata.',location:'',position:null,positionKind:'unknown',targets:[{organizationId:'approved-org'},{organizationId:'other-org'}]};
    const result=await h.handle(request('dispatcher',data));
    const ref=db.doc(`dispatchIncidents/${result.incidentId}`);
    const incident=(await ref.get()).data(), assignments=(await ref.collection('assignments').get()).docs.map(d=>d.data());
    const update={action:'update',requestId:'update-1',centerId:'merevalvekeskus',incidentId:incident.id,expectedRevision:1,
      title:incident.title,description:incident.description,location:'',position:null,positionKind:'unknown',status:'active',message:'Uus vaatlus ranna lähedal',critical:false};
    return {db,h,data,ref,incident,assignments,update};
  }
  test('dispatch unknown location, two independent callouts/logs, idempotent create and no unauthorized targets',async()=>{
    const {db,h,data,incident,assignments}=await setup();
    assert.equal(incident.position,null);assert.equal(assignments.length,2);
    assert.equal(new Set(assignments.map(a=>a.calloutId)).size,2);
    for(const a of assignments){
      const log=(await db.doc(`operationLogs/callout_${a.calloutId}_created`).get()).data();
      assert.equal(log.organizationId,a.organizationId);assert.equal(log.calloutId,a.calloutId);
    }
    assert.equal((await h.handle(request('dispatcher',data))).incidentId,incident.id);
    assert.equal((await db.collection('callouts').get()).size,2);
    await assert.rejects(h.handle(request('dispatcher',{...data,title:'other'})),{code:'already-exists'});
    await assert.rejects(h.handle(request('active-member',{...data,requestId:'forged'})),{code:'permission-denied'});
    await assert.rejects(h.handle(request('dispatcher',{...data,requestId:'foreign',targets:[...data.targets,{organizationId:'hidden'}]})),{code:'permission-denied'});
    assert.equal((await db.collection('callouts').get()).size,2);
  });
  test('dispatch common radio and responder information projects to both organizations without changing their logs',async()=>{
    const {db,h,assignments,update}=await setup();
    const beforeLogs=await Promise.all(assignments.map(a=>db.doc(`operationLogs/callout_${a.calloutId}_created`).get()));
    await h.handle(request('dispatcher',{...update,description:'Punane rakett umbes 2 miili kaugusel',position:{latitude:59.45,longitude:27.02},positionKind:'approximate'}));
    for(const a of assignments){const c=(await db.doc(`callouts/${a.calloutId}`).get()).data();assert.equal(c.description,'Punane rakett umbes 2 miili kaugusel');assert.equal(c.dispatch.revision,2);}
    await h.handle(request('dispatcher',{...update,requestId:'radio',expectedRevision:2,radioChannel:'VHF 16',otherResponders:'PPA alus'}));
    for(const a of assignments){
      const c=(await db.doc(`callouts/${a.calloutId}`).get()).data();
      assert.equal(c.dispatch.radioChannel,'VHF 16');assert.equal(c.dispatch.otherResponders,'PPA alus');assert.equal(c.dispatch.task,undefined);
    }
    await assert.rejects(h.handle(request('dispatcher',{...update,requestId:'targeted',expectedRevision:3,targetOrganizationId:assignments[0].organizationId})),{code:'invalid-argument'});
    await assert.rejects(h.handle(request('dispatcher',{...update,requestId:'stale'})),{code:'aborted'});
    for(let i=0;i<assignments.length;i++)assert.deepEqual((await db.doc(`operationLogs/callout_${assignments[i].calloutId}_created`).get()).data(),beforeLogs[i].data());
  });
  test('dispatch adding a third organization never re-alarms existing organizations',async()=>{
    const {db,h,ref,incident,assignments}=await setup();
    await h.handle(request('dispatcher',{action:'addTargets',requestId:'add',centerId:'merevalvekeskus',incidentId:incident.id,expectedRevision:1,targets:[{organizationId:'third-org'}]}));
    assert.equal((await ref.collection('assignments').get()).size,3);
    assert.equal((await db.collection('callouts').get()).size,3);
    for(const a of assignments){
      const c=(await db.doc(`callouts/${a.calloutId}`).get()).data();
      assert.equal(c.dispatch.revision,1);assert.equal(c.dispatch.organizations.length,3);
    }
    await assert.rejects(h.handle(request('dispatcher',{action:'addTargets',requestId:'repeat',centerId:'merevalvekeskus',incidentId:incident.id,expectedRevision:2,targets:[{organizationId:'approved-org'}]})),{code:'already-exists'});
  });
  test('dispatch acceptance is org/admin-or-level2 scoped, does not accept peer assignments, and protects concurrency',async()=>{
    const {db,h,ref,incident,assignments}=await setup();
    const d={action:'respond',requestId:'reply',incidentId:incident.id,organizationId:'approved-org',expectedRevision:1,expectedResponse:'pending',response:'accepted',reason:''};
    await assert.rejects(h.handle(request('active-member',d)),{code:'permission-denied'});
    await h.handle(request('org-admin',d));
    assert.equal((await ref.collection('assignments').doc('approved-org').get()).data().response,'accepted');
    assert.equal((await ref.collection('assignments').doc('other-org').get()).data().response,'pending');
    for(const a of assignments){
      const shared=(await db.doc(`callouts/${a.calloutId}`).get()).data().dispatch.organizations;
      assert.equal(shared.find(o=>o.organizationId==='approved-org').response,'accepted');
      assert.equal(shared.find(o=>o.organizationId==='other-org').response,'pending');
      assert.deepEqual(Object.keys(shared[0]).sort(),['name','organizationId','response']);
    }
    await assert.rejects(h.handle(request('org-admin',{...d,requestId:'stale',response:'declined',reason:'Ei saa'})),{code:'aborted'});
    await assert.rejects(h.handle(request('org-admin',{...d,requestId:'foreign',organizationId:'other-org'})),{code:'permission-denied'});
  });
  test('dispatch cancellation notifies all but never closes organization logs or marks vessels at base',async()=>{
    const {db,h,assignments,update}=await setup();
    await h.handle(request('dispatcher',{...update,status:'cancelled',message:'Lapsed leitud kaldalt'}));
    for(const a of assignments){
      const c=(await db.doc(`callouts/${a.calloutId}`).get()).data();
      assert.equal(c.dispatch.incidentStatus,'cancelled');assert.equal(c.status,'active');
      assert.equal((await db.doc(`operationLogs/callout_${a.calloutId}_created`).get()).data().status,'open');
    }
    assert.equal((await db.collection('dispatchUpdateEvents').get()).size,2);
  });
  test('dispatch rules isolate centers, grants and organizations; derived fields cannot be forged',async()=>{
    const {db,ref,assignments,h,update}=await setup(),env=getEnv();
    const center=env.authenticatedContext('dispatcher').firestore(),admin=env.authenticatedContext('org-admin').firestore(),member=env.authenticatedContext('active-member').firestore();
    await assertSucceeds(getDocs(query(collection(center,'dispatchIncidents'),where('centerId','==','merevalvekeskus'))));
    await assertSucceeds(getDocs(collection(center,`${ref.path}/assignments`)));
    await assertFails(getDoc(doc(member,ref.path)));
    await assertFails(getDoc(doc(env.authenticatedContext('outsider').firestore(),ref.path)));
    const own=assignments.find(a=>a.organizationId==='approved-org'),other=assignments.find(a=>a.organizationId==='other-org');
    await assertSucceeds(getDoc(doc(member,`callouts/${own.calloutId}`)));
    await assertFails(getDoc(doc(member,`callouts/${other.calloutId}`)));
    await assertFails(updateDoc(doc(admin,`callouts/${own.calloutId}`),{'dispatch.response':'accepted'}));
    await assertFails(setDoc(doc(center,ref.path),{title:'Injected'}));
    await assertFails(getDoc(doc(center,`operationLogs/callout_${own.calloutId}_created`)));
    await h.handle(request('dispatcher',update));
    await assertSucceeds(getDoc(doc(member,`callouts/${own.calloutId}/centerUpdates/2`)));
    await assertFails(getDoc(doc(member,`callouts/${other.calloutId}/centerUpdates/2`)));
    await db.doc('centerAccess/dispatcher/grants/merevalvekeskus').update({canDispatch:false});
    await assertFails(getDoc(doc(center,ref.path)));
    await assert.rejects(h.handle(request('dispatcher',{...update,requestId:'revoked',expectedRevision:2})),{code:'permission-denied'});
  });
  test('dispatch progress uses current own log and responses without sharing full operational content',async()=>{
    const {db,h,ref,assignments}=await setup(),a=assignments[0];
    await db.doc(`operationLogs/callout_${a.calloutId}_created`).update({status:'enRoute',description:'Private crew note'});
    await db.doc(`calloutResponses/response`).set({calloutId:a.calloutId,organizationId:a.organizationId,response:'responding'});
    await h.syncProgress({params:{calloutId:a.calloutId},data:{after:{data:()=>({})}}});
    const result=(await ref.collection('assignments').doc(a.organizationId).get()).data();
    assert.equal(result.progress,'enRoute');assert.equal(result.responseCounts.responding,1);assert.equal(result.description,undefined);
    assert.equal((await ref.collection('assignments').doc(assignments[1].organizationId).get()).data().progress,'open');
  });
  test('dispatch phone fallback adopts the existing callout and log without creating a second alarm source',async()=>{
    const {db,h,incident}=await setup();
    await db.doc('callouts/phone-call').set({id:'phone-call',organizationId:'third-org',commandId:'third-org',phoneCenterId:'merevalvekeskus',
      title:'Telefonikõne',description:'Algne teade',location:'',status:'active',calloutType:'sar',isTest:false});
    const log={organizationId:'third-org',calloutId:'phone-call',status:'enRoute',description:'Meie logi'};
    await db.doc('operationLogs/callout_phone-call_created').set(log);
    await h.handle(request('dispatcher',{action:'addTargets',requestId:'link-phone',centerId:'merevalvekeskus',incidentId:incident.id,expectedRevision:1,
      targets:[{organizationId:'third-org',existingCalloutId:'phone-call'}]}));
    assert.equal((await db.collection('callouts').get()).size,3);
    assert.deepEqual((await db.doc('operationLogs/callout_phone-call_created').get()).data(),log);
    assert.equal((await db.doc('callouts/phone-call').get()).data().dispatch.incidentId,incident.id);
    assert.equal((await db.doc(`dispatchIncidents/${incident.id}/assignments/third-org`).get()).data().calloutId,'phone-call');
  });
  test('dispatch center-owned fields cannot be changed via existing admin amendment endpoint',async()=>{
    const {db,assignments}=await setup();
    const a=assignments.find(a=>a.organizationId==='approved-org');
    const amend=serverRequire('./callout-report').createAmendCalloutHandler({db,timestamp:()=>new Date()});
    await assert.rejects(amend(request('org-admin',{organizationId:'approved-org',calloutId:a.calloutId,title:'Hacked',description:'Different',location:'Elsewhere',version:0})),{code:'permission-denied'});
  });
  test('dispatch capabilities default off and can only be granted by platform through audited handler',async()=>{
    const {db}=await setup(),{FieldValue,Timestamp}=serverRequire('firebase-admin/firestore');
    const h=serverRequire('./center-access').createCenterAccessHandlers({db,timestamp:()=>FieldValue.serverTimestamp(),fromMillis:Timestamp.fromMillis});
    await db.doc('users/platform-dispatch').set({systemRole:'platformAdmin'});await db.doc('users/reader').set({systemRole:'user'});
    const change={userId:'reader',centerId:'merevalvekeskus',active:true,expectedRevision:0};
    await h.setCenterAccess(request('platform-dispatch',change));
    assert.equal((await h.getCenterContexts(request('reader',{}))).contexts[0].canDispatch,false);
    await assert.rejects(h.setCenterAccess(request('reader',{...change,expectedRevision:1,canDispatch:true})),{code:'permission-denied'});
    await h.setCenterAccess(request('platform-dispatch',{...change,expectedRevision:1,canDispatch:true}));
    assert.equal((await h.getCenterContexts(request('reader',{}))).contexts[0].canDispatch,true);
    await h.setCenterAccess(request('platform-dispatch',{...change,expectedRevision:2,active:false}));
    assert.equal((await db.doc('centerAccess/reader/grants/merevalvekeskus').get()).data().canDispatch,false);
  });

  test('quick shared update needs only the new information, preserves radio/location and reaches every organization',async()=>{
    const {db,h,incident,assignments,update}=await setup();
    await h.handle(request('dispatcher',{...update,radioChannel:'VHF 16',otherResponders:'PPA alus'}));
    const data={action:'append',requestId:'append',centerId:'merevalvekeskus',incidentId:incident.id,expectedRevision:2,message:'Lapsi nähti muuli juures',critical:false};
    await h.handle(request('dispatcher',data));
    await h.handle(request('dispatcher',data));
    for(const a of assignments){
      const c=(await db.doc(`callouts/${a.calloutId}`).get()).data();
      assert.equal(c.description,incident.description);assert.equal(c.dispatch.radioChannel,'VHF 16');assert.equal(c.dispatch.otherResponders,'PPA alus');
      assert.equal(c.dispatch.message,data.message);assert.equal(c.dispatch.revision,3);
    }
  });
  test('unacknowledged critical information survive later routine updates and stale acknowledgements fail',async()=>{
    const {db,h,incident,assignments,update}=await setup();
    const own=assignments.find(a=>a.organizationId==='approved-org');
    await h.handle(request('dispatcher',{...update,critical:true,message:'Muudetud otsinguala: ida pool'}));
    await h.handle(request('dispatcher',{...update,requestId:'routine',expectedRevision:2,message:'Kontakt täpsustamisel'}));
    let c=(await db.doc(`callouts/${own.calloutId}`).get()).data();
    assert.equal(c.dispatch.critical,true);assert.equal(c.dispatch.criticalMessage,'Muudetud otsinguala: ida pool');assert.equal(c.dispatch.revision,3);
    const ack={action:'acknowledge',incidentId:incident.id,organizationId:'approved-org',requestId:'ack',expectedRevision:2};
    await assert.rejects(h.handle(request('org-admin',ack)),{code:'aborted'});
    await h.handle(request('org-admin',{...ack,requestId:'ack-new',expectedRevision:3}));
    c=(await db.doc(`callouts/${own.calloutId}`).get()).data();assert.equal(c.dispatch.acknowledgedRevision,3);
    assert.equal((await db.doc(`dispatchIncidents/${incident.id}/assignments/other-org`).get()).data().acknowledgedRevision,0);
  });

};
