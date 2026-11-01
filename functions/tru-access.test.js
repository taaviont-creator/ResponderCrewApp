const {test} = require('node:test');
const assert = require('node:assert/strict');
const {membershipContext, createTruAccessHandlers} = require('./tru-access');
const active = {active: true, role: 'member', regions: ['Ida'], revision: 1, validUntil: null};

test('TRU membership fails closed for revoked, expired, malformed and oversized grants', () => {
  assert.deepEqual(membershipContext(active, 100), {role: 'member', regions: ['Ida'], revision: 1, validUntilMs: null});
  for (const patch of [{active:false}, {role:'orgAdmin'}, {role:'platformAdmin'}, {regions:[]},
    {regions:['Ida','Ida']}, {regions:['Ida','Kõik']}, {regions:Array(500).fill('Ida')},
    {revision:0}, {validUntil:undefined}, {validUntil:'tomorrow'}, {validUntil:{toMillis:()=>100}}]) {
    assert.equal(membershipContext({...active, ...patch}, 100), null);
  }
  assert.equal(membershipContext(undefined, 100), null);
});

test('TRU context uses authenticated UID even when request supplies another identity', async () => {
  const reads = [];
  const handlers = createTruAccessHandlers({db:{doc:path=>({get: async () => {
    reads.push(path); return {data:()=>active};
  }})}, now:()=>100});
  await assert.rejects(handlers.getTruContext({data:{userId:'other'}}), {code:'unauthenticated'});
  const result = await handlers.getTruContext({auth:{uid:'own'}, data:{userId:'other', role:'admin'}});
  assert.deepEqual(reads, ['truMemberships/own']);
  assert.equal(result.membership.role, 'member');
});

test('TRU grant validation rejects schema injection before transactions', async () => {
  const handlers = createTruAccessHandlers({db:{runTransaction:()=>assert.fail('No writes allowed')}, now:()=>100});
  const data = {userId:'target', active:true, role:'member', regions:['Ida'], expectedRevision:0};
  for (const patch of [{userId:'../other'}, {role:'platformAdmin'}, {regions:['Kõik']},
    {expectedRevision:-1}, {active:'true'}, {extra:'injection'}, {validUntilMs:100}]) {
    await assert.rejects(handlers.setTruAccess({auth:{uid:'admin'}, data:{...data,...patch}}), {code:'invalid-argument'});
  }
});

test('TRU grants require platform authorization and revision checks; writes are audited', async () => {
  const values = new Map([['users/admin', {systemRole:'platformAdmin'}], ['users/member', {systemRole:'member'}],
    ['users/target', {}]]);
  const writes = [];
  const db = {doc:path=>({path, get:async()=>({exists:values.has(path),data:()=>values.get(path)})}), runTransaction: async fn => fn({
    get: async ref => ({exists:values.has(ref.path), data:()=>values.get(ref.path)}),
    set: (ref,data) => {writes.push(ref.path); values.set(ref.path,data);},
    create: (ref,data) => {writes.push(ref.path); values.set(ref.path,data);},
  })};
  const handlers = createTruAccessHandlers({db, now:()=>100, timestamp:()=>100, fromMillis:ms=>({toMillis:()=>ms})});
  const data = {userId:'target', active:true, role:'coordinator', regions:['Ida'], expectedRevision:0};
  await assert.rejects(handlers.setTruAccess({data}), {code:'unauthenticated'});
  await assert.rejects(handlers.setTruAccess({auth:{uid:'member'}, data}), {code:'permission-denied'});
  assert.equal(writes.length, 0);
  await handlers.setTruAccess({auth:{uid:'admin'}, data});
  assert.equal(values.get('truMemberships/target').revision, 1);
  assert.ok(writes[1].startsWith('platformAudit/'));
  await assert.rejects(handlers.setTruAccess({auth:{uid:'admin'}, data}), {code:'aborted'});
  await handlers.setTruAccess({auth:{uid:'admin'}, data:{...data, expectedRevision:1, active:false}});
  assert.equal((await handlers.getTruContext({auth:{uid:'target'}})).membership, null);
  assert.equal(values.get('truMemberships/target').revision, 2);
});
