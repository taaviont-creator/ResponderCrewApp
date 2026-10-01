const {test}=require('node:test');
const assert=require('node:assert/strict');
const {evaluateCenterReadiness}=require('./center-readiness');
const {evaluateReadiness}=require('./effective-readiness');
const {confirmationCurrent}=require('./center-readiness');
function input(patch={}) {
  return {service:'sar',now:100000,revision:2,evidenceReady:true,
    policy:{enabled:true,departureMinutes:15,minimumResponders:1},vessels:[{status:'ok'}],
    readiness:{minimum:3,paused:false,crew:[{level:'level1',status:'onDuty'},{level:'level1',status:'onDuty'},{level:'level2',status:'onDuty'}]},
    confirmation:{revision:2,confirmedAtMs:90000,validUntilMs:10000000},...patch};
}
test('center evaluation: one responder yields SAR red and Tross green, no automatic SAR requirements for Tross',()=>{
  const d=input({readiness:{minimum:3,crew:[{level:'none',status:'onDuty'}]}});
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  assert.equal(evaluateCenterReadiness({...d,service:'tross'}).status,'ready');
  assert.equal(evaluateCenterReadiness(input()).status,'ready');
});
test('center evaluation: delayed requires a current explicit confirmation and sufficient crew including level II',()=>{
  const d=input();d.readiness.crew[2]={level:'level2',status:'delayed',arrivalMinutes:15};
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  d.confirmation.expectedReadyAtMs=d.now+15*60000;
  assert.equal(evaluateCenterReadiness(d).status,'delayed');
  d.readiness.crew[2].level='none';
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
});

