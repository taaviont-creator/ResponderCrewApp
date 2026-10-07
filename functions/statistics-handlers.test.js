const {test}=require('node:test');const assert=require('node:assert/strict');
const {access,createRecordContributionHandler,createCalloutAttendanceHandler}=require('./statistics-handlers');
const member=(uid,extra={})=>({userId:uid,organizationId:'org',commandId:'org',status:'active',isActive:true,role:'member',displayName:uid,...extra});
function fixture(overrides={}) {
 const records={'commands/org':{status:'approved',allowMembersToViewStatistics:true,allowMembersToCreateActivities:true},'memberships/a_org':member('a'),'memberships/b_org':member('b'),'callouts/c':{organizationId:'org',status:'closed'},...overrides};
 const writes=[];const snapshot=p=>({exists:!!records[p],data:()=>records[p]});
 const db={doc:path=>({path,get:async()=>snapshot(path)}),runTransaction:async fn=>fn({get:async ref=>snapshot(ref.path),getAll:async(...refs)=>refs.map(ref=>snapshot(ref.path)),create:(ref,data)=>{records[ref.path]=data;writes.push(ref.path);},set:(ref,data)=>{records[ref.path]=data;writes.push(ref.path);}})};
 return {db,records,writes,record:createRecordContributionHandler({db,timestamp:()=>123,now:()=>Date.parse('2026-09-28T12:00:00Z')}),attendance:createCalloutAttendanceHandler({db,timestamp:()=>123})};
}
const req=data=>({auth:{uid:'a'},data:{organizationId:'org',...data}});
const contribution={requestId:'unique',title:'Mowing',type:'groundskeeping',date:'2026-09-27',hours:2,memberIds:['a']};

test('event export capability is derived from organization admin membership, never caller flags or platform claim',async()=>{
 const {createStatisticsHandler}=require('./statistics-handlers');
 for(const role of ['member','orgAdmin']) {
   const f=fixture({'memberships/a_org':member('a',{role}),
     'callouts/c':{organizationId:'org',createdAt:'2026-09-27T10:00:00Z',title:'Empty callout',status:'active'}});
   f.db.collection=name=>({where:(field,op,value)=>({get:async()=>({docs:Object.entries(f.records)
     .filter(([path,data])=>path.startsWith(`${name}/`)&&data[field]===value)
     .map(([path,data])=>({id:path.split('/')[1],data:()=>data}))})})});
   const handler=createStatisticsHandler({db:f.db,now:()=>Date.parse('2026-09-28T12:00Z')});
   const response=await handler({...req({from:'2026-09-01',to:'2026-09-28',includeEventDetails:true,canManage:true}),auth:{uid:'a',token:{platformAdmin:true}}});
   assert.equal(Object.hasOwn(response,'eventDetails'),role==='orgAdmin');
   if(role==='orgAdmin') assert.equal(response.eventDetails[0].id,'c');
 }
});

