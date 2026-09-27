const test = require('node:test');
const assert = require('node:assert/strict');
const {expiryStage, recipients, reminderId, createCertificateReminderJob} = require('./certificate-reminders');
const now = new Date('2026-09-28T07:00:00Z');
test('30-day boundary, expiry day, invalid date and Tallinn midnight', () => {
  assert.equal(expiryStage('2026-10-28', now), 'expiringSoon');
  assert.equal(expiryStage('2026-10-29', now), null);
  assert.equal(expiryStage('2026-09-28', now), 'expiringSoon');
  assert.equal(expiryStage('2026-09-27', now), 'expired');
  assert.equal(expiryStage('2026-02-30', now), null);
  assert.equal(expiryStage('', now), null);
  assert.equal(expiryStage('2026-09-27', new Date('2026-09-27T21:01:00Z')), 'expired');
});
const member = (userId, role = 'member', extra = {}) => ({userId, role, organizationId:'org', status:'active', isActive:true, ...extra});
test('only active owner and same-org admins; pending, removed, contradictory and other-org excluded', () => {
  const people = [member('owner'), member('admin','orgAdmin'), member('admin','orgAdmin'), member('peer'), member('outsider','admin',{organizationId:'else'}), member('pending','orgAdmin',{status:'pending'}), member('disabled','orgAdmin',{isActive:false})];
  assert.deepEqual(recipients({userId:'owner',organizationId:'org'},people), ['owner','admin']);
  assert.deepEqual(recipients({userId:'left',organizationId:'org'},people), []);
});
test('renewal date, recipient and expired stage get distinct delivery identities', () => {
  const id = reminderId('cert','2026-10-28','expiringSoon','owner');
  assert.equal(id, reminderId('cert','2026-10-28','expiringSoon','owner'));
  assert.notEqual(id, reminderId('cert','2027-10-28','expiringSoon','owner'));
  assert.notEqual(id, reminderId('cert','2026-10-28','expired','owner'));
  assert.notEqual(id, reminderId('cert','2026-10-28','expiringSoon','admin'));
});
test('daily job creates private inbox and sends once; renewal alerts again', async () => {
  const stored = new Map(), sent = [];
  const cert = {organizationId:'org', userId:'owner', userName:'Owner', title:'Radio', expiresAt:'2026-10-28'};
  const db = {collection(name) {
    if (name === 'commands') return {doc: () => ({get: async () => ({data: () => ({status:'approved'})})})};
    if (name === 'certificateReminders') return {doc: id => ({create: async data => { if(stored.has(id)) throw {code:6}; stored.set(id,data); }})};
    const query = {orderBy: () => query, limit: () => query, where: () => query,
      get: async () => ({size: name === 'certificates' ? 1 : 2, docs: name === 'certificates' ? [{id:'cert', data: () => cert}] : [member('owner'), member('admin','orgAdmin')].map(d => ({data: () => d}))})};
    return query;
  }};
  const job = createCertificateReminderJob({db, messaging:{sendEachForMulticast: async m => { sent.push(m); return {failureCount:0}; }}, loadTokens:async ids => ids.map(id => ({token:id})), logger:{warn(){}, error(){}}, now:() => now});
  await job(); await job();
  assert.equal(stored.size,2); assert.equal(sent.length,2);
  assert.deepEqual([...stored.values()].map(d => d.recipientUserId),['owner','admin']);
  assert.equal(sent[0].android.notification.channelId,'certificate_reminders');
  cert.expiresAt = '2026-10-27'; await job();
  assert.equal(stored.size,4);
});
