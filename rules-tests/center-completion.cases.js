const {test} = require('node:test');
const assert = require('node:assert/strict');
const {assertFails} = require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc} = require('firebase/firestore');
module.exports = ({getEnv,serverDb,serverRequire}) => {
  const org='approved-org', uid='org-admin';
  const req=(data={},actor=uid,organizationId=org)=>({auth:{uid:actor},data:{organizationId,...data}});
  async function setup() {
    const db=serverDb(), {Timestamp,FieldValue}=serverRequire('firebase-admin/firestore');
    let at=Date.now();
    const deps={db,now:()=>at,timestamp:()=>FieldValue.serverTimestamp(),fromMillis:Timestamp.fromMillis};
    const resources=serverRequire('./center-resources').createCenterResourceHandlers(deps);
    const own=serverRequire('./organization-center-readiness').createOrganizationCenterReadinessHandlers(deps);
    const board=serverRequire('./center-board').createCenterBoardHandlers(deps);
    await db.doc(`organizationReadinessSummaries/${org}`).set({minimumCrewRequired:1});
    await db.doc(`availability/${uid}_${org}`).set({organizationId:org,userId:uid,status:'onDuty'});
    await db.doc('equipment/boat').set({organizationId:org,name:'Our boat',category:'vessel',status:'ok'});
    await db.doc(`organizationResponseSettings/${org}`).set({revision:1,services:{
      sar:{enabled:true,departureMinutes:15,vesselIds:['boat']},tross:{enabled:true,departureMinutes:60,minimumResponders:1,vesselIds:['boat']},
    }});
    await resources.saveCenterVesselIdentity(req({resourceId:'boat',country:'EE',registration:'TEST123',expectedRevision:0}));
    for(const service of ['sar','tross']) await own.setOrganizationReadinessConfirmation(req({service,action:'confirm',settingsRevision:1,
      expectedRevision:0,validityMode:'untilChanged',validForMinutes:null,delayMinutes:0,reason:''}));
    await db.doc('centers/merevalvekeskus').set({active:true,services:['sar']});
    await db.doc('centerAccess/center/grants/merevalvekeskus').set({active:true,services:['sar'],validUntil:null});
    await db.doc(`organizationCenterPublication/${org}_merevalvekeskus`).set({organizationId:org,centerId:'merevalvekeskus',requested:true,approved:true});
    return {db,resources,own,board,deps,Timestamp,advance:n=>at+=n,now:()=>at};
  }
  test('simple center settings: no duplicate confirmation, same map/phone status, pause wins and sharing stays gated',async()=>{
    const {db,own,board,deps}=await setup();
    for(const service of ['sar','tross']) await db.doc(`organizationReadinessConfirmations/${org}_${service}`).delete();
    const rows=async()=> (await own.getOrganizationCenterReadiness(req())).entries;
    assert.deepEqual((await rows()).map(r=>r.status),['ready','ready']);
    assert.ok((await rows()).every(r=>r.automatic && r.confirmedAtMs===null));
    const map=async()=> (await board.getCenterReadinessBoard({auth:{uid:'center'},data:{centerId:'merevalvekeskus'}})).items;
    assert.equal((await map())[0].status,'ready');
    await db.doc(`commands/${org}`).update({dutyPaused:true,dutyPauseReason:'Hooaeg läbi'});
    assert.deepEqual((await rows()).map(r=>r.status),['unavailable','unavailable']);
    assert.equal((await map())[0].status,'unavailable');
    assert.equal((await map())[0].restrictionReason,'Ühing on valvest maas.');
    assert.ok(!JSON.stringify(await map()).includes('Hooaeg läbi')); // Internal pause note is not automatically shared.
    const phone=await serverRequire('./readiness-availability').createReadinessAvailabilityHandler(deps)(req({},'active-member'));
    assert.equal(phone.operationalStatus,'unavailable');
    await db.doc(`commands/${org}`).update({dutyPaused:false});
    assert.equal((await map())[0].status,'ready');
    await db.doc(`organizationCenterPublication/${org}_merevalvekeskus`).update({approved:false});
    assert.deepEqual(await map(),[]);
    const sharing=await board.getOrganizationCenterSharing(req());
    assert.equal(sharing.positionReady,false);
    assert.equal(sharing.entries[0].requested,true);
    assert.equal(sharing.entries[0].approved,false);
  });
  test('complete center workflow: registration, indefinite confirmation, same phone/center result and member read access',async()=>{
    const {db,resources,own,board,deps}=await setup();
    const row=(await own.getOrganizationCenterReadiness(req({},'active-member'))).entries[0];
    assert.equal(row.status,'ready');
    const shared=(await board.getCenterReadinessBoard({auth:{uid:'center'},data:{centerId:'merevalvekeskus'}})).items[0];
    const phone=await serverRequire('./readiness-availability').createReadinessAvailabilityHandler(deps)(req({},'active-member'));
    assert.equal(phone.operationalStatus,row.status);
    assert.equal(shared.status,row.status);
    assert.equal(shared.latitude,null);
    assert.equal(phone.onDutyCount,shared.onDutyCount);
    assert.ok(!JSON.stringify(shared).includes(uid));
    for(const actor of ['active-member','outsider']) {
      await assert.rejects(resources.getOrganizationCenterResources(req({},actor)),{code:'permission-denied'});
      await assert.rejects(resources.saveCenterVesselIdentity(req({resourceId:'boat',country:'EE',registration:'TEST123',expectedRevision:1},actor)),{code:'permission-denied'});
      await assert.rejects(resources.setOrganizationCenterResource(req({resourceId:uid,kind:'member',action:'claim',expectedRevision:0},actor)),{code:'permission-denied'});
    }
    await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
    await assert.rejects(resources.getOrganizationCenterResources(req({},'platform-only')),{code:'permission-denied'});
    await db.doc('centerAccess/center/grants/merevalvekeskus').update({active:false});
    await assert.rejects(board.getCenterReadinessBoard({auth:{uid:'center'},data:{centerId:'merevalvekeskus'}}),{code:'permission-denied'});
  });
  test('complete center workflow: clock-only absence, qualification, vessel condition and independent SAR/Tross',async()=>{
    const {db,own,advance,now,Timestamp}=await setup();
    const rows=async()=> (await own.getOrganizationCenterReadiness(req())).entries.map(e=>e.status);
    await db.doc(`memberships/${uid}_${org}`).update({seaRescueLevel:'none'});
    assert.deepEqual(await rows(),['unavailable','ready']);
    await db.doc(`memberships/${uid}_${org}`).update({seaRescueLevel:'level2'});
    await db.doc('plannedUnavailability/clock-only').set({organizationId:org,userId:uid,status:'active',startAt:Timestamp.fromMillis(now()+1000),endAt:Timestamp.fromMillis(now()+2000)});
    advance(1000);assert.deepEqual(await rows(),['unavailable','unavailable']);
    advance(1000);assert.deepEqual(await rows(),['ready','ready']);
    await db.doc('equipment/boat').update({status:'broken'});
    assert.deepEqual(await rows(),['unavailable','unavailable']);
    await db.doc('equipment/boat').update({status:'ok'});
    await db.doc(`commands/${org}`).update({dutyPaused:true});
    assert.deepEqual(await rows(),['unavailable','unavailable']);
  });
  test('three own duty members count as three despite foreign duty and old assignments; member allocation is retired',async()=>{
    const {db,resources,own,board,deps}=await setup();
    await db.doc(`organizationReadinessSummaries/${org}`).update({minimumCrewRequired:3});
    for (const person of ['second','third']) {
      await db.doc(`memberships/${person}_${org}`).set({organizationId:org,userId:person,status:'active',role:'member',seaRescueLevel:'none'});
      await db.doc(`availability/${person}_${org}`).set({organizationId:org,userId:person,status:'onDuty'});
    }
    await db.doc('commands/other-org').set({status:'approved'});
    for (const person of [uid,'second']) {
      await db.doc(`memberships/${person}_other-org`).set({organizationId:'other-org',userId:person,status:'active',role:'member',seaRescueLevel:'none'});
      await db.doc(`availability/${person}_other-org`).set({organizationId:'other-org',userId:person,status:'onDuty'});
      await db.doc(`resourceAllocations/${serverRequire('./response-units').key('member',person)}`).set({organizationId:'other-org',kind:'member',resourceId:person,validityMode:'untilChanged',validUntil:null});
    }
    const row=(await own.getOrganizationCenterReadiness(req())).entries[0];
    const shared=(await board.getCenterReadinessBoard({auth:{uid:'center'},data:{centerId:'merevalvekeskus'}})).items[0];
    const phone=await serverRequire('./readiness-availability').createReadinessAvailabilityHandler(deps)(req({},'active-member'));
    assert.equal(row.onDutyCount,3);assert.equal(row.secondLevelCount,1);assert.equal(row.status,'ready');
    assert.equal(shared.onDutyCount,3);assert.equal(phone.onDutyCount,3);
    assert.ok((await resources.getOrganizationCenterResources(req())).entries.every(e=>e.kind==='vessel'));
    await assert.rejects(resources.setOrganizationCenterResource(req({kind:'member',resourceId:uid,action:'claim',expectedRevision:0})),{code:'failed-precondition'});
  });
  test('complete center workflow: shared boat identity, claim/release, immutable foreign allocation and no client writes',async()=>{
    const {db,resources,own}=await setup();
    await db.doc('commands/other-org').set({status:'approved'});
    await db.doc(`memberships/${uid}_other-org`).set({organizationId:'other-org',userId:uid,status:'active',role:'orgAdmin'});
    await db.doc('equipment/other-boat').set({organizationId:'other-org',name:'PRIVATE OTHER',category:'vessel',status:'ok'});
    await resources.saveCenterVesselIdentity(req({resourceId:'other-boat',country:'EE',registration:'test-123',expectedRevision:0},uid,'other-org'));
    await db.doc('organizationResponseSettings/other-org').set({services:{tross:{enabled:true,vesselIds:['other-boat']}}});
    assert.equal((await own.getOrganizationCenterReadiness(req())).entries[0].status,'unavailable');
    await resources.setOrganizationCenterResource(req({resourceId:'boat',kind:'vessel',action:'claim',expectedRevision:0}));
    assert.equal((await own.getOrganizationCenterReadiness(req())).entries[0].status,'ready');
    await assert.rejects(resources.saveCenterVesselIdentity(req({resourceId:'boat',country:'EE',registration:'CHANGED123',expectedRevision:1})),{code:'failed-precondition'});
    const foreign=await resources.getOrganizationCenterResources(req({},uid,'other-org'));
    assert.equal(foreign.entries.find(e=>e.resourceId==='other-boat').allocation,'other');
    await assert.rejects(resources.setOrganizationCenterResource(req({resourceId:'other-boat',kind:'vessel',action:'claim',expectedRevision:1},uid,'other-org')),{code:'failed-precondition'});
    const client=getEnv().authenticatedContext(uid).firestore();
    for(const collection of ['vesselIdentities','resourceAllocations','organizationOperationalReadiness']) {
      await assertFails(getDoc(doc(client,collection,'boat')));
      await assertFails(setDoc(doc(client,collection,'boat'),{organizationId:org,status:'ready'}));
    }
    const audit=await db.collection('platformAudit').where('action','==','center.resourceAllocation').get();
    assert.equal(audit.size,1);
    assert.equal(audit.docs[0].data().createdBy,uid);
  });
  test('readiness refresh renews freshness without invalidating pending alerts; real recovery suppresses the old alert', async()=>{
    const {db,deps,advance}=await setup();
    const {createReadinessEngine,createReadinessDelivery}=serverRequire('./organization-readiness');
    const engine=createReadinessEngine(deps);
    await engine.recompute(org);
    await db.doc(`availability/${uid}_${org}`).update({status:'offDuty'});
    await engine.recompute(org);
    const events=await db.collection('readinessNotificationEvents').get();
    assert.equal(events.size,1);
    const pending=events.docs[0], oldTime=(await db.doc(`organizationOperationalReadiness/${org}`).get()).data().computedAt.toMillis();
    advance(60000);
    await engine.recompute(org);
    const current=(await db.doc(`readinessNotificationState/${org}`).get()).data();
    assert.equal(current.fingerprint,pending.data().fingerprint);
    assert.ok((await db.doc(`organizationOperationalReadiness/${org}`).get()).data().computedAt.toMillis()>oldTime);
    assert.equal((await db.collection('readinessNotificationEvents').get()).size,1);
    const sent=[];
    const deliver=createReadinessDelivery({db,deliver:async d=>sent.push(d),preferencesFor:async()=>({belowMinimum:true})});
    const event={params:{eventId:pending.id},data:pending};
    await deliver(event);
    assert.ok(sent.some(d=>d.uid===uid));
    sent.length=0;
    await db.doc(`availability/${uid}_${org}`).update({status:'onDuty'});
    await engine.recompute(org);
    await deliver(event);
    assert.equal(sent.length,0);
  });
  test('complete center workflow: scheduler persists actual results and admin below-minimum event without automatic pause',async()=>{
    const {db,deps}=await setup();
    const engine=serverRequire('./organization-readiness').createReadinessEngine(deps);
    await engine.scheduled();
    let snapshot=(await db.doc(`organizationOperationalReadiness/${org}`).get()).data();
    assert.equal(snapshot.services[0].status,'ready');
    await db.doc(`availability/${uid}_${org}`).update({status:'offDuty'});
    await engine.scheduled();
    snapshot=(await db.doc(`organizationOperationalReadiness/${org}`).get()).data();
    assert.equal(snapshot.services[0].status,'unavailable');
    const events=await db.collection('readinessNotificationEvents').get();
    assert.equal(events.size,1);assert.ok(events.docs[0].data().keys.includes('belowMinimum'));
    assert.notEqual((await db.doc(`commands/${org}`).get()).data().dutyPaused,true);
    await engine.scheduled();
    assert.equal((await db.collection('readinessNotificationEvents').get()).size,1);
  });
};
