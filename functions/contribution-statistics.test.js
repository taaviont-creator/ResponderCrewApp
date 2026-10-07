const {test}=require('node:test');const assert=require('node:assert/strict');
const {aggregate,period,dateMillis,versionTimelines,dutyForMember}=require('./contribution-statistics');
const {project,createHistoryHandler}=require('./statistics-history');
const time=s=>Date.parse(s), start=time('2026-09-01T00:00:00Z');
const member={userId:'u',organizationId:'org',status:'active',isActive:true,displayName:'Liige U',joinedAt:start-100};
const manual=status=>({userId:'u',organizationId:'org',status});
const rec=(source,id,data,version=start-1)=>({source,id,data,version});
const change=(source,sourceId,at,before,after)=>({organizationId:'org',userId:'u',source,sourceId,at,before,after});
const base={organizationId:'org',from:'2026-09-01',to:'2026-09-01',now:start+12*3600000,trackingStart:start,current:[rec('memberships','u_org',member),rec('availability','u_org',manual('onDuty'))],history:[],memberships:[member],activities:[],participants:[],callouts:[],responses:[],attendance:[]};
const hours=(options={})=>aggregate({...base,...options}).members[0];

test('event extract preserves callouts without attendance and shares the confirmed deduplicated source',()=>{
 const c={id:'c',organizationId:'org',title:'SAR',createdAt:start,status:'closed',closedAt:start+3600000,description:'private detail'};
 const p={organizationId:'org',calloutId:'c',userId:'u',status:'confirmed',hours:2};
 const result=aggregate({...base,includeEventDetails:true,
   callouts:[c,{...c,id:'empty',calloutType:'tross'},{...c,id:'cancel',status:'cancelled'},
     {...c,id:'test',isTest:true},{...c,id:'foreign',organizationId:'other'},{...c,id:'undated',createdAt:null}],
   attendance:[p,p,{...p,calloutId:'cancel'},{...p,userId:'pending',status:'pending'},
     {...p,userId:'foreign',organizationId:'other'},{...p,userId:'former',userName:'Endine liige',hours:null}],
   responses:[{...p,userId:'responder',response:'responding'}]});
 assert.equal(result.eventDetails.length,result.events.period);
 assert.equal(result.eventDetails.length,3);
 const event=result.eventDetails.find(e=>e.id==='c');
 assert.equal(event.participants.length,2);assert.equal(event.participants.find(p=>p.userId==='u').hours,2);
 assert.equal(event.participants.find(p=>p.userId==='former').hours,null);
 assert.equal(event.endedAt,new Date(start+3600000).toISOString());
 assert.equal(Object.hasOwn(event,'description'),false);
 assert.deepEqual(result.eventDetails.find(e=>e.id==='cancel').participants,[]);
 assert.deepEqual(result.eventDetails.find(e=>e.id==='empty').participants,[]);
 assert.equal(result.events.undated,1);
 assert.equal(Object.hasOwn(aggregate({...base,callouts:[c]}),'eventDetails'),false);
});

test('annual event extract includes Tallinn year boundaries and leap day without next-year records',()=>{
 const callout=(id,date)=>({id,organizationId:'org',createdAt:date,status:'closed'});
 const result=aggregate({...base,from:'2024-01-01',to:'2024-12-31',now:Date.parse('2025-02-01'),includeEventDetails:true,
   callouts:[callout('before','2023-12-31T21:59:59Z'),callout('first','2023-12-31T22:00:00Z'),
     callout('leap','2024-02-29T12:00:00Z'),callout('last','2024-12-31T21:59:59Z'),callout('after','2024-12-31T22:00:00Z')]});
 assert.deepEqual(result.eventDetails.map(e=>e.id),['last','leap','first']);
});
test('unchanged duty starts at tracking activation, never fabricates older hours',()=>{assert.equal(hours().dutyHours,12);assert.equal(hours({trackingStart:null}).dutyHours,null);assert.equal(hours({to:'2026-08-31',from:'2026-08-01'}).dutyHours,null);});

