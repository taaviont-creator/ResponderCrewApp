const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createGeofenceNotifications}=require('./geofence-notifications');
const base={sessionId:'s',organizationId:'o',userId:'u',enabled:true,confirmationRequired:false,zone:'outside',reason:'observed'};
function fixture(before,after,current=after) {
  const sent=[];
  const handle=createGeofenceNotifications({getState:async()=>current,deliver:async d=>sent.push(d)});
  return {sent,run:()=>handle({id:'e',data:{before:{data:()=>before},after:{data:()=>after}}})};
}
test('return consent gets time-sensitive personal notification; unchanged pending state stays quiet',async()=>{
  const after={...base,zone:'unknown',reason:'returnCandidate',confirmationRequired:true};
  const x=fixture(base,after); await x.run();
  assert.equal(x.sent.length,1); assert.equal(x.sent[0].timeSensitive,true);
  assert.equal(x.sent[0].relatedType,'personalAvailability'); assert.match(x.sent[0].body,/kinnitust/);
  const repeat=fixture(after,after); await repeat.run(); assert.equal(repeat.sent.length,0);
});
test('departure and delay messages explicitly explain automation and the new status',async()=>{
  for(const [to,zone,word] of [['offDuty','outside','mitte valves'],['delayed','ring','hilinemisega'],['offDuty','unknown','mitte valves']]) {
    const after={...base,zone,statusChange:{atMs:1,from:'onDuty',to,zone,responseMinutes:30}};
    const x=fixture(base,after); await x.run(); assert.equal(x.sent.length,1);
    assert.match(x.sent[0].title,new RegExp(word)); assert.match(x.sent[0].body,/Automaatika/);
    const repeat=fixture(after,{...after,lastObservedMs:2}); await repeat.run(); assert.equal(repeat.sent.length,0);
  }
});
test('planned absence, manual choice, changed session and already answered return suppress late pushes',async()=>{
  const after={...base,confirmationRequired:true,zone:'inner'};
  for(const patch of [{reason:'plannedAbsence'},{enabled:false,reason:'manual'},{sessionId:'new'},{confirmationRequired:false,reason:'confirmed'}]) {
    const x=fixture(base,after,{...after,...patch}); await x.run(); assert.equal(x.sent.length,0);
  }
  const changed={...base,statusChange:{atMs:1,to:'offDuty',zone:'outside'}};
  for(const patch of [{statusChange:{atMs:2}},{zone:'inner'},{reason:'confirmed'},{enabled:false}]) {
    const x=fixture(base,changed,{...changed,...patch}); await x.run(); assert.equal(x.sent.length,0);
  }
});
test('expiry remains notified, deleted state and lost membership do not leak notifications',async()=>{
  const after={...base,enabled:false,reason:'stale'};
  const x=fixture(base,after); await x.run(); assert.match(x.sent[0].title,/aegus/);
  const deleted=fixture(base,undefined); await deleted.run(); assert.equal(deleted.sent.length,0);
  const handle=createGeofenceNotifications({getState:async()=>{throw {code:'permission-denied'};},deliver:()=>assert.fail('No membership')});
  await handle({data:{before:{data:()=>base},after:{data:()=>after}}});
});
