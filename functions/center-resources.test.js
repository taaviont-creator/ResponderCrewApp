const {test} = require('node:test');
const assert = require('node:assert/strict');
const {registrationIdentity,allocationActive} = require('./center-resources');
test('vessel registry identity canonicalizes spacing/case while separating countries', () => {
  assert.deepEqual(registrationIdentity('EE','abc- 123'),registrationIdentity('EE','ABC123'));
  assert.notEqual(registrationIdentity('EE','ABC123').physicalResourceId,registrationIdentity('FI','ABC123').physicalResourceId);
  for (const args of [['E','123'],['EE',''],['EE','<script>']]) assert.throws(()=>registrationIdentity(...args));
});
test('resource allocation requires explicit persistent marker, supports legacy deadlines and release', () => {
  assert.equal(allocationActive({validityMode:'untilChanged',validUntil:null},100000),true);
  assert.equal(allocationActive({validUntil:null},100000),false);
  assert.equal(allocationActive({validityMode:'released',validUntil:null},100000),false);
  assert.equal(allocationActive({validUntil:{toMillis:()=>100}},99),true);
  assert.equal(allocationActive({validUntil:{toMillis:()=>100}},100),false);
});
