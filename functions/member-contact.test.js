const {test}=require('node:test'); const assert=require('node:assert/strict');
const {createMemberContactHandler}=require('./member-contact');
const member=(userId,extra={})=>({userId,organizationId:'org',commandId:'org',status:'active',isActive:true,role:'member',...extra});
function fixture(overrides={}) {
  const records={'commands/org':{status:'approved'},'memberships/a_org':member('a'),'memberships/b_org':member('b'),
    'users/b':{phone:'+372 555 1234',email:'private@example.test',name:'Private'},...overrides};
  const reads=[];const get=async ref=>{reads.push(ref);return {data:()=>records[ref]};};
  return {reads,handler:createMemberContactHandler({db:{doc:path=>path,runTransaction:fn=>fn({get,getAll:(...refs)=>Promise.all(refs.map(get))})}})};
}
const request={auth:{uid:'a'},data:{organizationId:'org',userId:'b'}};
test('active peers can fetch only the phone field',async()=>{const {handler}=fixture();assert.deepEqual(await handler(request),{phone:'+372 555 1234'});});
test('authentication and valid IDs required before reads',async()=>{const {handler,reads}=fixture();
 await assert.rejects(handler({data:request.data}),{code:'unauthenticated'});
 await assert.rejects(handler({...request,data:{...request.data,userId:'users/b'}}),{code:'invalid-argument'});assert.equal(reads.length,0);});
test('pending, removed, conflicting and cross-org memberships cannot read contacts',async()=>{
 for(const key of ['memberships/a_org','memberships/b_org']) for(const extra of [
  {status:'pending',isActive:false},{status:'removed',isActive:true},{status:'active',isActive:false},
  {organizationId:'other'},{commandId:'other'},{userId:'different'},
 ]){const {handler,reads}=fixture({[key]:member(key.includes('/a_')?'a':'b',extra)});
 await assert.rejects(handler(request),{code:'permission-denied'});assert.ok(!reads.includes('users/b'));}
});
test('missing membership or unapproved organization cannot read profile',async()=>{
 for(const overrides of [{'memberships/b_org':undefined},{'commands/org':{status:'pending'}},{'commands/org':undefined}]){
 const {handler,reads}=fixture(overrides);await assert.rejects(handler(request),{code:'permission-denied'});assert.ok(!reads.includes('users/b'));}
});
test('missing phone returns a truthful empty result without other fields',async()=>{const {handler}=fixture({'users/b':{name:'B',email:'private@example.test'}});assert.deepEqual(await handler(request),{phone:null});});
