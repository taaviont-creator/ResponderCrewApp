const {test}=require('node:test');
const assert=require('node:assert/strict');
const {transition,availabilityStatus,validateSettings,FRESH_MS}=require('./geofence-policy');
test('geofence: entry always needs explicit on-duty consent, re-entry invalidates previous consent',()=>{
  for(const current of ['offDuty','delayed','onDuty']) {
    const next=transition({zone:'outside',confirmedInner:true},'inner',current,15);
    assert.notEqual(next.status,'onDuty'); assert.equal(next.confirmationRequired,true);
  }
  assert.equal(transition({zone:'inner',confirmedInner:true},'inner','onDuty',15).status,'onDuty');
  assert.equal(transition({zone:'inner',confirmedInner:true},'outside','onDuty',15).confirmedInner,false);
});
test('geofence: ring delays, outside and inaccurate location remove availability',()=>{
  assert.equal(transition({},'ring','onDuty',30).responseMinutes,30);
  for(const zone of ['outside','unknown']) assert.equal(transition({},zone,'onDuty',15).status,'offDuty');
});
test('geofence: lease expiry is exact and never applies to later manual status',()=>{
  const at=1000, a={status:'onDuty',updatedAt:new Date(at),geofenceAppliedAt:new Date(at),geofenceUntil:new Date(at+FRESH_MS)};
  assert.equal(availabilityStatus(a,at+FRESH_MS-1),'onDuty');
  assert.equal(availabilityStatus(a,at+FRESH_MS),'offDuty');
  assert.equal(availabilityStatus({...a,updatedAt:new Date(at+1)},at+FRESH_MS),'onDuty');
  assert.equal(availabilityStatus({status:'onDuty'},at+FRESH_MS),'onDuty');
});
test('geofence: bounded distinct radii and supported delay',()=>{
  const d={enabled:true,innerMeters:3000,outerMeters:8000,delayMinutes:15};
  assert.equal(validateSettings(d),true);
  for(const patch of [{innerMeters:0},{outerMeters:3000},{outerMeters:50001},{delayMinutes:0},{enabled:'true'}]) assert.equal(validateSettings({...d,...patch}),false);
});
