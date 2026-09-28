const {HttpsError} = require('firebase-functions/v2/https');
const {DateTime} = require('luxon');
const {SOURCES,orgId,millis,project} = require('./statistics-history');
const {aggregate,period,TYPES,ZONE,active} = require('./contribution-statistics');
const validId = v => typeof v==='string' && v.length>0 && v.length<=128 && !v.includes('/');
async function access(db, request, {adminOnly=false, statistics=false}={}) {
  if(!request.auth?.uid) throw new HttpsError('unauthenticated','Logi sisse.');
  const org=request.data?.organizationId;
  if(!validId(org)) throw new HttpsError('invalid-argument','Ühing puudub.');
  const [organization,membership]=await Promise.all([db.doc(`commands/${org}`).get(),db.doc(`memberships/${request.auth.uid}_${org}`).get()]);
  const m=membership.data(),o=organization.data();
  const admin=['orgAdmin','admin'].includes(m?.role);
  if(o?.status!=='approved' || orgId(m)!==org || m?.userId!==request.auth.uid || !active(m) || (adminOnly&&!admin) || (statistics&&!admin&&o.allowMembersToViewStatistics!==true)) {
    throw new HttpsError('permission-denied','Sul puudub selle toimingu õigus.');
  }
  return {org,admin,organization:o,membership:m};
}
async function organizationDocs(db,collection,org,legacy=true) {
  const snapshots=await Promise.all((legacy?['organizationId','commandId']:['organizationId']).map(field=>db.collection(collection).where(field,'==',org).get()));
  const docs=new Map();for(const snapshot of snapshots)for(const doc of snapshot.docs)if(orgId(doc.data())===org)docs.set(doc.id,doc);
  return [...docs.values()];
}
function createStatisticsHandler({db,now=()=>Date.now()}) {
  return async request => {
    const {org,admin,organization}=await access(db,request,{statistics:true});
    const {from,to}=request.data||{};
    if(!period(from,to)) throw new HttpsError('invalid-argument','Vali kuni 366 päeva pikkune periood.');
    const at=now();
    const names=[...SOURCES,'activities','activityParticipants','callouts','calloutResponses','calloutAttendance','statisticsHistory'];
    const [settings,...snapshots]=await Promise.all([db.doc('statisticsSettings/tracking').get(),...names.map(name=>organizationDocs(db,name,org,!['calloutAttendance','statisticsHistory'].includes(name)))]);
    const data=Object.fromEntries(names.map((name,i)=>[name,snapshots[i].map(d=>({...d.data(),id:d.id}))]));
    const current=SOURCES.flatMap((source,i)=>snapshots[i].map(d=>({source,id:d.id,data:project(source,d.data()),version:millis(d.updateTime)})));
    const result=aggregate({organizationId:org,from,to,now:at,trackingStart:millis(settings.data()?.startedAt),current,history:data.statisticsHistory,
      memberships:data.memberships,activities:data.activities,participants:data.activityParticipants,callouts:data.callouts,responses:data.calloutResponses,attendance:data.calloutAttendance});
    return {...result,canManage:admin,canRecord:admin || organization.allowMembersToCreateActivities===true};
  };
}
function createRecordContributionHandler({db,timestamp,now=()=>Date.now()}) {
  return async request => {
    const {org,admin,organization}=await access(db,request);
    if(!admin && organization.allowMembersToCreateActivities!==true) throw new HttpsError('permission-denied','Panuse lisamise õigus puudub.');
    const {requestId,title,type,date,hours,memberIds}=request.data||{};
    const day=DateTime.fromISO(typeof date==='string'?date:'',{zone:ZONE});
    if(!validId(requestId) || typeof title!=='string' || !title.trim() || title.length>200 || !Object.hasOwn(TYPES,type) || !/^\d{4}-\d{2}-\d{2}$/.test(date||'') || !day.isValid || +day>now() || typeof hours!=='number' || !Number.isFinite(hours) || hours<=0 || hours>24 || !Array.isArray(memberIds) || !memberIds.length || memberIds.length>50 || memberIds.some(id=>!validId(id))) throw new HttpsError('invalid-argument','Kontrolli panuse nimetust, kuupäeva, osalejaid ja tunde (kuni 24 t).');
    const users=[...new Set(memberIds)];
    if(!admin && (users.length!==1 || users[0]!==request.auth.uid)) throw new HttpsError('permission-denied','Saad esitada ainult enda panust.');
    const id=`contribution_${requestId}`;
    return db.runTransaction(async tx=>{
      const fresh=await access({doc:path=>({get:()=>tx.get(db.doc(path))})},request);
      if(fresh.admin!==admin || (!fresh.admin && fresh.organization.allowMembersToCreateActivities!==true)) throw new HttpsError('permission-denied','Panuse lisamise õigus muutus.');
      const ref=db.doc(`activities/${id}`),existing=await tx.get(ref);
      if(existing.exists) {
        if(orgId(existing.data())!==org || existing.data().createdBy!==request.auth.uid) throw new HttpsError('already-exists','Panuse tunnus on kasutusel.');
        return {activityId:id};
      }
      const members=await tx.getAll(...users.map(uid=>db.doc(`memberships/${uid}_${org}`)));
      if(members.some((m,i)=>!active(m.data()) || orgId(m.data())!==org || m.data()?.userId!==users[i])) throw new HttpsError('failed-precondition','Osaleja ei ole selle ühingu aktiivne liige.');
      tx.create(ref,{id,organizationId:org,commandId:org,title:title.trim(),description:admin?'':'Liikme esitatud panus; osalemine ootab admini kinnitust.',type,
        startTime:day.toISO(),endTime:'',location:'',createdBy:request.auth.uid,createdAt:timestamp(),updatedAt:timestamp()});
      for(const uid of users) {
        const participantId=`${id}_${uid}`;
        tx.create(db.doc(`activityParticipants/${participantId}`),{id:participantId,activityId:id,userId:uid,organizationId:org,commandId:org,
          status:'attendedSelfReported',attendanceStatus:admin?'confirmed':'notConfirmed',hours,
          ...(admin?{confirmedBy:request.auth.uid,confirmedAt:timestamp()}:{}),createdAt:timestamp(),updatedAt:timestamp()});
      }
      return {activityId:id};
    });
  };
}
function createCalloutAttendanceHandler({db,timestamp}) {
  return async request => {
    const {org}=await access(db,request,{adminOnly:true});
    const {calloutId,userId,status,hours}=request.data||{};
    if(!validId(calloutId)||!validId(userId)||!['confirmed','absent'].includes(status)|| (hours!==null&&hours!==undefined&&(typeof hours!=='number'||!Number.isFinite(hours)||hours<0||hours>744))) throw new HttpsError('invalid-argument','Kontrolli osalemise andmeid.');
    return db.runTransaction(async tx=>{
      await access({doc:path=>({get:()=>tx.get(db.doc(path))})},request,{adminOnly:true});
      const [callout,member]=await tx.getAll(db.doc(`callouts/${calloutId}`),db.doc(`memberships/${userId}_${org}`));
      if(orgId(callout.data())!==org || callout.data()?.status==='cancelled' || orgId(member.data())!==org || member.data()?.userId!==userId || (!active(member.data()) && !['removed','inactive'].includes(member.data()?.status))) throw new HttpsError('failed-precondition','Väljakutset või selle ühingu liiget ei leitud.');
      const id=`${calloutId}_${userId}`;
      tx.set(db.doc(`calloutAttendance/${id}`),{id,organizationId:org,calloutId,userId,userName:member.data().displayName||'Liige',status,hours:status==='confirmed'?(hours??null):null,confirmedBy:request.auth.uid,updatedAt:timestamp()});
      return {saved:true};
    });
  };
}
module.exports={access,organizationDocs,createStatisticsHandler,createRecordContributionHandler,createCalloutAttendanceHandler};
