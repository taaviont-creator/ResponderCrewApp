const {test}=require('node:test');
const assert=require('node:assert/strict');
const {assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,deleteDoc}=require('firebase/firestore');
module.exports=({getEnv,serverDb,serverRequire})=>{
  const req=(data={},uid='org-admin',organizationId='approved-org')=>({auth:{uid},data:{organizationId,...data}});
  const value=(patch={})=>({expectedRevision:0,contactName:'Valvekontakt',contactPhone:'+37255555555',services:{
    sar:{enabled:true,departureMinutes:30,vesselIds:['boat']},tross:{enabled:true,departureMinutes:60,vesselIds:['boat'],minimumResponders:1},
  },...patch});
  const setup=async()=>{
    const db=serverDb(),{FieldValue}=serverRequire('firebase-admin/firestore');
    const h=serverRequire('./organization-response-settings').createOrganizationResponseSettingsHandlers({db,timestamp:()=>FieldValue.serverTimestamp()});
    await db.doc('equipment/boat').set({organizationId:'approved-org',category:'vessel',scope:'organization',name:'Alus',status:'ok'});
    await db.doc('organizationReadinessSummaries/approved-org').set({minimumCrewRequired:3});
    return {db,h};
  };
  test('response settings: one org config inherits SAR minimum and references equipment without creating units/rosters',async()=>{
    const {db,h}=await setup();
    const initial=await h.getOrganizationResponseSettings(req());
    assert.equal(initial.sarMinimumCrew,3);
    assert.equal(initial.services.sar.enabled,false);
    assert.equal((await db.collection('organizationResponseSettings').get()).size,0);
    await h.saveOrganizationResponseSettings(req(value()));
    const after=await h.getOrganizationResponseSettings(req());
    assert.equal(after.services.tross.minimumResponders,1);
    assert.equal(after.services.sar.enabled,true);
    assert.equal(after.revision,1);
    assert.equal(after.sarMinimumCrew,3);
    await db.doc('organizationReadinessSummaries/approved-org').update({minimumCrewRequired:4});
    await db.doc('equipment/boat').update({status:'broken'});
    const refreshed=await h.getOrganizationResponseSettings(req());
    assert.equal(refreshed.sarMinimumCrew,4);
    assert.equal(refreshed.vessels[0].status,'broken');
    assert.equal('status' in refreshed.services.sar,false);
    assert.equal((await db.collection('responseUnits').get()).size,0);
    assert.equal((await db.collection('unitRoster').get()).size,0);
    const audit=await db.collection('platformAudit').where('action','==','organization.responseSettings').get();
    assert.equal(audit.size,1);
    assert.equal(audit.docs[0].data().createdBy,'org-admin');
  });
  test('response settings: members, center role, platform-only and foreign admins cannot read/write; direct clients denied',async()=>{
    const {db,h}=await setup();
    await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
    await db.doc('centerAccess/center-only/grants/tross').set({active:true,services:['tross'],validUntil:null});
    for(const uid of ['active-member','outsider','platform-only','center-only']) {
      await assert.rejects(h.getOrganizationResponseSettings(req({},uid)),{code:'permission-denied'});
      await assert.rejects(h.saveOrganizationResponseSettings(req(value(),uid)),{code:'permission-denied'});
    }
    await assert.rejects(h.getOrganizationResponseSettings(req({},'org-admin','other-org')),{code:'permission-denied'});
    await assert.rejects(h.saveOrganizationResponseSettings(req(value(),'org-admin','other-org')),{code:'permission-denied'});
    await h.saveOrganizationResponseSettings(req(value()));
    for(const uid of ['org-admin','active-member','platform-only','center-only']) {
      const ref=doc(getEnv().authenticatedContext(uid).firestore(),'organizationResponseSettings/approved-org');
      await assertFails(getDoc(ref)); await assertFails(setDoc(ref,{ready:true}));
      await assertFails(updateDoc(ref,{ready:true})); await assertFails(deleteDoc(ref));
    }
  });
  test('response settings: wrong tenant, personal, issued and non-vessel equipment rejected; legacy status remains unknown',async()=>{
    const {db,h}=await setup();
    const records={foreign:{organizationId:'other-org'},personal:{scope:'personal'},issued:{assignedToUserId:'active-member'},
      suit:{category:'safety'},conflict:{organizationId:'other-org',commandId:'approved-org'},old:{category:'other'}};
    for(const [id,patch] of Object.entries(records)) {
      await db.doc(`equipment/${id}`).set({organizationId:'approved-org',category:'vessel',scope:'organization',...patch});
      const d=value(); d.services.tross.vesselIds=[id];
      await assert.rejects(h.saveOrganizationResponseSettings(req(d)),{code:'invalid-argument'});
    }
    await db.doc('equipment/legacy').set({commandId:'approved-org',category:'vessel',name:'Vana alus'});
    const data=await h.getOrganizationResponseSettings(req());
    assert.deepEqual(data.vessels.map(v=>v.id).sort(),['boat','legacy']);
    assert.equal(data.vessels.find(v=>v.id==='legacy').status,'unknown');
    const d=value();d.services.sar.vesselIds=['legacy'];
    await h.saveOrganizationResponseSettings(req(d));
    await db.doc('equipment/legacy').delete();
    const stale=await h.getOrganizationResponseSettings(req());
    assert.deepEqual(stale.services.sar.vesselIds,['legacy']);
    assert.equal(stale.vessels.some(v=>v.id==='legacy'),false);
    await assert.rejects(h.saveOrganizationResponseSettings(req({...d,expectedRevision:1})),{code:'invalid-argument'});
  });
  test('response settings: concurrent revisions and multi-org accounts cannot overwrite or mix configs',async()=>{
    const {db,h}=await setup();
    const results=await Promise.allSettled([h.saveOrganizationResponseSettings(req(value())),h.saveOrganizationResponseSettings(req(value()))]);
    assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
    assert.equal(results.find(r=>r.status==='rejected').reason.code,'aborted');
    await db.doc('memberships/org-admin_other-org').set({organizationId:'other-org',userId:'org-admin',role:'orgAdmin',status:'active',isActive:true});
    await db.doc('equipment/other-boat').set({organizationId:'other-org',category:'vessel',scope:'organization'});
    const other=value();for(const s of Object.values(other.services)) s.vesselIds=['other-boat'];
    other.services.tross.minimumResponders=2;
    await h.saveOrganizationResponseSettings(req(other,'org-admin','other-org'));
    assert.equal((await h.getOrganizationResponseSettings(req())).services.tross.minimumResponders,1);
    assert.equal((await h.getOrganizationResponseSettings(req({},'org-admin','other-org'))).services.tross.minimumResponders,2);
    await db.doc('memberships/org-admin_approved-org').update({status:'inactive',isActive:false});
    await assert.rejects(h.saveOrganizationResponseSettings(req(value({expectedRevision:1}))),{code:'permission-denied'});
  });
};
