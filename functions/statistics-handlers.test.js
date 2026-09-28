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
 const blocked=fixture({'commands/org':{status:'approved'}});await assert.rejects(blocked.record(req(contribution)),{code:'permission-denied'});
 const pending=fixture({'memberships/a_org':member('a',{role:'orgAdmin'}),'memberships/b_org':member('b',{status:'pending'})});await assert.rejects(pending.record(req({...contribution,memberIds:['b']})),{code:'failed-precondition'});assert.equal(pending.writes.length,0);
});
test('invalid contribution fields and cross-org idempotency collisions are rejected',async()=>{
 for(const invalid of [{hours:0},{hours:NaN},{hours:25},{date:'2027-01-01'},{date:{}},{type:'__proto__'},{title:''},{memberIds:[]},{requestId:'../bad'}]) await assert.rejects(fixture().record(req({...contribution,...invalid})),{code:'invalid-argument'});
 await assert.rejects(fixture({'activities/contribution_unique':{organizationId:'other',createdBy:'a'}}).record(req(contribution)),{code:'already-exists'});
});
test('only admin confirms actual callout attendance; confirmation and hours can be corrected',async()=>{
 const data={calloutId:'c',userId:'b',status:'confirmed',hours:3};
 await assert.rejects(fixture().attendance(req(data)),{code:'permission-denied'});
 const f=fixture({'memberships/a_org':member('a',{role:'orgAdmin'})});await f.attendance(req(data));assert.equal(f.records['calloutAttendance/c_b'].hours,3);
 await f.attendance(req({...data,status:'absent'}));assert.equal(f.records['calloutAttendance/c_b'].hours,null);
 for(const changes of [{'callouts/c':{organizationId:'other'}},{'callouts/c':{organizationId:'org',status:'cancelled'}},{'memberships/b_org':member('b',{status:'pending'})}]) await assert.rejects(fixture({'memberships/a_org':member('a',{role:'orgAdmin'}),...changes}).attendance(req(data)),{code:'failed-precondition'});
});
