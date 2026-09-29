const {createHash} = require('node:crypto');
const {orgId} = require('./statistics-history');
function createAdministrativeAudit({db,source}) {
  const fields={commands:['name','status','profile'],memberships:['role','status','isActive','seaRescueLevel'],callouts:['title','description','location','status'],operationLogs:['summary','outcome','status']}[source];
  return async event=>{
    if (!event.data || !event.id) return;
    const before=event.data.before.data(),after=event.data.after.data();
    const changed=fields.filter(k=>JSON.stringify(before?.[k])!==JSON.stringify(after?.[k]));
    if (!changed.length) return;
    const organizationId=source==='commands'?event.params.documentId:orgId(after || before);
    if (!organizationId) return;
    const createdAt=event.data.after.updateTime || event.data.before.updateTime;
    const createdBy=event.authType==='service_account' ? (after?.updatedBy || after?.reviewedBy || after?.completedBy || 'server') : (event.authId || after?.updatedBy || after?.reviewedBy || after?.createdBy || 'unknown');
    const id=createHash('sha256').update(`${source}:${event.id}`).digest('hex');
    const ref=db.doc(`platformAudit/${id}`);
    try { await ref.create({organizationId,action:`${source}.${before?'updated':'created'}`,targetId:event.params.documentId,changedFields:changed,createdBy,createdAt}); }
    catch(error) {if(error.code!==6 && error.code!=='already-exists') throw error;}
  };
}
module.exports={createAdministrativeAudit};
