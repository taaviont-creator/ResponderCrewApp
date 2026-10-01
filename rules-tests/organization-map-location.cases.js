const {test}=require('node:test');
const assert=require('node:assert/strict');
const {assertFails}=require('@firebase/rules-unit-testing');
const {doc,updateDoc}=require('firebase/firestore');
module.exports=({getEnv,serverDb,serverRequire})=>{
  const req=(data={},uid='org-admin',organizationId='approved-org')=>({auth:{uid},data:{organizationId,...data}});
  const value=(patch={})=>({expectedRevision:0,address:'Purtse sadam',latitude:59.45,longitude:26.5,positionVerified:true,...patch});
  const setup=()=>{
    const db=serverDb(),{FieldValue,Timestamp,GeoPoint}=serverRequire('firebase-admin/firestore');
    const h=serverRequire('./response-units').createResponseUnitHandlers({db,timestamp:()=>FieldValue.serverTimestamp(),
      fromMillis:Timestamp.fromMillis,geoPoint:(a,b)=>new GeoPoint(a,b)});
    return {db,h};
  };
  test('organization location: empty read, one canonical base, audited edits and clearing without duplicates',async()=>{
    const {db,h}=setup();
    assert.deepEqual(await h.getOrganizationMapLocation(req()),{address:'',latitude:null,longitude:null,positionVerified:false,revision:0});
    assert.equal((await db.collection('rescueBases').get()).size,0);
    await h.saveOrganizationMapLocation(req(value()));
    const org=(await db.doc('commands/approved-org').get()).data();
    const ref=db.doc(`rescueBases/${org.primaryRescueBaseId}`);
    const original=(await ref.get()).data();
    assert.equal(original.position.latitude,59.45);
    await h.saveOrganizationMapLocation(req(value({expectedRevision:1,address:'Sadama kai'})));
    assert.equal((await ref.get()).data().positionVerifiedAt.toMillis(),original.positionVerifiedAt.toMillis());
    await h.saveOrganizationMapLocation(req(value({expectedRevision:2,latitude:null,longitude:null,positionVerified:false})));
    assert.equal((await ref.get()).data().position,null);
    assert.equal((await db.collection('rescueBases').get()).size,1);
    assert.equal((await db.collection('responseUnits').get()).size,0);
    assert.equal((await db.collection('platformAudit').where('action','==','organization.mapLocation').get()).size,3);
    assert.equal((await h.getOrganizationMapLocation(req())).positionVerified,false);
  });
  test('organization location: reuse existing base, preserve links/status, reject ambiguous legacy bases',async()=>{
    const {db,h}=setup();
    await db.doc('rescueBases/existing').set({organizationId:'approved-org',name:'Senine nimi',active:false,revision:4});
    await db.doc('responseUnits/linked').set({organizationId:'approved-org',baseId:'existing'});
    assert.equal((await h.getOrganizationMapLocation(req())).revision,4);
    await h.saveOrganizationMapLocation(req(value({expectedRevision:4})));
    const existing=(await db.doc('rescueBases/existing').get()).data();
    assert.equal(existing.name,'Senine nimi');
    assert.equal(existing.active,false);
    assert.equal((await db.doc('commands/approved-org').get()).data().primaryRescueBaseId,'existing');
    await db.doc('rescueBases/second').set({organizationId:'approved-org',revision:0});
    assert.equal((await h.getOrganizationMapLocation(req())).revision,5);
    const {FieldValue}=serverRequire('firebase-admin/firestore');
    await db.doc('commands/approved-org').update({primaryRescueBaseId:FieldValue.delete()});
    await assert.rejects(h.getOrganizationMapLocation(req()),{code:'failed-precondition'});
    await assert.rejects(h.saveOrganizationMapLocation(req(value())),{code:'failed-precondition'});
    assert.equal((await db.collection('rescueBases').get()).size,2);
  });
  test('organization location: admin membership required; no target, role, state or pointer injection',async()=>{
    const {db,h}=setup();
    await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
    for (const uid of ['active-member','outsider','platform-only']) {
      await assert.rejects(h.getOrganizationMapLocation(req({},uid)),{code:'permission-denied'});
      await assert.rejects(h.saveOrganizationMapLocation(req(value(),uid)),{code:'permission-denied'});
    }
    await assert.rejects(h.saveOrganizationMapLocation(req(value(),'org-admin','other-org')),{code:'permission-denied'});
    for (const extra of [{id:'foreign'},{baseId:'foreign'},{active:true},{ready:true},{role:'orgAdmin'},{primaryRescueBaseId:'foreign'}]) {
      await assert.rejects(h.saveOrganizationMapLocation(req(value(extra))),{code:'invalid-argument'});
    }
    for (const patch of [{latitude:59,longitude:null},{latitude:NaN},{latitude:91},{latitude:null,longitude:null},{expectedRevision:-1}]) {
      await assert.rejects(h.saveOrganizationMapLocation(req(value(patch))),{code:'invalid-argument'});
    }
    for (const uid of ['org-admin','active-member','platform-only']) {
      await assertFails(updateDoc(doc(getEnv().authenticatedContext(uid).firestore(),'commands/approved-org'),{primaryRescueBaseId:'foreign'}));
    }
    await db.doc('rescueBases/foreign').set({organizationId:'other-org',revision:0});
    await db.doc('commands/approved-org').update({primaryRescueBaseId:'foreign'});
    await assert.rejects(h.getOrganizationMapLocation(req()),{code:'failed-precondition'});
    await assert.rejects(h.saveOrganizationMapLocation(req(value())),{code:'failed-precondition'});
    assert.equal((await db.doc('rescueBases/foreign').get()).data().revision,0);
  });
  test('organization location: concurrent first saves and stale edits cannot duplicate bases or lose changes',async()=>{
    const {db,h}=setup();
    const results=await Promise.allSettled([h.saveOrganizationMapLocation(req(value())),h.saveOrganizationMapLocation(req(value({latitude:59.6})))]);
    assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
    assert.equal(results.find(r=>r.status==='rejected').reason.code,'aborted');
    assert.equal((await db.collection('rescueBases').get()).size,1);
    await assert.rejects(h.saveOrganizationMapLocation(req(value())),{code:'aborted'});
  });
  test('organization location: multi-org admin edits each organization independently',async()=>{
    const {db,h}=setup();
    await db.doc('memberships/org-admin_other-org').set({organizationId:'other-org',userId:'org-admin',role:'orgAdmin',status:'active',isActive:true});
    await h.saveOrganizationMapLocation(req(value()));
    await h.saveOrganizationMapLocation(req(value({latitude:58.2,longitude:24.5}),'org-admin','other-org'));
    assert.equal((await h.getOrganizationMapLocation(req())).latitude,59.45);
    assert.equal((await h.getOrganizationMapLocation(req({},'org-admin','other-org'))).latitude,58.2);
    assert.equal((await db.collection('rescueBases').get()).size,2);
  });
};
