const {test}=require('node:test');
const assert=require('node:assert/strict');
const {assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc}=require('firebase/firestore');
module.exports=({getEnv,serverDb,serverRequire})=>{
  const req=(data={},uid='org-admin')=>({auth:{uid},data});
  const sharing=(patch={})=>({organizationId:'approved-org',centerId:'merevalvekeskus',enabled:true,expectedRevision:0,...patch});
  const setup=async()=>{
    const db=serverDb(),{FieldValue,GeoPoint}=serverRequire('firebase-admin/firestore');
    let now=Date.now();
    const h=serverRequire('./center-board').createCenterBoardHandlers({db,timestamp:()=>FieldValue.serverTimestamp(),now:()=>now});
    await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
    await db.doc('centers/merevalvekeskus').set({active:true,services:['sar']});
    await db.doc('centers/tross').set({active:true,services:['tross']});
    await db.doc('centerAccess/center/grants/merevalvekeskus').set({active:true,services:['sar'],validUntil:null});
    await db.doc('commands/approved-org').update({primaryRescueBaseId:'base',dutyPauseReason:'PRIVATE REASON'});
    await db.doc('rescueBases/base').set({organizationId:'approved-org',active:true,position:new GeoPoint(59.45,26.5),positionVerifiedAt:FieldValue.serverTimestamp()});
    await db.doc('equipment/boat').set({organizationId:'approved-org',category:'vessel',scope:'organization',name:'Alus',status:'ok',note:'PRIVATE NOTE'});
    await db.doc('organizationReadinessSummaries/approved-org').set({minimumCrewRequired:3});
    await db.doc('organizationResponseSettings/approved-org').set({revision:1,contactName:'Avalik valvekontakt',contactPhone:'123',
      services:{sar:{enabled:true,departureMinutes:15,vesselIds:['boat']},tross:{enabled:true,departureMinutes:60,vesselIds:['boat'],minimumResponders:1}}});
    const board=(centerId='merevalvekeskus',uid='center')=>h.getCenterReadinessBoard(req({centerId},uid));
    const publish=async()=>{
      await h.setOrganizationCenterSharing(req(sharing()));
      await h.reviewOrganizationCenterSharing(req(sharing({expectedRevision:1}),'platform-only'));
    };
    return {db,h,board,publish,advance:ms=>{now+=ms;}};
  };
  test('center board: only explicitly requested and platform-approved organizations appear; no personal info or guessed readiness',async()=>{
    const {db,h,board,publish}=await setup();
    assert.equal((await board()).items.length,0);
    await publish();
    const result=await board(),row=result.items[0];
    assert.equal(row.id,'approved-org');assert.equal(row.latitude,59.45);assert.equal(row.status,'unavailable'); // Known crew shortage is red without a separate confirmation.
    assert.ok(row.reasons.some(reason=>reason.includes('3')));
    assert.equal(row.contactName,'Avalik valvekontakt');
    await db.doc('rescueBases/base').update({positionVerifiedAt:null});
    assert.equal((await board()).items[0].latitude,59.45); // Existing saved coordinates need no second confirmation.
    assert.equal((await h.getOrganizationCenterSharing(req({organizationId:'approved-org'}))).positionReady,true);
    const payload=JSON.stringify(result);
    assert.ok(!payload.includes('PRIVATE'));assert.ok(!payload.includes('org-admin'));assert.ok(!payload.includes('active-member'));
    await db.doc('rescueBases/base').update({organizationId:'other-org'});
    assert.equal((await board()).items[0].latitude,null);
    await h.setOrganizationCenterSharing(req(sharing({enabled:false,expectedRevision:2})));
    assert.equal((await board()).items.length,0);
    await h.setOrganizationCenterSharing(req(sharing({expectedRevision:3})));
    assert.equal((await board()).items.length,0); // Re-request requires a new platform approval.
  });
  test('center board: wrong roles/services, expired or revoked grants and direct access are denied',async()=>{
    const {db,h,board,publish,advance}=await setup();
    await publish();
    for(const uid of ['active-member','org-admin','platform-only','outsider']) await assert.rejects(board('merevalvekeskus',uid),{code:'permission-denied'});
    await assert.rejects(board('tross'),{code:'permission-denied'});
    await assert.rejects(h.setOrganizationCenterSharing(req(sharing(),'active-member')),{code:'permission-denied'});
    await assert.rejects(h.reviewOrganizationCenterSharing(req(sharing({expectedRevision:2})) ),{code:'permission-denied'});
    const {Timestamp}=serverRequire('firebase-admin/firestore');
    await db.doc('centerAccess/center/grants/merevalvekeskus').update({validUntil:Timestamp.fromMillis(Date.now()+1000)});
    advance(2000);await assert.rejects(board(),{code:'permission-denied'});
    await db.doc('centerAccess/center/grants/merevalvekeskus').update({validUntil:null,active:false});
    await assert.rejects(board(),{code:'permission-denied'});
    for(const uid of ['center','org-admin','platform-only']) {
      const client=getEnv().authenticatedContext(uid).firestore();
      await assertFails(getDoc(doc(client,'organizationCenterPublication/approved-org_merevalvekeskus')));
      await assertFails(setDoc(doc(client,'organizationCenterPublication/approved-org_merevalvekeskus'),{approved:true}));
    }
  });
  test('center sharing: no forced approval without consent, revision guard, foreign org prevention and audited withdrawal',async()=>{
    const {db,h,publish,board}=await setup();
    await assert.rejects(h.reviewOrganizationCenterSharing(req(sharing(),'platform-only')),{code:'failed-precondition'});
    await assert.rejects(h.setOrganizationCenterSharing(req(sharing({organizationId:'other-org'}))),{code:'permission-denied'});
    await assert.rejects(h.setOrganizationCenterSharing(req({...sharing(),approved:true})),{code:'invalid-argument'});
    await publish();
    await assert.rejects(h.setOrganizationCenterSharing(req(sharing())),{code:'aborted'});
    await h.reviewOrganizationCenterSharing(req(sharing({enabled:false,expectedRevision:2}),'platform-only'));
    assert.equal((await board()).items.length,0);
    assert.equal((await db.collection('platformAudit').where('action','==','centerPublication.reviewed').get()).size,2);
  });
};
