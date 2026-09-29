const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access, organizationDocs} = require('./statistics-handlers');
const {orgId, millis} = require('./statistics-history');
const {active} = require('./contribution-statistics');
const id = v => typeof v === 'string' && v.length > 0 && v.length <= 128 && !v.includes('/');
const text = (v, max = 10000) => typeof v === 'string' && v.length <= max;
function fail(message) { throw new HttpsError('invalid-argument', message); }
function serial(value) {
  if (value?.toDate) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(serial);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v]) => [k,serial(v)]));
  return value;
}
function validateReport(d) {
  if (!id(d.calloutId) || !id(d.operationLogId) || !id(d.authorUserId) ||
      !(d.leaderUserId === '' || id(d.leaderUserId)) || !['draft','completed'].includes(d.status) ||
      !Number.isInteger(d.revision) || d.revision < 0 || !text(d.expectedSummary) || !text(d.expectedOutcome) || !text(d.summary) || !text(d.outcome) || !text(d.suggestions) ||
      !Array.isArray(d.equipmentIds) || d.equipmentIds.length > 50 || d.equipmentIds.some(v => !id(v)) ||
      new Set(d.equipmentIds).size !== d.equipmentIds.length || !Array.isArray(d.persons) || d.persons.length > 50) fail('Kontrolli aruande andmeid.');
  const allowed = ['name','contact','identifier','role','notes'];
  const registrations=d.equipmentRegistration || {};
  if (typeof registrations!=='object' || Array.isArray(registrations) || Object.keys(registrations).length>50 ||
      Object.entries(registrations).some(([key,value])=>!d.equipmentIds.includes(key) || !text(value,100))) fail('Kontrolli tehnika registreerimisnumbreid.');
  for (const p of d.persons) if (!p || typeof p !== 'object' || Object.keys(p).some(k => !allowed.includes(k)) ||
      allowed.some(k => !text(p[k], k === 'notes' ? 2000 : 300))) fail('Kontrolli seotud isiku andmeid.');
}
function createGetReportHandler({db}) {
  return async request => {
    const actor = await access(db, request);
    const {calloutId} = request.data;
    if (!id(calloutId)) fail('Sündmuse tunnus puudub.');
    const callout = (await db.doc(`callouts/${calloutId}`).get()).data();
    if (!callout || orgId(callout) !== actor.org) throw new HttpsError('not-found','Sündmust ei leitud.');
    const canEdit = actor.admin || actor.membership.seaRescueLevel === 'level2';
    const [reportDoc, logDocs, attendance, memberships, equipment] = await Promise.all([
      db.doc(`calloutReports/${calloutId}`).get(),
      db.collection('operationLogs').where('calloutId','==',calloutId).get(),
      db.collection('calloutAttendance').where('calloutId','==',calloutId).get(),
      organizationDocs(db,'memberships',actor.org), organizationDocs(db,'equipment',actor.org),
    ]);
    const logs = logDocs.docs.filter(d => orgId(d.data()) === actor.org)
      .sort((a,b) => (millis(a.data().createdAt) || 0) - (millis(b.data().createdAt) || 0) || a.id.localeCompare(b.id));
    const metadata = reportDoc.exists ? reportDoc.data() : {status:'draft',revision:0,authorUserId:canEdit?request.auth.uid:'',leaderUserId:'',equipmentIds:[],suggestions:''};
    if (reportDoc.exists && orgId(metadata) !== actor.org) throw new HttpsError('permission-denied','Aruanne kuulub teisele ühingule.');
    const primary = logs.find(d => d.id === metadata.operationLogId) || logs[0];
    const timeline = [];
    if (callout.createdAt) timeline.push({id:`callout-${calloutId}-created`,title:'Väljakutse loodud',createdAt:callout.createdAt,type:'system',origin:'system'});
    if (callout.closedAt) timeline.push({id:`callout-${calloutId}-closed`,title:callout.status==='cancelled'?'Väljakutse tühistatud':'Väljakutse lõpetatud',createdAt:callout.closedAt,type:'system',origin:'system'});
    for (const log of logs) {
      const events = await db.collection(`operationLogs/${log.id}/events`).get();
      for (const event of events.docs) if (orgId(event.data()) === actor.org) timeline.push({id:event.id,...event.data(),origin:'member'});
    }
    timeline.sort((a,b) => (millis(a.occurredAt || a.createdAt) ?? Infinity) - (millis(b.occurredAt || b.createdAt) ?? Infinity) || a.id.localeCompare(b.id));
    const members = memberships.filter(m => orgId(m.data()) === actor.org && m.id === `${m.data().userId}_${actor.org}`)
      .map(m => ({userId:m.data().userId,name:m.data().displayName || 'Liige',level:m.data().seaRescueLevel || 'none',active:active(m.data())}));
    const crew = attendance.docs.filter(p => orgId(p.data()) === actor.org && p.data().status === 'confirmed').map(p => {
      const m = members.find(m => m.userId === p.data().userId);
      return {userId:p.data().userId,name:p.data().userName || m?.name || 'Liige',level:p.data().seaRescueLevel || m?.level || 'none',levelAtConfirmation:!!p.data().seaRescueLevel,hours:p.data().hours ?? null};
    });
    const allEquipment = equipment.filter(e => e.data().scope !== 'personal').map(e => ({id:e.id,name:e.data().name || e.data().title || 'Varustus',category:e.data().category || '',registrationNumber:e.data().registrationNumber || metadata.equipmentRegistration?.[e.id] || ''}));
    const privateData = canEdit ? (await db.doc(`calloutPrivate/${calloutId}`).get()).data() : null;
    // Private persons never enter the member response, even as empty placeholders.
    return serial({callout:{id:calloutId,...callout},organizationName:actor.organization.name || '',canEdit,
      report:metadata,operationLogId:primary?.id || null,summary:primary?.data().summary || '',outcome:primary?.data().outcome || '',
      authorName:members.find(m=>m.userId===metadata.authorUserId)?.name || 'Määramata',leaderName:members.find(m=>m.userId===metadata.leaderUserId)?.name || 'Määramata',
      crew,timeline,members:canEdit?members:[],equipment:allEquipment.filter(e => canEdit || metadata.equipmentIds?.includes(e.id)),
      ...(canEdit ? {persons:privateData?.persons || []} : {})});
  };
}
function createSaveReportHandler({db,timestamp}) {
  return async request => {
    validateReport(request.data || {});
    const d = request.data, changeId = randomUUID();
    return db.runTransaction(async tx => {
      const actor = await access({doc:path=>({get:()=>tx.get(db.doc(path))})},request,{crewOnly:true});
      const reportRef=db.doc(`calloutReports/${d.calloutId}`), logRef=db.doc(`operationLogs/${d.operationLogId}`), privateRef=db.doc(`calloutPrivate/${d.calloutId}`);
      const [c,r,l,p] = await tx.getAll(db.doc(`callouts/${d.calloutId}`),reportRef,logRef,privateRef);
      const callout=c.data(), old=r.data(), log=l.data();
      if (orgId(callout)!==actor.org || orgId(log)!==actor.org || log.calloutId!==d.calloutId || (old && (orgId(old)!==actor.org || old.operationLogId!==d.operationLogId))) throw new HttpsError('permission-denied','Sündmuse ja logi seos ei vasta ühingule.');
      if ((old?.revision || 0)!==d.revision) throw new HttpsError('aborted','Aruannet muudeti vahepeal. Laadi uus versioon ja proovi uuesti.');
      if ((log.summary || '')!==d.expectedSummary || (log.outcome || '')!==d.expectedOutcome) throw new HttpsError('aborted','Kokkuvõtet muudeti op-logis. Laadi uus versioon enne salvestamist.');
      if (d.status==='completed' && callout.status!=='closed') throw new HttpsError('failed-precondition','Lõpeta enne sündmus. Mustandit saad juba praegu täiendada.');
      const people=[...new Set([d.authorUserId,d.leaderUserId].filter(Boolean))];
      const peopleDocs=await tx.getAll(...people.map(uid=>db.doc(`memberships/${uid}_${actor.org}`)));
      if (peopleDocs.some((m,i)=>orgId(m.data())!==actor.org || m.data()?.userId!==people[i] || !active(m.data()))) fail('Koostaja ja juht peavad olema ühingu aktiivsed liikmed.');
      if (d.equipmentIds.length) {
        const gear=await tx.getAll(...d.equipmentIds.map(e=>db.doc(`equipment/${e}`)));
        if (gear.some(e=>orgId(e.data())!==actor.org || e.data()?.scope==='personal')) fail('Vali selle ühingu tehnika.');
      }
      const next={organizationId:actor.org,calloutId:d.calloutId,operationLogId:d.operationLogId,authorUserId:d.authorUserId,leaderUserId:d.leaderUserId,
        equipmentIds:d.equipmentIds,equipmentRegistration:d.equipmentRegistration || {},suggestions:d.suggestions.trim(),status:d.status,revision:d.revision+1,updatedBy:request.auth.uid,updatedAt:timestamp()};
      tx.set(reportRef,next);
      tx.create(db.doc(`callouts/${d.calloutId}/reportHistory/${changeId}`), {organizationId:actor.org,createdBy:request.auth.uid,createdAt:timestamp(),before:old || null,after:next});
      if ((log.summary || '')!==d.summary.trim() || (log.outcome || '')!==d.outcome.trim()) {
        tx.update(logRef,{summary:d.summary.trim(),outcome:d.outcome.trim(),updatedBy:request.auth.uid,updatedAt:timestamp()});
        tx.create(db.doc(`operationLogs/${d.operationLogId}/events/${changeId}`),{id:changeId,operationLogId:d.operationLogId,organizationId:actor.org,commandId:actor.org,
          type:'summarySaved',status:log.status,title:'Sündmuse kokkuvõte salvestatud',description:d.outcome.trim(),summarySnapshot:d.summary.trim(),
          createdBy:request.auth.uid,createdByName:actor.membership.displayName || '',createdAt:timestamp()});
      }
      if (JSON.stringify(p.data()?.persons || [])!==JSON.stringify(d.persons)) {
        tx.set(privateRef,{organizationId:actor.org,calloutId:d.calloutId,persons:d.persons,updatedBy:request.auth.uid,updatedAt:timestamp()});
        tx.create(db.doc(`calloutPrivate/${d.calloutId}/history/${changeId}`),{organizationId:actor.org,createdBy:request.auth.uid,createdAt:timestamp(),before:p.data()?.persons || [],after:d.persons});
      }
      const changedFields=Object.keys(next).filter(k=>!['updatedAt','updatedBy','revision'].includes(k) && JSON.stringify(old?.[k])!==JSON.stringify(next[k]));
      if ((log.summary || '')!==d.summary.trim()) changedFields.push('summary');
      if ((log.outcome || '')!==d.outcome.trim()) changedFields.push('outcome');
      if (JSON.stringify(p.data()?.persons || [])!==JSON.stringify(d.persons)) changedFields.push('privatePersons');
      tx.create(db.doc(`platformAudit/${changeId}`),{organizationId:actor.org,action:'report.updated',targetId:d.calloutId,changedFields,createdBy:request.auth.uid,createdAt:timestamp()});
      return {revision:next.revision};
    });
  };
}
function createAmendCalloutHandler({db,timestamp}) {
  return async request => {
    const d=request.data || {};
    if (!id(d.calloutId) || !text(d.title,200) || !d.title.trim() || !text(d.description) || !text(d.location,500)) fail('Kontrolli sündmuse pealkirja, kirjeldust ja asukohta.');
    const auditId=randomUUID();
    return db.runTransaction(async tx=>{
      const actor=await access({doc:path=>({get:()=>tx.get(db.doc(path))})},request,{crewOnly:true});
      const ref=db.doc(`callouts/${d.calloutId}`), old=(await tx.get(ref)).data();
      if (orgId(old)!==actor.org) throw new HttpsError('permission-denied','Sündmus kuulub teisele ühingule.');
      if (Math.trunc(millis(old.updatedAt) || 0)!==d.version) throw new HttpsError('aborted','Sündmust muudeti vahepeal. Ava see uuesti.');
      const before={title:old.title,description:old.description,location:old.location},after={title:d.title.trim(),description:d.description.trim(),location:d.location.trim()};
      tx.update(ref,{...after,updatedAt:timestamp(),updatedBy:request.auth.uid});
      tx.create(db.doc(`callouts/${d.calloutId}/changeHistory/${auditId}`),{organizationId:actor.org,before,after,createdBy:request.auth.uid,createdAt:timestamp()});
      tx.create(db.doc(`platformAudit/${auditId}`),{organizationId:actor.org,action:'callout.amended',targetId:d.calloutId,changedFields:Object.keys(after).filter(k=>before[k]!==after[k]),createdBy:request.auth.uid,createdAt:timestamp()});
      return {saved:true};
    });
  };
}
module.exports={createGetReportHandler,createSaveReportHandler,createAmendCalloutHandler,validateReport,serial};
