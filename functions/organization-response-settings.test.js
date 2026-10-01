const {test}=require('node:test');
const assert=require('node:assert/strict');
const {validateSettings,defaults}=require('./organization-response-settings');
const data=(patch={})=>({organizationId:'org',expectedRevision:0,contactName:'Valvekontakt',contactPhone:'',
  services:{sar:{enabled:true,departureMinutes:15,vesselIds:['boat']},
    tross:{enabled:true,departureMinutes:60,vesselIds:['boat'],minimumResponders:1}},...patch});

test('service settings: legacy/absent settings enable no service and invent no boat or departure time',()=>{
  const d=defaults();
  assert.equal(d.revision,0);
  assert.equal(d.services.sar.enabled,false);
  assert.equal(d.services.tross.enabled,false);
  assert.equal(d.services.tross.minimumResponders,1);
  assert.equal(d.services.sar.departureMinutes,null);
  assert.deepEqual(d.services.sar.vesselIds,[]);
  assert.equal('minimumResponders' in d.services.sar,false);
});
test('service settings: Tross accepts one responder without inheriting SAR minimum or level',()=>{
  const d=validateSettings(data());
  assert.equal(d.services.tross.minimumResponders,1);
  assert.equal(d.services.tross.departureMinutes,60);
  assert.equal('minimumResponders' in d.services.sar,false);
  assert.equal('requiresLevel2' in d.services.tross,false);
});
test('service settings: no client-computed readiness, SAR override, role or confirmation',()=>{
  for(const patch of [{ready:true},{confirmedAt:Date.now()},{role:'orgAdmin'},{enabledServices:['sar']}]) {
    assert.throws(()=>validateSettings(data(patch)),{code:'invalid-argument'});
  }
  for(const patch of [{minimumResponders:0},{requiresLevel2:false},{minimumCrewRequired:1}]) {
    const d=data(); Object.assign(d.services.sar,patch);
    assert.throws(()=>validateSettings(d),{code:'invalid-argument'});
  }
});
test('service settings: enabled services require a real selection and 1-60 minute departure; disabled drafts allowed',()=>{
  for(const service of ['sar','tross']) for(const patch of [
    {vesselIds:[]},{vesselIds:['boat','boat']},{vesselIds:['foreign/path']},
    {departureMinutes:0},{departureMinutes:61},{departureMinutes:1.5},{departureMinutes:null},
    {departureMinutes:'15'},{enabled:'true'},
  ]) {
    const d=data(); Object.assign(d.services[service],patch);
    assert.throws(()=>validateSettings(d),{code:'invalid-argument'});
  }
  const d=data(); d.services.sar={enabled:false,departureMinutes:null,vesselIds:[]};
  assert.equal(validateSettings(d).services.sar.enabled,false);
  for(const minimum of [0,51,-1,1.5,'1',null]) {
    const d=data(); d.services.tross.minimumResponders=minimum;
    assert.throws(()=>validateSettings(d),{code:'invalid-argument'});
  }
});
