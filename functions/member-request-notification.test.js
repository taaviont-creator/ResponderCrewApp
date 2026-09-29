const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createMemberRequestHandler} = require('./member-request-notification');

const pending = {userId: 'applicant', organizationId: 'a', role: 'member',
  status: 'pending', isActive: false, joinedAt: {toMillis: () => 100}};
function fixture({before, after = pending, latest = after, admins = [], tokens = [{token: 'device'}]} = {}) {
  const sends = [], recipients = [];
  const {db,records:claims} = require('./test-helpers/memory-db').memoryDb({
    'commands/a':{status:'approved',name:'Ühing A'},
    ...Object.fromEntries(admins.map(m=>[`memberships/${m.userId}_${m.organizationId || m.commandId}`,m])),
  });
  const handler = createMemberRequestHandler({db,
    messaging: {sendEachForMulticast: async message => {
      sends.push(message); return {successCount: message.tokens.length, failureCount: 0};
    }},
    logger: {info() {}},
    loadTokens: async ids => {recipients.push(ids); return ids.length ? tokens : [];},
  });
  const event = {id: 'event-1', params: {membershipId: 'applicant_a'}, data: {
    before: {data: () => before},
    after: {data: () => after, ref: {get: async () => ({data: () => latest})}},
  }};
  return {handler, event, sends, recipients, claims};
}
const activeAdmin = {userId: 'admin', organizationId: 'a', role: 'orgAdmin', status: 'active', isActive: true};

test('new request alerts only same-org active admins and deduplicates legacy query results', async () => {
  const f = fixture({admins: [activeAdmin,
    {...activeAdmin, userId: 'legacy', role: 'admin', organizationId: undefined, commandId: 'a'},
    {...activeAdmin, userId: 'member', role: 'member'},
    {...activeAdmin, userId: 'other', organizationId: 'b', commandId: 'a'},
    {...activeAdmin, userId: 'inactive', isActive: false},
    {...activeAdmin, userId: 'removed', status: 'removed'},
    {...activeAdmin, userId: 'applicant'},
  ]});
  await f.handler(f.event);
  assert.deepEqual(f.recipients, [['admin'], ['legacy']]);
  assert.equal(f.sends.length, 2);
  assert.equal(f.sends[0].data.type, 'member_request');
  assert.equal(f.sends[0].data.organizationId, 'a');
  assert.equal(f.sends[0].android.notification.channelId, 'respondcrew_info');
});
test('same event delivery never sends twice', async () => {
  const f = fixture({admins: [activeAdmin]});
  await f.handler(f.event); await f.handler(f.event);
  assert.equal(f.sends.length, 1);
});
test('removed member requesting again generates a notification', async () => {
  const f = fixture({before: {...pending, status: 'removed'}, admins: [activeAdmin]});
  await f.handler(f.event);
  assert.equal(f.sends.length, 1);
});
test('pending edits, decisions, deletion and new organization owner do not alert', async () => {
  for (const options of [
    {before: pending}, {after: {...pending, status: 'active', isActive: true}},
    {after: null}, {after: {...pending, role: 'orgAdmin'}},
  ]) {
    const f = fixture({...options, admins: [activeAdmin]});
    await f.handler(f.event);
    assert.equal(f.sends.length, 0);
  }
});
test('delayed event skips reviewed, deleted or newer requests', async () => {
  for (const latest of [null, {...pending, status: 'rejected'},
    {...pending, organizationId: 'b'}, {...pending, joinedAt: {toMillis: () => 200}}]) {
    const f = fixture({latest, admins: [activeAdmin]});
    await f.handler(f.event);
    assert.equal(f.sends.length, 0);
  }
});
test('no devices still stores inbox; large audiences use FCM batch limits', async () => {
  const empty = fixture({admins: [activeAdmin], tokens: []});
  await empty.handler(empty.event);
  assert.equal([...empty.claims.keys()].filter(k=>k.startsWith('userNotifications/')).length, 1);
  const large = fixture({admins: [activeAdmin], tokens: Array.from({length: 501}, (_, i) => ({token: String(i)}))});
  await large.handler(large.event);
  assert.deepEqual(large.sends.map(s => s.tokens.length), [500, 1]);
});
