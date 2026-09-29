const {test}=require('node:test');const assert=require('node:assert/strict');
const {createCalloutAlarmHandler}=require('./callout-alarm-delivery');
function fixture({status='active',orgStatus='approved',tokens=[{token:'secret'}],failure=false}={}) {
 let claimed=false,calls=0,record;
 const current={organizationId:'org',status};
 const db={doc:path=>path.startsWith('commands/')?{get:async()=>({exists:true,data:()=>({status:orgStatus})})}:{
 create:async value=>{if(claimed)throw {code:6};claimed=true;record=value;},update:async value=>Object.assign(record,value)}};
 const handler=createCalloutAlarmHandler({db,loadMembers:async()=>['u'],loadTokens:async()=>tokens,
 sendAlarm:async()=>{calls++;if(failure)throw Error('timeout');return {successCount:1,failureCount:0}},logger:{warn(){},error(){}}});
 const event={params:{calloutId:'c'},data:{data:()=>({organizationId:'org',status:'active'}),ref:{get:async()=>({data:()=>current})}}};
 return {handler,event,get calls(){return calls},get record(){return record}};
}
test('concurrent repeated Firestore events send the callout alarm only once',async()=>{
 const f=fixture();await Promise.all(Array.from({length:8},()=>f.handler(f.event)));assert.equal(f.calls,1);assert.equal(f.record.status,'accepted');assert.equal(f.record.token,undefined);
});
test('ambiguous send failure is recorded and never resent blindly',async()=>{
 const f=fixture({failure:true});await f.handler(f.event);await f.handler(f.event);assert.equal(f.calls,1);assert.equal(f.record.status,'unknown');
});
test('closed callout, suspended organization and absent tokens do not send',async()=>{
 for(const options of [{status:'closed'},{orgStatus:'suspended'},{tokens:[]}]){const f=fixture(options);await f.handler(f.event);assert.equal(f.calls,0);assert.equal(f.record,undefined);}
});