test('geofence duty stops at evidence expiry even when cleanup has not yet run',()=>{
 const a={...manual('onDuty'),geofenceUntil:start+3*3600000};
 assert.equal(hours({current:[base.current[0],rec('availability','u_org',a)]}).dutyHours,3);
 const projected=project('availability',{...a,updatedAt:new Date(start),geofenceAppliedAt:new Date(start)});
 assert.equal(projected.geofenceUntil,a.geofenceUntil);
 assert.equal(project('availability',{...a,updatedAt:new Date(start+1),geofenceAppliedAt:new Date(start)}).geofenceUntil,undefined);
});
test('manual changes replay in commit order; delayed duty remains separate',()=>{
 const at=start+4*3600000,end=start+8*3600000;
 const history=[change('availability','u_org',end,manual('delayed'),manual('offDuty')),change('availability','u_org',at,manual('onDuty'),manual('delayed'))];
 const row=hours({history,current:[base.current[0],rec('availability','u_org',manual('offDuty'),end)]});assert.equal(row.dutyHours,4);assert.equal(row.delayedHours,4);
});
test('new availability starts at creation; pending trigger cannot backfill current state',()=>{
 const at=start+5*3600000,current=[base.current[0],rec('availability','u_org',manual('onDuty'),at)];
 assert.equal(hours({current}).dutyHours,null);
 assert.equal(hours({current,history:[change('availability','u_org',at,null,manual('onDuty'))]}).dutyHours,7);
});
test('absence overlaps subtract once and cancellation preserves earlier absence',()=>{
 const one={...manual('active'),startAt:start+3600000,endAt:start+6*3600000};
 const two={...manual('active'),startAt:start+3*3600000,endAt:start+8*3600000};
 const at=start+4*3600000, cancelled={...two,status:'cancelled'};
 assert.equal(hours({current:[...base.current,rec('plannedUnavailability','one',one),rec('plannedUnavailability','two',two)]}).dutyHours,5);
 assert.equal(hours({current:[...base.current,rec('plannedUnavailability','one',one),rec('plannedUnavailability','two',cancelled,at)],history:[change('plannedUnavailability','two',at,two,cancelled)]}).dutyHours,7);
});
test('recurring absence obeys Tallinn weekday and date limits',()=>{
 const rule={...manual('active'),daysOfWeek:[2],startMinute:240,endMinute:360};
 assert.equal(hours({current:[...base.current,rec('plannedUnavailabilityRules','r',rule)]}).dutyHours,10);
});
test('DST fall-back counts both repeated hours, spring-forward only actual elapsed time',()=>{
 for(const [day,expected,total] of [['2026-10-25',23,25],['2026-03-29',23,23]]) {
  const range=period(day,day), m={...member,joinedAt:range.start-1};
  const current=[rec('memberships','u_org',m,range.start-1),rec('availability','u_org',manual('onDuty'),range.start-1)];
  const lines=versionTimelines(current,[],range.start,range.end).lines;
  assert.equal(dutyForMember('u',lines,range.start,range.end).dutyHours,total);
  const rule=rec('plannedUnavailabilityRules','r',{...manual('active'),daysOfWeek:[7],startMinute:180,endMinute:240},range.start-1);
  assert.equal(dutyForMember('u',versionTimelines([...current,rule],[],range.start,range.end).lines,range.start,range.end).dutyHours,expected);
 }
});
test('member removal stops duty, and canonical inactive membership overrides legacy active',()=>{
 const at=start+3*3600000,removed={...member,status:'removed',isActive:false};
 const current=[rec('memberships','u_org',removed,at),base.current[1],rec('memberships','legacy',member)];
 assert.equal(hours({current,history:[change('memberships','u_org',at,member,removed)]}).dutyHours,3);
});
test('confirmed activities use activity date, categories and known hours; intent is pending',()=>{
 const a={id:'a',organizationId:'org',title:'Repair',type:'repair',startTime:'2026-09-01 10:00'};
 const b={...a,id:'b',type:'training'},p={organizationId:'org',activityId:'a',userId:'u',attendanceStatus:'confirmed',hours:2};
 const row=hours({activities:[a,b],participants:[p,{...p},{...p,activityId:'b',attendanceStatus:'notConfirmed',status:'registered',hours:4}]});
 assert.equal(row.activityCount,1);assert.equal(row.contributionHours,2);assert.equal(row.pendingCount,1);assert.deepEqual(row.categories,{repair:{count:1,hours:2}});
});
test('missing hours stay unknown and invalid/foreign/future records cannot inflate stats',()=>{
 const a={id:'a',organizationId:'org',title:'Work',type:'maintenance',startTime:'2026-09-01'};
 const p={organizationId:'org',activityId:'a',userId:'u',attendanceStatus:'confirmed'};
 const row=hours({activities:[a,{...a,id:'future',startTime:'2026-09-02'},{...a,id:'bad',startTime:'n/a'}],participants:[p,{...p,organizationId:'other',hours:100},{...p,activityId:'future',hours:3},{...p,activityId:'bad'}]});
 assert.equal(row.unknownHoursCount,1);assert.equal(row.activityCount,1);assert.equal(row.contributionHours,0);
});
test('callout response is distinct from actual attendance; cancellations excluded',()=>{
 const c={id:'c',organizationId:'org',createdAt:start,title:'Callout',status:'closed'};
 const r={calloutId:'c',organizationId:'org',userId:'u',response:'responding'};
 assert.equal(hours({callouts:[c],responses:[r]}).calloutCount,0);
 const row=hours({callouts:[c],responses:[r],attendance:[{...r,status:'confirmed',hours:3}]});
 assert.equal(row.calloutCount,1);assert.equal(row.responseCount,1);assert.equal(row.contributionHours,3);
 assert.equal(hours({callouts:[{...c,status:'cancelled'}],responses:[r],attendance:[{...r,status:'confirmed'}]}).calloutCount,0);
});
test('period validation rejects malformed, inverted and oversized ranges; dates inclusive in Tallinn',()=>{
 for(const pair of [[{},'2026-01-01'],['invalid','invalid'],['2026-02-30','2026-03-01'],['2026-09-02','2026-09-01'],['2025-01-01','2026-02-01']]) assert.equal(period(...pair),null);
 assert.equal(dateMillis('2026-09-01 18:00'),time('2026-09-01T15:00:00Z'));
 assert.equal(period('2026-09-01','2026-09-01').end,time('2026-09-01T21:00:00Z'));
});
test('history projection excludes personal fields and preserves commit timestamp; retries idempotent',async()=>{
 assert.deepEqual(project('availability',{...manual('onDuty'),email:'private',phone:'secret'}),manual('onDuty'));
 const writes=new Map();const handler=createHistoryHandler({source:'availability',db:{collection:()=>({doc:id=>({create:async data=>{if(writes.has(id)){throw {code:6};}writes.set(id,data);}})})}});
 const event={id:'event',params:{documentId:'u_org'},time:new Date(start+20).toISOString(),data:{before:{data:()=>manual('offDuty')},after:{data:()=>manual('onDuty'),updateTime:{toMillis:()=>start}}}};
 await handler(event);await handler(event);assert.equal(writes.size,1);assert.equal([...writes.values()][0].at,start);
 await handler({...event,id:'deleted',data:{before:{data:()=>manual('onDuty')},after:{data:()=>undefined}}});assert.equal(writes.size,2);assert.equal([...writes.values()][1].after,null);
});


