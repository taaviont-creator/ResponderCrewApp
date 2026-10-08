const {createHash,randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access,organizationDocs} = require('./statistics-handlers');
const {orgId,millis} = require('./statistics-history');
const validId = v => typeof v==='string' && v.length>0 && v.length<=128 && !v.includes('/');
const statuses=['ok','needsMaintenance','broken','outOfService'];
async function equipmentAccess(db,request,edit=false) {
  const actor=await access(db,request);
  const id=request.data?.equipmentId;
  if(!validId(id)) throw new HttpsError('invalid-argument','Vali varustus.');
  const ref=db.doc(`equipment/${id}`);
  let item=(await ref.get()).data();
  const archived=!item;
  if(!item && !edit) item=(await db.doc(`equipmentArchive/${id}`).get()).data();
  if(!item || orgId(item)!==actor.org ||
      (item.scope==='personal' && item.ownerUserId!==request.auth.uid && !actor.admin) ||
      (edit && !actor.admin && !(item.scope==='personal' && item.ownerUserId===request.auth.uid))) {
    throw new HttpsError('permission-denied','Sul puudub selle varustuse toimingu õigus.');
  }
  return {...actor,id,item,ref,archived};
}
function createSetEquipmentCondition({db,timestamp}) {
  return async request=>{
    const {status,note,expectedStatus,expectedNote}=request.data||{};
    if(!statuses.includes(status) || typeof note!=='string' || note.length>2000 ||
      typeof expectedStatus!=='string' || typeof expectedNote!=='string' ||
      (status!=='ok' && !note.trim())) throw new HttpsError('invalid-argument','Vali olek ning kirjelda probleemi.');
    return db.runTransaction(async tx=>{
      const reader={doc:path=>({get:()=>tx.get(db.doc(path))})};
      const {item,id}=await equipmentAccess(reader,request,true);
      if((item.status||'ok')!==expectedStatus || (item.note||'')!==expectedNote) {
        throw new HttpsError('aborted','Keegi muutis vahepeal olekut. Värskenda vaadet ja proovi uuesti.');
      }
      if(item.status===status && (item.note||'')===note.trim()) return {saved:true};
      tx.update(db.doc(`equipment/${id}`),{status,note:note.trim(),updatedBy:request.auth.uid,updatedAt:timestamp()});
      if(item.scope==='organization' && item.status!==status && status!=='ok') {
        const notificationId=randomUUID();
        const label={needsMaintenance:'vajab hooldust',broken:'katki / vajab remonti',outOfService:'hoolduses / kasutusest väljas'}[status];
        tx.create(db.doc(`notifications/${notificationId}`),{id:notificationId,organizationId:orgId(item),commandId:orgId(item),
          title:`Varustus: ${item.name}`,message:`${item.name}: ${label}. ${note.trim()}`,type:'equipment',
          priority:status==='needsMaintenance'?'normal':'high',relatedType:'equipment',relatedId:id,createdBy:request.auth.uid,createdAt:timestamp(),updatedAt:timestamp()});
      }
      return {saved:true};
    });
  };
}
function createEquipmentHistoryRecorder({db}) {
  return async event=>{
    if(!event.data || !event.id) return;
    const before=event.data.before.data(),after=event.data.after.data();
    const fields=['status','note','nextMaintenanceDate','storage','assignedToUserId','assignedToName'];
    const changed=fields.filter(k=>(before?.[k]??'')!==(after?.[k]??''));
    if(!changed.length) return;
    const organizationId=orgId(after||before);
    if(!organizationId) return;
    const actor=event.authType==='service_account' ? (after?.updatedBy||'server') : (event.authId||'unknown');
    const member=validId(actor)?(await db.doc(`memberships/${actor}_${organizationId}`).get()).data():null;
    const pick=data=>data?Object.fromEntries(fields.map(k=>[k,data[k]??''])):null;
    const ref=db.doc(`equipment/${event.params.equipmentId}/history/${createHash('sha256').update(event.id).digest('hex')}`);
    try {
      await ref.create({organizationId,before:pick(before),after:pick(after),changed,
        actorId:actor,actorName:member?.displayName|| (actor==='server'?'Süsteem':'Kasutaja'),
        occurredAt:event.data.after.updateTime||event.data.before.updateTime});
    } catch(e) { if(e.code!==6 && e.code!=='already-exists') throw e; }
  };
}
function summarizeWork(activities,participants,members) {
  const names=new Map(members.map(m=>[m.userId,m.displayName||'Liige']));
  return activities.map(a=>{
    const seen=new Set();
    const crew=participants.filter(p=>p.activityId===a.id && p.userId && p.attendanceStatus!=='absent' &&
      (p.attendanceStatus==='confirmed' || p.status==='attendedSelfReported')).filter(p=>{
      if(seen.has(p.userId)) return false;seen.add(p.userId);return true;
    }).map(p=>({name:names.get(p.userId)||'Endine liige',confirmed:p.attendanceStatus==='confirmed',
      hours:typeof p.hours==='number' && Number.isFinite(p.hours) && p.hours>=0?p.hours:null}));
    return {id:a.id,title:a.title||'Töö',type:a.type,date:a.startTime,description:a.description||'',crew,
      confirmedHours:crew.filter(p=>p.confirmed).reduce((n,p)=>n+(p.hours||0),0),
      pendingCount:crew.filter(p=>!p.confirmed).length};
  }).sort((a,b)=>(Date.parse(b.date)||0)-(Date.parse(a.date)||0));
}
function createGetEquipmentCare({db}) {
  return async request=>{
    const {org,id,item,admin,archived}=await equipmentAccess(db,request);
    let query=db.collection(`equipment/${id}/history`).orderBy('occurredAt','desc');
    if(request.data?.cursor) {
      if(!validId(request.data.cursor)) throw new HttpsError('invalid-argument','Vigane ajaloo lehekülg.');
      const cursor=await db.doc(`equipment/${id}/history/${request.data.cursor}`).get();
      if(!cursor.exists) throw new HttpsError('invalid-argument','Värskenda ajalugu.');
      query=query.startAfter(cursor);
    }
    const history=await query.limit(51).get();
    let works=[],workLimitReached=false;
    // Clients cannot write links or audit records. Hours remain in the original
    // activityParticipants, so confirmation/correction is reflected on reload.
    if(item.scope==='organization' && !request.data?.cursor) {
      const links=await db.collection('equipmentWorkLinks').where('equipmentId','==',id).limit(501).get();
      workLimitReached=links.docs.length>500;
      const scoped=links.docs.slice(0,500).map(d=>d.data()).filter(d=>d.organizationId===org&&validId(d.activityId));
      const activities=[];const participants=[];
      for(let i=0;i<scoped.length;i+=25) {
        await Promise.all(scoped.slice(i,i+25).map(async link=>{
          const [a,ps]=await Promise.all([db.doc(`activities/${link.activityId}`).get(),db.collection('activityParticipants').where('activityId','==',link.activityId).get()]);
          if(orgId(a.data())!==org || !['maintenance','repair'].includes(a.data()?.type)) return;
          activities.push({...a.data(),id:link.activityId});
          for(const p of ps.docs) if(orgId(p.data())===org) participants.push(p.data());
        }));
      }
      const members=activities.length?await organizationDocs(db,'memberships',org):[];
      works=summarizeWork(activities,participants,members.map(d=>d.data()));
    }
    // Recheck revocation before returning the assembled response.
    await equipmentAccess(db,request);
    return {status:item.status||'ok',note:item.note||'',archived,canEdit:!archived && (admin||item.ownerUserId===request.auth.uid),
      history:history.docs.slice(0,50).map(d=>({id:d.id,...d.data(),occurredAt:millis(d.data().occurredAt)})),
      nextCursor:history.docs.length>50?history.docs[49].id:null,works,workLimitReached};
  };
}
module.exports={equipmentAccess,createSetEquipmentCondition,createEquipmentHistoryRecorder,createGetEquipmentCare,summarizeWork};
