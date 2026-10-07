const {test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, query, where, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp} = require('firebase/firestore');

module.exports = ({getEnv, serverDb}) => {
  const organizationId = 'approved-org', owner = 'active-member', admin = 'org-admin';
  const value = (id, extra = {}) => ({
    id, organizationId, commandId: organizationId, userId: owner, userName: 'Member',
    title: 'Merepäästetunnistus', type: 'seaRescue', issuer: 'Issuer',
    issuedAt: '2026-01-01', expiresAt: '2028-01-01', status: 'valid', note: '',
    number: 'CERT-1', noExpiry: false, createdBy: owner,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  });
  const db = (uid) => getEnv().authenticatedContext(uid).firestore();

  test('member enters own certificate, reads it, edits it and archives it without qualification escalation', async () => {
    const client = db(owner), ref = doc(client, 'certificates', 'self-cert');
    await assertSucceeds(setDoc(ref, value('self-cert')));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(getDocs(query(collection(client, 'certificates'), where('organizationId', '==', organizationId), where('userId', '==', owner))));
    await assertSucceeds(updateDoc(ref, {number: 'CERT-2', note: 'Täiendatud', expiresAt: '2029-01-01', updatedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(ref, {archived: true, updatedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(doc(db(admin), 'certificates', 'self-cert'), {note: 'Admini parandus'}));
    await assertFails(updateDoc(doc(client, 'memberships', `${owner}_${organizationId}`), {seaRescueLevel: 'level2', updatedAt: serverTimestamp()}));
    await assertFails(deleteDoc(ref));
  });

  test('self-service certificates cannot forge ownership, authority, organization or creation metadata', async () => {
    const client = db(owner), ref = doc(client, 'certificates', 'self-cert');
    await assertSucceeds(setDoc(ref, value('self-cert')));
    for (const extra of [
      {userId: 'target-member'}, {createdBy: admin}, {organizationId: 'other-org', commandId: 'other-org'},
      {role: 'orgAdmin'}, {seaRescueLevel: 'level2'}, {verified: true},
      {createdAt: new Date('2020-01-01')}, {noExpiry: true}, {number: 123},
    ]) await assertFails(setDoc(doc(client, 'certificates', 'invalid'), value('invalid', extra)));
    for (const extra of [
      {userId: 'target-member'}, {createdBy: admin}, {organizationId: 'other-org', commandId: 'other-org'},
      {role: 'orgAdmin'}, {verified: true}, {createdAt: new Date('2020-01-01')},
      {archived: 'true'}, {updatedAt: new Date('2020-01-01')},
    ]) await assertFails(updateDoc(ref, {...extra, ...('updatedAt' in extra ? {} : {updatedAt: serverTimestamp()})}));
    const peer = db('target-member');
    await assertFails(getDoc(doc(peer, 'certificates', 'self-cert')));
    await assertFails(updateDoc(doc(peer, 'certificates', 'self-cert'), {note: 'Other member', updatedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(peer, 'certificates', 'peer-for-owner'), value('peer-for-owner', {createdBy: 'target-member'})));
    await assertFails(setDoc(doc(getEnv().unauthenticatedContext().firestore(), 'certificates', 'anonymous'), value('anonymous')));
  });

  test('inactive membership and suspended organization revoke self-service certificate writes', async () => {
    const client = db(owner), ref = doc(client, 'certificates', 'self-cert');
    await assertSucceeds(setDoc(ref, value('self-cert')));
    for (const status of ['pending', 'removed']) {
      await serverDb().doc(`memberships/${owner}_${organizationId}`).update({status, isActive: false});
      await assertFails(setDoc(doc(client, 'certificates', 'inactive'), value('inactive')));
      await assertFails(updateDoc(ref, {note: 'Denied', updatedAt: serverTimestamp()}));
    }
    await serverDb().doc(`memberships/${owner}_${organizationId}`).update({status: 'active', isActive: true});
    await serverDb().doc(`commands/${organizationId}`).update({status: 'suspended'});
    await assertFails(setDoc(doc(client, 'certificates', 'suspended'), value('suspended')));
    await assertFails(updateDoc(ref, {note: 'Denied', updatedAt: serverTimestamp()}));
  });

  test('member cannot rewrite certificates recorded by admin', async () => {
    await assertSucceeds(setDoc(doc(db(admin), 'certificates', 'admin-cert'), value('admin-cert', {createdBy: admin})));
    const ref = doc(db(owner), 'certificates', 'admin-cert');
    await assertSucceeds(getDoc(ref));
    await assertFails(updateDoc(ref, {note: 'Changed', updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(ref, {archived: true, updatedAt: serverTimestamp()}));
  });
};
