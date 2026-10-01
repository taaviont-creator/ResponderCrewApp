const {test} = require('node:test');
const assert = require('node:assert/strict');
const {allowed, createCenterAccessHandlers} = require('./center-access');

test('center permission requires its service, an active center and an unexpired explicit grant', () => {
  const center = {active:true, services:['sar']};
  const grant = {active:true, services:['sar'], validUntil:null};
  assert.equal(allowed(grant, center, 'sar', 100), true);
  for (const patch of [{active:false}, {services:['tross']}, {validUntil:undefined},
    {validUntil:'tomorrow'}, {validUntil:{toMillis:()=>100}}]) {
    assert.ok(!allowed({...grant,...patch}, center, 'sar', 100));
  }
  assert.ok(!allowed(grant, {...center,active:false}, 'sar', 100));
  assert.ok(!allowed(grant, center, 'tross', 100));
  assert.ok(!allowed(null, center, 'sar', 100));
});

test('center writes reject role injection, invalid ids and uncontrolled fields before any write', async () => {
  const handlers = createCenterAccessHandlers({db:{runTransaction:()=>assert.fail('must not write')}, now:()=>100});
  const valid = {userId:'user',centerId:'merevalvekeskus',active:true,expectedRevision:0};
  for (const patch of [{role:'orgAdmin'}, {services:['sar','tross']}, {centerId:'__proto__'},
    {userId:'user/other'}, {expectedRevision:-1}, {active:'true'}, {validUntilMs:99}]) {
    await assert.rejects(handlers.setCenterAccess({auth:{uid:'admin'},data:{...valid,...patch}}), {code:'invalid-argument'});
  }
  await assert.rejects(handlers.getCenterContexts({data:{userId:'someone-else'}}), {code:'unauthenticated'});
});