test('contributions are separate from scheduling, keep notes and count once only after confirmation',async()=>{
 const f=fixture({'commands/org':{status:'approved',allowMembersToCreateActivities:false,allowMembersToViewStatistics:false}});
 const data={...contribution,description:'  Puhastasin kai  '};
 await f.record(req(data));await f.record(req(data));
 const a=f.records['activities/contribution_unique'],p=f.records['activityParticipants/contribution_unique_a'];
 assert.equal(a.entryKind,'contribution');assert.equal(a.description,'Puhastasin kai');assert.equal(f.writes.length,2);
 const {aggregate}=require('./contribution-statistics');
 const calculate=()=>aggregate({organizationId:'org',from:'2026-09-27',to:'2026-09-28',now:Date.parse('2026-09-28T12:00Z'),trackingStart:null,current:[],history:[],memberships:[member('a')],activities:[a],participants:[p],callouts:[],responses:[],attendance:[]}).members.find(m=>m.userId==='a');
 assert.equal(calculate().contributionHours,0);assert.equal(calculate().pendingCount,1);
 p.attendanceStatus='confirmed';assert.equal(calculate().contributionHours,2);assert.equal(calculate().categories.groundskeeping.hours,2);
 p.attendanceStatus='absent';assert.equal(calculate().contributionHours,0);
 await assert.rejects(f.record(req({...data,requestId:'peer',memberIds:['b']})),{code:'permission-denied'});
 for(const extra of [{status:'pending'},{status:'removed'},{isActive:false},{organizationId:'other'}]) await assert.rejects(fixture({'memberships/a_org':member('a',extra)}).record(req(data)),{code:'permission-denied'});
});
test('stats authorization rejects anonymous, inactive, conflicting and other-org memberships',async()=>{
 await assert.rejects(access(fixture().db,{data:{organizationId:'org'}}),{code:'unauthenticated'});
 for(const override of [{status:'pending'},{status:'removed',isActive:true},{isActive:false},{commandId:'other'},{organizationId:'other'},{userId:'other'}]) {
  await assert.rejects(access(fixture({'memberships/a_org':member('a',override)}).db,req({}),{statistics:true}),{code:'permission-denied'});
 }
 await assert.rejects(access(fixture({'commands/org':{status:'pending'}}).db,req({})),{code:'permission-denied'});
 await assert.rejects(access(fixture({'commands/org':{status:'approved'}}).db,req({}),{statistics:true}),{code:'permission-denied'});
 await assert.rejects(access(fixture().db,req({organizationId:'org/path'})),{code:'invalid-argument'});
});
test('member contribution is pending and may only name self; retries do not double-count',async()=>{
 const f=fixture();await f.record(req(contribution));await f.record(req(contribution));assert.equal(f.writes.length,2);
 const p=f.records['activityParticipants/contribution_unique_a'];assert.equal(p.attendanceStatus,'notConfirmed');assert.equal(p.hours,2);
 await assert.rejects(f.record(req({...contribution,requestId:'other',memberIds:['b']})),{code:'permission-denied'});
});
test('admin can confirm a group contribution; permission and target membership enforced',async()=>{
 const f=fixture({'memberships/a_org':member('a',{role:'orgAdmin'})});await f.record(req({...contribution,memberIds:['a','b','b']}));
 assert.equal(f.writes.length,3);assert.equal(f.records['activityParticipants/contribution_unique_b'].attendanceStatus,'confirmed');
 const withoutScheduling=fixture({'commands/org':{status:'approved'}});await withoutScheduling.record(req(contribution));assert.equal(withoutScheduling.records['activityParticipants/contribution_unique_a'].attendanceStatus,'notConfirmed');
 const pending=fixture({'memberships/a_org':member('a',{role:'orgAdmin'}),'memberships/b_org':member('b',{status:'pending'})});await assert.rejects(pending.record(req({...contribution,memberIds:['b']})),{code:'failed-precondition'});assert.equal(pending.writes.length,0);
});
test('invalid contribution fields and cross-org idempotency collisions are rejected',async()=>{
 for(const invalid of [{hours:0},{hours:NaN},{hours:25},{date:'2027-01-01'},{date:{}},{type:'__proto__'},{title:''},{memberIds:[]},{requestId:'../bad'},{description:{}},{description:'a'.repeat(2001)}]) await assert.rejects(fixture().record(req({...contribution,...invalid})),{code:'invalid-argument'});
 await assert.rejects(fixture({'activities/contribution_unique':{organizationId:'other',createdBy:'a'}}).record(req(contribution)),{code:'already-exists'});
});
test('admin confirms actual callout attendance; confirmation and hours can be corrected',async()=>{
 const data={calloutId:'c',userId:'b',status:'confirmed',hours:3};
 await assert.rejects(fixture().attendance(req(data)),{code:'permission-denied'});
 const f=fixture({'memberships/a_org':member('a',{role:'orgAdmin'})});await f.attendance(req(data));assert.equal(f.records['calloutAttendance/c_b'].hours,3);
 await f.attendance(req({...data,status:'absent'}));assert.equal(f.records['calloutAttendance/c_b'].hours,null);
 for(const changes of [{'callouts/c':{organizationId:'other'}},{'callouts/c':{organizationId:'org',status:'cancelled'}},{'memberships/b_org':member('b',{status:'pending'})}]) await assert.rejects(fixture({'memberships/a_org':member('a',{role:'orgAdmin'}),...changes}).attendance(req(data)),{code:'failed-precondition'});
});

test('active II-level member can maintain attendance during and after callout; change history is immutable and retries do not duplicate', async()=>{
 for(const status of ['active','closed']) {
  const f=fixture({'memberships/a_org':member('a',{seaRescueLevel:'level2'}),'callouts/c':{organizationId:'org',status}});
  const data={calloutId:'c',userId:'b',status:'confirmed',hours:2};
  await f.attendance(req(data));await f.attendance(req(data));
  let history=Object.entries(f.records).filter(([key])=>key.startsWith('callouts/c/attendanceHistory/')).map(([,v])=>v);
  assert.equal(history.length,1);assert.equal(history[0].before,null);assert.equal(history[0].createdBy,'a');assert.deepEqual(history[0].after,{status:'confirmed',hours:2});
  await f.attendance(req({...data,status:'absent'}));history=Object.entries(f.records).filter(([key])=>key.startsWith('callouts/c/attendanceHistory/')).map(([,v])=>v);
  assert.equal(history.length,2);assert.deepEqual(history[1].before,{status:'confirmed',hours:2});assert.deepEqual(history[1].after,{status:'absent',hours:null});
 }
});
test('first-level, removed, pending, conflicting and cross-org leaders cannot change attendance',async()=>{
 for(const extra of [{seaRescueLevel:'level1'},{seaRescueLevel:'level2',status:'removed'},{seaRescueLevel:'level2',isActive:false},{seaRescueLevel:'level2',status:'pending'},{seaRescueLevel:'level2',commandId:'other'}]) {
  const f=fixture({'memberships/a_org':member('a',extra)});
  await assert.rejects(f.attendance(req({calloutId:'c',userId:'b',status:'confirmed'})),{code:'permission-denied'});assert.equal(f.writes.length,0);
 }
});
