const {createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {DateTime} = require('luxon');
const {access,organizationDocs} = require('./statistics-handlers');
const {orgId,millis} = require('./statistics-history');
const {active} = require('./contribution-statistics');
const validId=v=>typeof v==='string' && /^[a-zA-Z0-9_-]{1,128}$/.test(v);
const key=(...v)=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const fail=(code,message)=>{throw new HttpsError(code,message);};
function draft(data) {
  const result={};
  for(const [field,max] of Object.entries({name:200,location:300,nextMaintenanceDate:10,note:2000})) {
    const value=data?.[field];
    if(typeof value!=='string' || value.length>max) fail('invalid-argument','Kontrolli varustuse andmeid.');
    result[field]=value.trim();
  }
  if(!result.name || !['vessel','engine','trailer','vehicle','machinery','rescue','safety','medical','radio','other'].includes(data.category) ||
      !['ok','needsMaintenance','broken','outOfService'].includes(data.status) || (data.status!=='ok'&&!result.note) ||
      (result.nextMaintenanceDate && (!/^\d{4}-\d{2}-\d{2}$/.test(result.nextMaintenanceDate) || !DateTime.fromISO(result.nextMaintenanceDate).isValid))) fail('invalid-argument','Kontrolli nimetust, kategooriat, olekut ja kuupäeva.');
  return {...result,category:data.category,status:data.status};
}
function createEquipmentLifecycle({db,timestamp}) {
  const reader=tx=>({doc:path=>({get:()=>tx.get(db.doc(path))})});
  function notify(tx,org,uid,id,title,message) {
    const notificationId=key(id,uid);
    tx.create(db.doc(`userNotifications/${notificationId}`),{id:notificationId,organizationId:org,commandId:org,recipientUserId:uid,
      title,message,type:'equipment',priority:'normal',relatedType:'equipment_request',relatedId:id,createdBy:'system',createdAt:timestamp(),updatedAt:timestamp()});
  }
  function approve(tx,ref,r,actor,uid,member) {
    tx.create(db.doc(`equipment/${ref.id || ref.path.split('/').at(-1)}`),{
      ...r.item,id:ref.id || ref.path.split('/').at(-1),organizationId:actor.org,commandId:actor.org,scope:'organization',storage:'shared',
      assignedToUserId:r.submittedBy,assignedToName:member.displayName || '',issuedBy:uid,issuedAt:timestamp(),
      createdBy:uid,submittedBy:r.submittedBy,createdAt:timestamp(),updatedAt:timestamp(),updatedBy:uid,
    });
  }
  return async request=>{
    const d=request.data || {};
    if(d.action==='list') {
      const actor=await access(db,request);
      let q=db.collection('equipmentRequests').where('organizationId','==',actor.org).where('status','==','pending');
      if(!actor.admin) q=q.where('submittedBy','==',request.auth.uid);
      const docs=(await q.limit(101).get()).docs;
      await access(db,request,{adminOnly:actor.admin});
      return {requests:docs.slice(0,100).map(doc=>({id:doc.id,...doc.data(),createdAt:millis(doc.data().createdAt)})),hasMore:docs.length>100};
    }
    if(!['submit','approve','reject','cancel','delete'].includes(d.action) || !validId(d.id)) fail('invalid-argument','Kontrolli toimingut.');
    const item=d.action==='submit'?draft(d.item):null;
    // Admin recipients are revalidated inside the write transaction.
    const actor=await access(db,request);
    const admins=d.action==='submit'&&!actor.admin?(await organizationDocs(db,'memberships',actor.org))
      .filter(m=>m.id===`${m.data().userId}_${actor.org}` && active(m.data()) && ['admin','orgAdmin'].includes(m.data().role)).map(m=>m.data().userId):[];
    if(admins.length>100) fail('resource-exhausted','Liiga palju administraatoreid.');
    return db.runTransaction(async tx=>{
      const fresh=await access(reader(tx),request);
      if(d.action==='delete') {
        const ref=db.doc(`equipment/${d.id}`),archive=db.doc(`equipmentArchive/${d.id}`);
        const [live,archived]=await tx.getAll(ref,archive),e=live.data() || archived.data();
        if(!e || orgId(e)!==fresh.org || (!fresh.admin && !(e.scope==='personal'&&e.ownerUserId===request.auth.uid))) fail('permission-denied','Kustutada saad enda isiklikku varustust. Ühingu varustust kustutab admin.');
        if(!live.exists) return {deleted:true};
        if(archived.exists) fail('failed-precondition','Selle tunnusega ese on juba arhiivis.');
        tx.create(archive,{...e,deletedBy:request.auth.uid,deletedAt:timestamp()});
        tx.create(db.doc(`equipment/${d.id}/history/deleted`),{organizationId:fresh.org,changed:['deleted'],before:e,after:null,
          actorId:request.auth.uid,actorName:fresh.membership.displayName || '',occurredAt:timestamp()});
        tx.delete(ref);
        return {deleted:true};
      }
      const requestId=key(fresh.org,d.action==='submit'?request.auth.uid:'',d.id);
      const ref=db.doc(`equipmentRequests/${d.action==='submit'?requestId:d.id}`);
      const existing=(await tx.get(ref)).data();
      if(d.action==='submit') {
        if(existing) return {status:existing.status};
        const recipients=[];
        for(const uid of admins) {
          const m=(await tx.get(db.doc(`memberships/${uid}_${fresh.org}`))).data();
          if(orgId(m)===fresh.org && m?.userId===uid && active(m) && ['admin','orgAdmin'].includes(m.role)) recipients.push(uid);
        }
        const r={organizationId:fresh.org,submittedBy:request.auth.uid,submittedByName:fresh.membership.displayName || '',item,
          status:fresh.admin?'approved':'pending',createdAt:timestamp()};
        tx.create(ref,r);
        if(fresh.admin) approve(tx,ref,r,fresh,request.auth.uid,fresh.membership);
        else for(const uid of recipients) notify(tx,fresh.org,uid,requestId,'Varustus ootab kinnitamist',`${r.submittedByName || 'Liige'}: ${item.name}. Vaata Varustus → Kinnitust ootavad esemed.`);
        return {status:r.status};
      }
      if(!existing || existing.organizationId!==fresh.org) fail('permission-denied','Taotlust ei leitud.');
      if(d.action==='cancel' ? existing.submittedBy!==request.auth.uid : !fresh.admin) fail('permission-denied','Sul puudub kinnitamise õigus.');
      const next={approve:'approved',reject:'rejected',cancel:'cancelled'}[d.action];
      if(existing.status!== 'pending') {
        if(existing.status===next) return {status:next};
        fail('failed-precondition','Taotlus on juba lahendatud. Värskenda loendit.');
      }
      const member=(await tx.get(db.doc(`memberships/${existing.submittedBy}_${fresh.org}`))).data();
      if(d.action==='approve' && (!active(member) || orgId(member)!==fresh.org || member?.userId!==existing.submittedBy)) fail('failed-precondition','Varustust saab väljastada ainult aktiivsele liikmele.');
      if(d.action==='approve') approve(tx,ref,existing,fresh,request.auth.uid,member);
      tx.update(ref,{status:next,reviewedBy:request.auth.uid,reviewedAt:timestamp()});
      if(d.action!=='cancel') notify(tx,fresh.org,existing.submittedBy,`${d.id}-${next}`,
        d.action==='approve'?'Varustus kinnitatud':'Varustuse taotlus tagasi lükatud',
        `${existing.item.name}. ${d.action==='approve'?'Ese on sinu ja liikmete varustuse all.':'Täpsusta eseme arvestust ühingu adminiga.'}`);
      return {status:next};
    });
  };
}
module.exports={createEquipmentLifecycle,draft};
