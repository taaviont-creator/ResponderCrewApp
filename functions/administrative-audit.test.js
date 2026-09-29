const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createAdministrativeAudit}=require('./administrative-audit');

test('administrative audit is idempotent, keeps actor and excludes private payload values',async()=>{
 const writes=new Map(),db={doc:path=>({create:async data=>{if(writes.has(path))throw {code:6};writes.set(path,data);}})};
 const handler=createAdministrativeAudit({db,source:'operationLogs'});
 const before={organizationId:'org',summary:'Enne'},after={...before,summary:'Pärast',updatedBy:'leader',privatePerson:'must not be copied'};
 const event={id:'delivery',authType:'service_account',params:{documentId:'log'},data:{before:{data:()=>before},after:{data:()=>after,updateTime:123}}};
 await handler(event);await handler(event);
 assert.equal(writes.size,1);
 assert.deepEqual([...writes.values()][0],{organizationId:'org',action:'operationLogs.updated',targetId:'log',changedFields:['summary'],createdBy:'leader',createdAt:123});
 await handler({...event,id:'ordinary',data:{before:{data:()=>after},after:{data:()=>({...after,updatedAt:456}),updateTime:456}}});
 assert.equal(writes.size,1);
});
