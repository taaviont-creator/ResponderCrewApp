const {test} = require('node:test');
const assert = require('node:assert/strict');
const {assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, deleteDoc} = require('firebase/firestore');

module.exports = ({getEnv, serverDb, serverRequire}) => {
  const handlers = clock => {
    const {Timestamp, FieldValue} = serverRequire('firebase-admin/firestore');
    return serverRequire('./center-access').createCenterAccessHandlers({
      db:serverDb(), timestamp:()=>FieldValue.serverTimestamp(), fromMillis:Timestamp.fromMillis,
      now:clock || Date.now,
    });
  };
  const request = (uid, data={}) => ({auth:{uid},data});
  const change = (userId,centerId,active,expectedRevision=0) => ({userId,centerId,active,expectedRevision});

  test('center grants can be read only by their owner and cannot be forged even by platform clients', async () => {
    const db = serverDb();
    await db.doc('users/center-platform').set({systemRole:'platformAdmin'});
    await db.doc('centerAccess/center-user/grants/merevalvekeskus').set({active:true,services:['sar'],validUntil:null});
    const env=getEnv(), owner=env.authenticatedContext('center-user').firestore();
    await assertSucceeds(getDocs(collection(owner,'centerAccess/center-user/grants')));
    for (const uid of ['outsider','org-admin','center-platform']) {
      const client=env.authenticatedContext(uid).firestore();
      await assertFails(getDoc(doc(client,'centerAccess/center-user/grants/merevalvekeskus')));
      await assertFails(getDocs(collection(client,'centerAccess/center-user/grants')));
    }
    for (const uid of ['center-user','org-admin','center-platform']) {
      const client=env.authenticatedContext(uid).firestore();
      for (const path of [`centerAccess/${uid}/grants/tross`, 'centers/tross',
        'unitReadiness/unit_sar', 'centerViews/merevalvekeskus/services/sar/units/unit']) {
        await assertFails(setDoc(doc(client,path),{active:true,services:['sar','tross'],status:'ready'}));
        await assertFails(deleteDoc(doc(client,path)));
      }
    }
    await db.doc('centerViews/merevalvekeskus/services/sar/units/unit').set({name:'Private unit'});
    await assertFails(getDoc(doc(owner,'centerViews/merevalvekeskus/services/sar/units/unit')));
    await assertFails(getDoc(doc(owner,'memberships/org-admin_approved-org')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'centerAccess/center-user/grants/merevalvekeskus')));
  });

  test('platform can grant both centers and revoke immediately without adding organization roles', async () => {
    const db=serverDb(), h=handlers();
    await db.doc('users/center-platform').set({systemRole:'platformAdmin'});
    await db.doc('users/center-user').set({name:'Center worker',systemRole:'user'});
    const before=(await db.doc('users/center-user').get()).data();
    for (const actor of ['center-user','org-admin','active-member']) {
      await assert.rejects(h.setCenterAccess(request(actor,change('center-user','merevalvekeskus',true))),{code:'permission-denied'});
      await assert.rejects(h.getPlatformCenterAccess(request(actor,{userId:'center-user'})),{code:'permission-denied'});
    }
    assert.equal((await h.getCenterContexts(request('center-platform'))).contexts.length,0);
    for (const center of ['merevalvekeskus','tross']) {
      await h.setCenterAccess(request('center-platform',change('center-user',center,true)));
    }
    assert.deepEqual((await h.getCenterContexts(request('center-user'))).contexts.map(c=>c.service),['sar','tross']);
    assert.equal((await h.getCenterContexts(request('org-admin',{userId:'center-user'}))).contexts.length,0);
    assert.deepEqual((await db.doc('users/center-user').get()).data(),before);
    assert.equal((await db.collection('memberships').where('userId','==','center-user').get()).size,0);
    await h.setCenterAccess(request('center-platform',change('center-user','merevalvekeskus',false,1)));
    assert.deepEqual((await h.getCenterContexts(request('center-user'))).contexts.map(c=>c.service),['tross']);
    await assert.rejects(h.setCenterAccess(request('center-platform',change('center-user','merevalvekeskus',true,1))),{code:'aborted'});
    const audit=await db.collection('platformAudit').where('targetId','==','center-user').get();
    assert.equal(audit.size,3);
    assert.ok(audit.docs.every(d=>d.data().createdBy==='center-platform' && d.data().createdAt.toMillis()));
    await db.doc('users/center-platform').update({systemRole:'user'});
    await assert.rejects(h.setCenterAccess(request('center-platform',change('center-user','tross',false,1))),{code:'permission-denied'});
  });

  test('center grant expiry and center suspension are checked from current server data', async () => {
    let time=1000;
    const db=serverDb(), h=handlers(()=>time);
    await db.doc('users/center-platform').set({systemRole:'platformAdmin'});
    await db.doc('users/center-user').set({systemRole:'user'});
    await h.setCenterAccess(request('center-platform',{...change('center-user','tross',true),validUntilMs:2000}));
    assert.equal((await h.getCenterContexts(request('center-user'))).contexts.length,1);
    time=2000;
    assert.equal((await h.getCenterContexts(request('center-user'))).contexts.length,0);
    await h.setCenterAccess(request('center-platform',change('center-user','tross',true,1)));
    await db.doc('centers/tross').update({active:false});
    assert.equal((await h.getCenterContexts(request('center-user'))).contexts.length,0);
  });
};
