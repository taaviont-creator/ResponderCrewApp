const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createSetEquipmentCondition,createGetEquipmentCare,createEquipmentHistoryRecorder,summarizeWork}=require('./equipment-care');
const {createRecordContributionHandler}=require('./statistics-handlers');
const member=(uid,role='member')=>({userId:uid,organizationId:'org',status:'active',isActive:true,role,displayName:uid});
function fixture(){
  const records={'commands/org':{status:'approved'},'memberships/admin_org':member('admin','orgAdmin'),'memberships/a_org':member('a'),
    'equipment/boat':{id:'boat',organizationId:'org',scope:'organization',category:'vessel',name:'Alus',status:'ok',note:'',storage:'shared'},
    'equipment/private':{organizationId:'org',scope:'personal',ownerUserId:'a',status:'ok',note:''},
    'equipment/foreign':{organizationId:'other',scope:'organization',status:'ok',note:''}};
  const snapshot=path=>({id:path.split('/').at(-1),exists:!!records[path],data:()=>records[path]});
  const create=(ref,data)=>{if(records[ref.path])throw Object.assign(new Error('exists'),{code:6});records[ref.path]=data;};
  const db={doc:path=>({path,get:async()=>snapshot(path),create:async data=>create({path},data)}),
    collection:path=>{let rows=Object.keys(records).filter(p=>p.startsWith(`${path}/`)&&p.slice(path.length+1).split('/').length===1).map(snapshot);
      const q={where:(f,op,v)=>{rows=rows.filter(d=>d.data()[f]===v);return q;},orderBy:f=>{rows.sort((a,b)=>b.data()[f]-a.data()[f]);return q;},limit:n=>{rows=rows.slice(0,n);return q;},startAfter:s=>{rows=rows.slice(rows.findIndex(d=>d.id===s.id)+1);return q;},get:async()=>({docs:rows})};return q;},
    runTransaction:async fn=>fn({get:async ref=>snapshot(ref.path),getAll:async(...refs)=>refs.map(ref=>snapshot(ref.path)),create,update:(ref,data)=>{records[ref.path]={...records[ref.path],...data};}})};
  return {db,records,set:createSetEquipmentCondition({db,timestamp:()=>123}),get:createGetEquipmentCare({db}),record:createRecordContributionHandler({db,timestamp:()=>123,now:()=>Date.parse('2026-10-07T12:00Z')})};
}
const request=(uid='admin',data={})=>({auth:{uid},data:{organizationId:'org',equipmentId:'boat',...data}});
const condition={status:'broken',note:'Mootor ei käivitu',expectedStatus:'ok',expectedNote:''};
test('only real organization admin can change shared condition; owner can change personal item',async()=>{
 const f=fixture();
 await assert.rejects(f.set({...request('a',condition),auth:{uid:'a',token:{platformAdmin:true}}}),{code:'permission-denied'});
 await f.set(request('admin',condition));
 assert.equal(f.records['equipment/boat'].status,'broken');
 assert.equal(f.records['equipment/boat'].updatedBy,'admin');
 assert.equal(Object.keys(f.records).filter(p=>p.startsWith('notifications/')).length,1);
 await assert.rejects(f.set(request('admin',condition)),{code:'aborted'});
 assert.equal(f.records['equipment/boat'].status,'broken');
 await f.set(request('a',{...condition,equipmentId:'private'}));
 await assert.rejects(f.set(request('admin',{...condition,equipmentId:'foreign'})),{code:'permission-denied'});
 await assert.rejects(f.set(request('admin',{...condition,status:'invented'})),{code:'invalid-argument'});
 await assert.rejects(f.set(request('admin',{...condition,note:' '})),{code:'invalid-argument'});
});
test('history is server-authored, idempotent and ignores irrelevant updates',async()=>{
 const f=fixture(),record=createEquipmentHistoryRecorder({db:f.db});
 const before={...f.records['equipment/boat']},after={...before,status:'broken',note:'Mootor',updatedBy:'forged'};
 const event={id:'event',params:{equipmentId:'boat'},authType:'unknown',authId:'admin',data:{before:{data:()=>before,updateTime:100},after:{data:()=>after,updateTime:200}}};
 await record(event);await record(event);
 const history=Object.entries(f.records).filter(([p])=>p.includes('/history/'));
 assert.equal(history.length,1);assert.equal(history[0][1].actorId,'admin');
 assert.equal(history[0][1].before.status,'ok');assert.equal(history[0][1].after.note,'Mootor');
 await record({...event,id:'second',data:{...event.data,after:{data:()=>({...before,name:'Renamed'}),updateTime:300}}});
 assert.equal(Object.keys(f.records).filter(p=>p.includes('/history/')).length,1);
});
test('linked work remains one contribution, validates organization/type, and totals only confirmed people',async()=>{
 const f=fixture();
 const data={requestId:'work',title:'Remont',type:'repair',date:'2026-10-06',hours:2.5,memberIds:['a'],equipmentId:'boat'};
 await f.record(request('a',data));await f.record(request('a',data));
 assert.equal(Object.keys(f.records).filter(p=>p.startsWith('equipmentWorkLinks/')).length,1);
 let care=await f.get(request('a'));
 assert.equal(care.works[0].confirmedHours,0);assert.equal(care.works[0].pendingCount,1);
 f.records['activityParticipants/contribution_work_a'].attendanceStatus='confirmed';
 care=await f.get(request('a'));assert.equal(care.works[0].confirmedHours,2.5);
 f.records['activityParticipants/contribution_work_a'].hours=1;
 care=await f.get(request('a'));assert.equal(care.works[0].confirmedHours,1);
 assert.equal(f.records['equipment/boat'].status,'ok');
 await assert.rejects(f.record(request('a',{...data,requestId:'foreign',equipmentId:'foreign'})),{code:'permission-denied'});
 await assert.rejects(f.record(request('a',{...data,requestId:'private',equipmentId:'private'})),{code:'permission-denied'});
 await assert.rejects(f.record(request('a',{...data,requestId:'mowing',type:'groundskeeping'})),{code:'invalid-argument'});
 await assert.rejects(f.get(request('a',{equipmentId:'foreign'})),{code:'permission-denied'});
});
test('read permission, full history pagination and personal privacy are enforced',async()=>{
 const f=fixture();f.records['memberships/b_org']=member('b');
 for(let i=0;i<55;i++)f.records[`equipment/boat/history/h${i}`]={organizationId:'org',occurredAt:i};
 const first=await f.get(request('a'));assert.equal(first.history.length,50);assert.ok(first.nextCursor);
 const second=await f.get(request('a',{cursor:first.nextCursor}));assert.equal(second.history.length,5);assert.equal(second.nextCursor,null);
 await assert.rejects(f.get(request('b',{equipmentId:'private'})),{code:'permission-denied'});
 f.records['memberships/a_org'].status='removed';
 await assert.rejects(f.get(request('a')),{code:'permission-denied'});
});
test('work totals distinguish unknown hours, deduplicate attendance and exclude absent members',()=>{
 const rows=summarizeWork([{id:'a',type:'repair'}],[{activityId:'a',userId:'u',attendanceStatus:'confirmed',hours:null},{activityId:'a',userId:'u',attendanceStatus:'confirmed',hours:5},{activityId:'a',userId:'v',attendanceStatus:'absent',hours:10}],[]);
 assert.equal(rows[0].crew.length,1);assert.equal(rows[0].crew[0].hours,null);assert.equal(rows[0].confirmedHours,0);
});
