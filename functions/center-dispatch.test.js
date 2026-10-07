const {test}=require('node:test');
const assert=require('node:assert/strict');
const {validateDetails,validateTargets}=require('./center-dispatch');
test('maritime dispatch permits narrative-only uncertainty and validates optional position precision',()=>{
  const d={title:'Punane rakett',description:'Purtse sadamast nähti umbes 2 miili kaugusel',location:'',position:null,positionKind:'unknown'};
  assert.equal(validateDetails(d).position,null);
  for(const position of [{latitude:91,longitude:26},{latitude:59,longitude:Infinity},{latitude:'59',longitude:26}])assert.throws(()=>validateDetails({...d,position,positionKind:'approximate'}));
  assert.throws(()=>validateDetails({...d,description:''}));
  assert.throws(()=>validateDetails({...d,positionKind:'exact'}));
  assert.equal(validateDetails({...d,position:{latitude:59,longitude:26},positionKind:'lastKnown'}).positionKind,'lastKnown');
});
test('dispatch recipients must be unique and bounded',()=>{
  validateTargets([{organizationId:'a'},{organizationId:'b'}]);
  for(const targets of [[],[{organizationId:'a'},{organizationId:'a'}],Array.from({length:31},(_,i)=>({organizationId:`org${i}`})),[{organizationId:'a/b'}]])assert.throws(()=>validateTargets(targets));
});
