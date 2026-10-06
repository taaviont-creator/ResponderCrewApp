const {test}=require('node:test');
const assert=require('node:assert/strict');
const {assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,Timestamp}=require('firebase/firestore');
module.exports=({getEnv,serverDb,serverRequire})=>{
  const org='approved-org',uid='active-member';
  const req=(action,fields={},user=uid,organizationId=org)=>({auth:{uid:user},data:{action,organizationId,...fields}});
  async function setup() {
    const db=serverDb(); let time=Date.now();
    await db.doc(`commands/${org}`).update({primaryRescueBaseId:'geo-base'});
    await db.doc('rescueBases/geo-base').set({organizationId:org,position:{latitude:59.4,longitude:26.5},positionVerifiedAt:new Date(time)});
    const h=serverRequire('./geofence').createGeofence({db,now:()=>time});
    await h.handle(req('save',{enabled:true,innerMeters:3000,outerMeters:8000,delayMinutes:30,expectedRevision:0},'org-admin'));
    const started=await h.handle(req('enable'));
    const sessionId=started.state.sessionId;
    return {db,h,sessionId,tick:(ms=1000)=>(time+=ms),now:()=>time,
      state:async()=>(await db.doc(`geofenceStates/${uid}_${org}`).get()).data(),
      availability:async()=>(await db.doc(`availability/${uid}_${org}`).get()).data()};
  }
  test('geofence: own consent, planned absence, replay ordering and return confirmation',async()=>{
    const x=await setup(),{h,sessionId,db}=x;
    const send=zone=>h.handle(req('event',{sessionId,zone,observedAtMs:x.tick()}));
    await send('inner');
    assert.equal((await x.availability()).status,'offDuty');
    await db.doc('plannedUnavailability/geo-plan').set({organizationId:org,userId:uid,status:'active',startAt:new Date(x.now()-10000),endAt:new Date(x.now()+60000)});
    await assert.rejects(h.handle(req('confirm',{sessionId,observedAtMs:x.now()})),{code:'failed-precondition'});
    await db.doc('plannedUnavailability/geo-plan').delete();
    await h.handle(req('confirm',{sessionId,observedAtMs:x.now()}));
    assert.equal((await x.availability()).status,'onDuty');
    await send('ring'); assert.equal((await x.availability()).responseMinutes,30);
    const old=x.now(); await send('outside');
    await h.handle(req('event',{sessionId,zone:'inner',observedAtMs:old}));
    assert.equal((await x.availability()).status,'offDuty');
    await send('inner'); assert.equal((await x.state()).confirmationRequired,true);
    await assert.rejects(h.handle(req('event',{sessionId,zone:'inner',observedAtMs:x.now()-200000})),{code:'failed-precondition'});
    await assert.rejects(h.handle(req('event',{sessionId,zone:'inner',observedAtMs:x.now(),latitude:59})),{code:'invalid-argument'});
  });
  test('geofence: manual status pauses automation and stale sessions cannot revive it',async()=>{
    const x=await setup();
    await x.db.doc(`availability/${uid}_${org}`).update({status:'offDuty',updatedAt:new Date(x.tick()),geofenceAppliedAt:null,geofenceUntil:null});
    await x.h.handle(req('event',{sessionId:x.sessionId,zone:'ring',observedAtMs:x.tick()}));
    assert.equal((await x.state()).enabled,false); assert.equal((await x.availability()).status,'offDuty');
    const next=await x.h.handle(req('enable'));
    await assert.rejects(x.h.handle(req('event',{sessionId:x.sessionId,zone:'ring',observedAtMs:x.tick()})),{code:'failed-precondition'});
    await x.h.handle(req('disable',{sessionId:x.sessionId}));
    assert.equal((await x.state()).sessionId,next.state.sessionId); assert.equal((await x.state()).enabled,true);
    x.tick(86400000); await x.h.expire();
    assert.equal((await x.state()).reason,'stale'); assert.equal((await x.availability()).status,'offDuty');
  });
  test('geofence: active callout preserves status, changed base invalidates monitoring',async()=>{
    const x=await setup(),{h,db,sessionId}=x;
    await h.handle(req('event',{sessionId,zone:'inner',observedAtMs:x.tick()}));
    await h.handle(req('confirm',{sessionId,observedAtMs:x.now()}));
    await db.doc('callouts/geo-callout').set({organizationId:org,status:'active'});
    await db.doc(`calloutResponses/geo-callout_${uid}`).set({organizationId:org,userId:uid,response:'responding'});
    await h.handle(req('event',{sessionId,zone:'outside',observedAtMs:x.tick()}));
    assert.equal((await x.availability()).status,'onDuty'); assert.equal((await x.state()).reason,'callout');
    await db.doc('callouts/geo-callout').update({status:'closed'});
    await h.handle(req('enable'));
    await db.doc('rescueBases/geo-base').update({position:{latitude:59.5,longitude:26.5}});
    await h.expire(); assert.equal((await x.state()).reason,'configuration');
  });
  test('geofence: org isolation, no role escalation or direct client leases/private state writes',async()=>{
    const x=await setup();
    await assert.rejects(x.h.handle(req('get',{},'outsider')),{code:'permission-denied'});
    await assert.rejects(x.h.handle(req('get',{},uid,'other-org')),{code:'permission-denied'});
    await assert.rejects(x.h.handle(req('save',{enabled:true,innerMeters:3000,outerMeters:8000,delayMinutes:30,expectedRevision:1})),{code:'permission-denied'});
    const own=getEnv().authenticatedContext(uid).firestore(), admin=getEnv().authenticatedContext('org-admin').firestore();
    await assertSucceeds(getDoc(doc(own,`geofenceStates/${uid}_${org}`)));
    await assertFails(getDoc(doc(admin,`geofenceStates/${uid}_${org}`)));
    await assertFails(updateDoc(doc(own,`geofenceStates/${uid}_${org}`),{enabled:true}));
    await assertFails(setDoc(doc(admin,`organizationGeofenceSettings/${org}`),{enabled:true}));
    await assertFails(updateDoc(doc(own,`availability/${uid}_${org}`),{geofenceUntil:Timestamp.fromMillis(Date.now()+99999999)}));
    await assertSucceeds(updateDoc(doc(own,`availability/${uid}_${org}`),{status:'offDuty',geofenceUntil:null,geofenceAppliedAt:null}));
  });
};