test('organization pauses subtract overlapping intervals once and do not suppress contributions',()=>{
 const pause=(a,b,org='org')=>({organizationId:org,startAt:start+a*3600000,endAt:b===null?null:start+b*3600000});
 const activity={id:'training',organizationId:'org',title:'Training',type:'training',startTime:'2026-09-01 10:00'};
 const options={dutyPauses:[pause(1,6),pause(3,8),pause(0,null,'other')],activities:[activity],participants:[{organizationId:'org',activityId:'training',userId:'u',attendanceStatus:'confirmed',hours:2}]};
 const row=hours(options);assert.equal(row.dutyHours,5);assert.equal(row.activityCount,1);assert.equal(row.contributionHours,2);
 assert.equal(hours({dutyPauses:[pause(4,null)]}).dutyHours,4);
 assert.equal(hours({dutyPauses:[pause(-5,0),pause(12,20)]}).dutyHours,12);
 assert.equal(hours({current:[base.current[0],rec('availability','u_org',manual('delayed'))],dutyPauses:[pause(4,null)]}).delayedHours,4);
});

test('event totals are scoped, deduplicated and separate period, type and completion',()=>{
 const c={id:'sar',organizationId:'org',createdAt:start,status:'closed',calloutType:'sar'};
 const result=aggregate({...base,callouts:[c,c,{...c,id:'tross',calloutType:'tross',status:'active'},{...c,id:'cancel',status:'cancelled'},{...c,id:'old',createdAt:start-86400000},{...c,id:'foreign',organizationId:'other'},{...c,id:'unknown',createdAt:null}]});
 assert.deepEqual(result.events,{total:5,period:3,sar:2,tross:1,closed:1,cancelled:1,undated:1});
});

test('corrected event start moves participation and event counts to the corrected period',()=>{
 const c={id:'c',organizationId:'org',createdAt:start,startedAt:start-86400000,status:'closed',calloutType:'tross'};
 const attendance=[{calloutId:'c',organizationId:'org',userId:'u',status:'confirmed',hours:3}];
 const result=aggregate({...base,callouts:[c],attendance});assert.equal(result.events.period,0);assert.equal(result.members[0].calloutCount,0);
 const previous=aggregate({...base,from:'2026-08-31',to:'2026-08-31',callouts:[c],attendance});assert.equal(previous.events.period,1);assert.equal(previous.events.tross,1);assert.equal(previous.members[0].calloutCount,1);
});

test('test callout never enters official event totals, responses or member contribution; activities stay counted',()=>{
 const c={id:'test',organizationId:'org',isTest:true,calloutType:'sar',status:'closed',createdAt:start+1000};
 const response={organizationId:'org',calloutId:'test',userId:'u',response:'responding'};
 const attendance=[{...response,status:'confirmed',hours:5}];
 const result=aggregate({...base,callouts:[c],responses:[response],attendance,
   activities:[{id:'training',organizationId:'org',type:'training',startTime:start+1000}],
   participants:[{activityId:'training',organizationId:'org',userId:'u',attendanceStatus:'confirmed',hours:2}]});
 assert.equal(result.events.total,0);assert.equal(result.events.sar,0);assert.equal(result.events.closed,0);
 assert.equal(result.members[0].calloutCount,0);assert.equal(result.members[0].responseCount,0);assert.equal(result.members[0].contributionHours,2);
 assert.equal(c.isTest,true);assert.equal(attendance.length,1);
 const old=aggregate({...base,callouts:[{...c,isTest:undefined}],attendance});assert.equal(old.events.total,1);assert.equal(old.members[0].calloutCount,1);
});