test('confirmed departure does not drift as time passes; newer personal delay can invalidate it',()=>{
  const d=input();d.confirmation.confirmedAtMs=d.now;
  d.readiness.crew[2]={level:'level2',status:'delayed',arrivalMinutes:15,delayUpdatedAtMs:d.now};
  d.confirmation.expectedReadyAtMs=d.now+15*60000;
  d.now+=5*60000;
  assert.equal(evaluateCenterReadiness(d).status,'delayed');
  d.readiness.crew[2].delayUpdatedAtMs=d.now;
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
});
test('center evaluation: expiry, missing proof, missing boat state and changed configuration never appear green',()=>{
  for(const patch of [{evidenceReady:false},{confirmation:null},{vessels:[{status:'unknown'}]},
    {confirmation:{revision:1,confirmedAtMs:0,validUntilMs:10000000}},
    {confirmation:{revision:2,confirmedAtMs:0,validUntilMs:100000}}]) {
    assert.equal(evaluateCenterReadiness(input(patch)).status,'unknown');
  }
  for(const vessels of [[],[{status:'broken'}],[{status:'outOfService'}]]) {
    assert.equal(evaluateCenterReadiness(input({vessels})).status,'unavailable');
  }
});
test('center evaluation: future scheduled absence cannot count toward a confirmed delay',()=>{
  const d=input();
  d.confirmation.expectedReadyAtMs=d.now+15*60000;
  d.readiness.crew=d.readiness.crew.map((m,i)=>({...m,userId:`u${i}`,status:'delayed',arrivalMinutes:15}));
  d.futureReadiness={crew:d.readiness.crew.map(m=>({...m,status:m.level==='level2'?'offDuty':m.status}))};
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  d.futureReadiness={crew:d.readiness.crew};
  assert.equal(evaluateCenterReadiness(d).status,'delayed');
});
test('center evaluation: pause and explicit unavailability override a valid confirmation and delay',()=>{
  const d=input(); d.readiness.paused=true;
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  d.readiness.paused=false;d.confirmation.unavailable=true;d.confirmation.expectedReadyAtMs=d.now+60000;
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
});
test('center evaluation: the shared existing engine applies planned absence at its boundary',()=>{
  const args={org:'org',organization:{status:'approved'},settings:{minimumCrewRequired:1},
    members:[{id:'u_org',organizationId:'org',userId:'u',status:'active',isActive:true,seaRescueLevel:'level2'}],
    availability:[{id:'u_org',organizationId:'org',userId:'u',status:'onDuty'}],rules:[],
    periods:[{organizationId:'org',userId:'u',status:'active',startAt:new Date(100000),endAt:new Date(200000)}]};
  assert.equal(evaluateCenterReadiness(input({readiness:evaluateReadiness({...args,now:99999})})).status,'ready');
  assert.equal(evaluateCenterReadiness(input({readiness:evaluateReadiness({...args,now:100000})})).status,'unavailable');
  assert.equal(evaluateCenterReadiness(input({readiness:evaluateReadiness({...args,now:200000})})).status,'ready');
});
test('generated demo scenarios include all statuses, no-coordinate unit, and different SAR/Tross states',()=>{
  const scenarios=require('../assets/center-demo.json');
  assert.deepEqual([...new Set(scenarios.normal.sar.map(r=>r.status))].sort(),['delayed','ready','unavailable','unknown']);
  assert.equal(scenarios.normal.sar.find(r=>r.id==='missing').latitude,null);
  assert.equal(scenarios.normal.sar.find(r=>r.id==='west').status,'unavailable');
  assert.equal(scenarios.normal.tross.find(r=>r.id==='west').status,'ready');
  assert.equal(scenarios.absence.sar.find(r=>r.id==='north').status,'unavailable');
  assert.equal(scenarios.expired.sar.find(r=>r.id==='north').status,'unknown');
  for(const scenario of Object.values(scenarios)) for(const rows of Object.values(scenario)) {
    assert.ok(rows.every(r=>r.name.startsWith('Näidis') && !r.contactPhone));
  }
});
test('persistent confirmation survives time, but shortage and admin suspension immediately override it',()=>{
  const d=input({confirmation:{revision:2,confirmedAtMs:1,validUntilMs:null,validityMode:'untilChanged'}});
  d.now+=100*86400000;
  assert.equal(evaluateCenterReadiness(d).status,'ready');
  d.readiness.crew.pop();
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  assert.equal(evaluateCenterReadiness({...d,evidenceReady:false,vessels:[{status:'unknown'}]}).status,'unavailable');
  d.confirmation.unavailable=true;
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  assert.equal(evaluateCenterReadiness(d).freshUntilMs,d.now+90000);
});
test('null expiry alone never grants persistent confirmation; legacy timed expiry and revision checks remain',()=>{
  for(const c of [{revision:2,confirmedAtMs:1,validUntilMs:null},
    {revision:2,confirmedAtMs:null,validUntilMs:null,validityMode:'untilChanged'},
    {revision:1,confirmedAtMs:1,validUntilMs:null,validityMode:'untilChanged'},
    {revision:2,confirmedAtMs:1,validUntilMs:100}]) assert.equal(confirmationCurrent(c,2,100),false);
  assert.equal(confirmationCurrent({revision:2,confirmedAtMs:1,validUntilMs:101},2,100),true);
});
test('persistent confirmation supports explicit delay but does not make delayed members available automatically',()=>{
  const d=input({confirmation:{revision:2,confirmedAtMs:1,validUntilMs:null,validityMode:'untilChanged',expectedReadyAtMs:100000+15*60000}});
  d.readiness.crew[2]={level:'level2',status:'delayed',arrivalMinutes:15};
  assert.equal(evaluateCenterReadiness(d).status,'delayed');
  d.now=d.confirmation.expectedReadyAtMs;
  assert.equal(evaluateCenterReadiness(d).status,'unknown');
});

// Normal center operation has no second manual readiness confirmation.
test('automatic duty mode needs no confirmation; shortage and qualification remain hard conditions',()=>{
  const d=input({automatic:true,confirmation:null});
  assert.equal(evaluateCenterReadiness(d).status,'ready');
  assert.equal(evaluateCenterReadiness(d).confirmedAtMs,null);
  d.readiness.crew.pop();
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  assert.equal(evaluateCenterReadiness({...d,service:'tross'}).status,'ready');
  d.readiness.crew.push({level:'level1',status:'onDuty'});
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
});
test('organization pause is red even without configuration or with an expired confirmation',()=>{
  const d=input({policy:null,confirmation:null});d.readiness.paused=true;
  assert.equal(evaluateCenterReadiness(d).status,'unavailable');
  assert.equal(evaluateCenterReadiness({...d,automatic:true}).status,'unavailable');
  d.readiness.paused=false;
  assert.equal(evaluateCenterReadiness({...d,confirmation:{unavailable:true,validUntilMs:1}}).status,'unavailable');
});
test('qualification loss also tells administrator to review organization duty',()=>{
  const {readinessMessage}=require('./organization-readiness');
  const m=readinessMessage({paused:false,onDutyCount:3,minimum:3,secondLevelMet:false,ready:false},['missingLevel2']);
  assert.ok(m.body.includes('Admin:'));
  assert.ok(m.body.includes('Puudub II astme'));
});
