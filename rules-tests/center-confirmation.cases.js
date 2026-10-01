const {test} = require('node:test');
const assert = require('node:assert/strict');
const {assertFails} = require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc} = require('firebase/firestore');
module.exports = ({getEnv,serverDb,serverRequire}) => {
  const org = 'approved-org';
  const request = (data,uid='org-admin') => ({auth:{uid},data:{organizationId:org,...data}});
  const change = (patch={}) => ({service:'sar',action:'confirm',settingsRevision:1,expectedRevision:0,validForMinutes:720,delayMinutes:0,reason:'Valvekontakt kinnitas',...patch});
  async function setup() {
    const db = serverDb();
    const {Timestamp,FieldValue} = serverRequire('firebase-admin/firestore');
    let at = Date.now();
    const handlers = serverRequire('./organization-center-readiness').createOrganizationCenterReadinessHandlers({
      db,now:()=>at,fromMillis:Timestamp.fromMillis,timestamp:()=>FieldValue.serverTimestamp(),
    });
    await db.doc(`organizationReadinessSummaries/${org}`).set({minimumCrewRequired:3});
    await db.doc(`organizationResponseSettings/${org}`).set({revision:1,services:{
      sar:{enabled:true,departureMinutes:15,vesselIds:[]},tross:{enabled:true,departureMinutes:60,minimumResponders:1,vesselIds:[]},
    }});
    return {db,handlers,advance:ms=>at+=ms};
  }
  test('confirmation: only an active organization admin can write; members can read own projection',async()=>{
    const {db,handlers:h} = await setup();
    await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
    for (const uid of ['active-member','platform-only','outsider']) {
      await assert.rejects(h.setOrganizationReadinessConfirmation(request(change(),uid)),{code:'permission-denied'});
    }
    await assert.rejects(h.setOrganizationReadinessConfirmation(request({...change(),organizationId:'other-org'})),{code:'permission-denied'});
    await h.setOrganizationReadinessConfirmation(request(change()));
    const member = await h.getOrganizationCenterReadiness(request({},'active-member'));
    assert.equal(member.canManage,false);
    assert.equal(member.entries[0].confirmation.revision,1);
    assert.equal(member.entries[0].status,'unavailable'); // Known missing crew/boat stays red, even with pending positive proof.
    assert.equal(member.entries[1].confirmation.confirmedAtMs,null); // Independent services.
    for (const uid of ['org-admin','active-member','platform-only']) {
      const client=getEnv().authenticatedContext(uid).firestore();
      await assertFails(getDoc(doc(client,`organizationReadinessConfirmations/${org}_sar`)));
      await assertFails(setDoc(doc(client,`organizationReadinessConfirmations/${org}_sar`),{status:'ready'}));
    }
    await assert.rejects(h.getOrganizationCenterReadiness(request({},'outsider')),{code:'permission-denied'});
  });
  test('confirmation: revisions, input whitelist, disabled service, withdrawal and audit are enforced',async()=>{
    const {db,handlers:h} = await setup();
    for (const patch of [{status:'ready'},{validForMinutes:0},{validForMinutes:100000},{validForMinutes:null},
      {validityMode:'untilChanged'},{validityMode:'forever'},{delayMinutes:61},
      {action:'unavailable',delayMinutes:15},{service:'invalid'},{reason:'x'.repeat(241)}]) {
      await assert.rejects(h.setOrganizationReadinessConfirmation(request(change(patch))),{code:'invalid-argument'});
    }
    await h.setOrganizationReadinessConfirmation(request(change({delayMinutes:15})));
    await assert.rejects(h.setOrganizationReadinessConfirmation(request(change())),{code:'aborted'});
    await db.doc(`organizationResponseSettings/${org}`).update({revision:2,'services.sar.enabled':false});
    await assert.rejects(h.setOrganizationReadinessConfirmation(request(change({expectedRevision:1}))),{code:'aborted'});
    await assert.rejects(h.setOrganizationReadinessConfirmation(request(change({expectedRevision:1,settingsRevision:2}))),{code:'failed-precondition'});
    await h.setOrganizationReadinessConfirmation(request(change({action:'withdraw',expectedRevision:1,settingsRevision:2})));
    const row=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    assert.equal(row.confirmation.confirmedAtMs,null);
    assert.equal(row.confirmation.validUntilMs,null);
    assert.equal(row.restrictionReason,'');
    const audit=await db.collection('platformAudit').where('action','==','organization.readinessConfirmation').get();
    assert.equal(audit.size,2);
    assert.ok(audit.docs.every(d=>d.data().createdBy==='org-admin' && d.data().createdAt));
  });
  test('confirmation: organization and center share exactly the same result and expiry',async()=>{
    const {db,handlers:h,advance} = await setup();
    const {FieldValue}=serverRequire('firebase-admin/firestore');
    let at = Date.now();
    const center = serverRequire('./center-board').createCenterBoardHandlers({db,now:()=>at,timestamp:()=>FieldValue.serverTimestamp()});
    await db.doc('centers/merevalvekeskus').set({active:true,services:['sar']});
    await db.doc('centerAccess/center/grants/merevalvekeskus').set({active:true,services:['sar'],validUntil:null});
    await db.doc(`organizationCenterPublication/${org}_merevalvekeskus`).set({organizationId:org,centerId:'merevalvekeskus',requested:true,approved:true});
    await h.setOrganizationReadinessConfirmation(request(change({action:'unavailable',reason:'Hooaeg lõppenud'})));
    const own=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    const shared=(await center.getCenterReadinessBoard({auth:{uid:'center'},data:{centerId:'merevalvekeskus'}})).items[0];
    for (const key of ['status','reasons','onDutyCount','minimum','confirmedAtMs','confirmationValidUntilMs','restrictionReason']) assert.deepEqual(shared[key],own[key]);
    advance(13*3600000);at+=13*3600000;
    const expired=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    assert.equal(expired.status,'unavailable'); // An explicit closure stays red until the admin removes it.
    assert.ok(expired.reasons.some(r=>r.includes('aegunud')));
    await db.doc(`memberships/org-admin_${org}`).update({status:'inactive',isActive:false});
    await assert.rejects(h.setOrganizationReadinessConfirmation(request(change({expectedRevision:1}))),{code:'permission-denied'});
  });
  test('confirmation: automatic mode ignores obsolete positive confirmations but never bypasses actual minimum',async()=>{
    const {db,handlers:h,advance}=await setup();
    await h.setOrganizationReadinessConfirmation(request(change({validityMode:'untilChanged',validForMinutes:null})));
    advance(100*86400000);
    let row=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    assert.equal(row.confirmation.validityMode,'untilChanged');
    assert.equal(row.confirmation.validUntilMs,null);
    assert.equal(row.status,'unavailable');
    assert.ok(!row.reasons.some(r=>r.includes('aegunud')));
    assert.ok(row.freshUntilMs>row.computedAtMs);
    const audit=await db.collection('platformAudit').where('action','==','organization.readinessConfirmation').get();
    assert.equal(audit.docs[0].data().after.validityMode,'untilChanged');
    await db.doc(`organizationReadinessConfirmations/${org}_sar`).update({validUntil:'invalid legacy value'});
    row=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    assert.equal(row.confirmation.validityMode,'timed');
    assert.equal(row.status,'unavailable');
    await db.doc(`organizationReadinessConfirmations/${org}_sar`).update({validUntil:null});
    await db.doc(`organizationResponseSettings/${org}`).update({revision:2});
    row=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    assert.equal(row.status,'unavailable');
    await h.setOrganizationReadinessConfirmation(request(change({action:'withdraw',validityMode:'untilChanged',validForMinutes:null,settingsRevision:2,expectedRevision:1})));
    assert.equal((await h.getOrganizationCenterReadiness(request({}))).entries[0].confirmation.confirmedAtMs,null);
  });
  test('evidence: foreign duty does not subtract own responders; vessel identity and privacy remain enforced',async()=>{
    const {db,handlers:h}=await setup();
    const {FieldValue}=serverRequire('firebase-admin/firestore');
    await db.doc('availability/active-member_approved-org').set({organizationId:org,userId:'active-member',status:'onDuty'});
    await db.doc('commands/foreign-evidence').set({status:'approved',name:'PRIVATE OTHER ORGANIZATION'});
    await db.doc('memberships/active-member_foreign-evidence').set({organizationId:'foreign-evidence',userId:'active-member',status:'active',displayName:'PRIVATE PERSON'});
    await db.doc('availability/active-member_foreign-evidence').set({organizationId:'foreign-evidence',userId:'active-member',status:'onDuty'});
    await db.doc('equipment/evidence-boat').set({organizationId:org,category:'vessel',status:'ok',scope:'organization'});
    await db.doc(`organizationResponseSettings/${org}`).update({'services.sar.vesselIds':['evidence-boat']});
    await db.doc('centers/merevalvekeskus').set({active:true,services:['sar']});
    await db.doc('centerAccess/center/grants/merevalvekeskus').set({active:true,services:['sar'],validUntil:null});
    await db.doc(`organizationCenterPublication/${org}_merevalvekeskus`).set({organizationId:org,centerId:'merevalvekeskus',requested:true,approved:true});
    const center=serverRequire('./center-board').createCenterBoardHandlers({db,timestamp:()=>FieldValue.serverTimestamp()});
    const own=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    const shared=(await center.getCenterReadinessBoard({auth:{uid:'center'},data:{centerId:'merevalvekeskus'}})).items[0];
    assert.deepEqual(shared.reasons,own.reasons);
    assert.ok(!shared.reasons.some(r=>r.includes('teises ühingus')));
    assert.equal(shared.onDutyCount,own.onDutyCount);
    assert.ok(shared.reasons.some(r=>r.includes('identiteet')));
    assert.ok(!JSON.stringify(shared).includes('PRIVATE'));
    assert.ok(!JSON.stringify(shared).includes('active-member'));
    const {Timestamp}=serverRequire('firebase-admin/firestore');
    await db.doc('plannedUnavailability/foreign-absence').set({organizationId:'foreign-evidence',userId:'active-member',status:'active',startAt:Timestamp.fromMillis(Date.now()-60000),endAt:Timestamp.fromMillis(Date.now()+60000)});
    const after=(await h.getOrganizationCenterReadiness(request({}))).entries[0];
    assert.ok(!after.reasons.some(r=>r.includes('teises ühingus')));
  });
};
