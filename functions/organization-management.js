const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access,organizationDocs} = require('./statistics-handlers');
const {active} = require('./contribution-statistics');
const {orgId} = require('./statistics-history');
const {serial} = require('./callout-report');
const validId=v=>typeof v==='string' && v.length>0 && v.length<=128 && !v.includes('/');
const isAdmin=m=>active(m) && ['orgAdmin','admin'].includes(m.role);
const lastAdminMessage='Sa oled organisatsiooni ainus administraator. Enne enda administraatorirolli eemaldamist määra vähemalt üks teine aktiivne liige administraatoriks.';
function requireOtherAdmin(members,targetId,next) {
  const target=members.find(m=>m.id===targetId);
  if (target && isAdmin(target.data) && !isAdmin({...target.data,...next}) && !members.some(m=>m.id!==targetId && isAdmin(m.data))) {
    throw new HttpsError('failed-precondition',lastAdminMessage);
  }
}
async function platformAccess(db,request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated','Logi sisse.');
  const user=(await db.doc(`users/${request.auth.uid}`).get()).data();
  if (!['platformAdmin','platformOwner'].includes(user?.systemRole)) throw new HttpsError('permission-denied','Platvormihalduse õigus puudub.');
}
function createMembershipManagementHandler({db,timestamp}) {
  return async request=> {
    const d=request.data || {}, auditId=randomUUID();
    if (!validId(d.userId) || !['role','remove','approve','reject'].includes(d.action) || (d.action==='role' && !['orgAdmin','member'].includes(d.role))) throw new HttpsError('invalid-argument','Kontrolli liikmelisuse muudatust.');
    return db.runTransaction(async tx=>{
      const actor=await access({doc:path=>({get:()=>tx.get(db.doc(path))})},request);
      if (!actor.admin && !(d.action==='remove' && d.userId===request.auth.uid)) throw new HttpsError('permission-denied','Liikmeid haldab ühingu admin.');
      // Every security-changing membership operation writes the organization lock.
      // Parallel demotions/removals therefore retry against the committed roster.
      const orgRef=db.doc(`commands/${actor.org}`), ref=db.doc(`memberships/${d.userId}_${actor.org}`);
      const members=(await tx.get(db.collection('memberships').where('organizationId','==',actor.org))).docs;
      const legacy=(await tx.get(db.collection('memberships').where('commandId','==',actor.org))).docs;
      const roster=[...new Map([...members,...legacy].map(m=>[m.id,m])).values()]
        .filter(m=>orgId(m.data())===actor.org && m.id===`${m.data().userId}_${actor.org}`).map(m=>({id:m.id,data:m.data()}));
      const before=roster.find(m=>m.id===ref.id)?.data;
      if (!before) throw new HttpsError('not-found','Liiget ei leitud.');
      if (['approve','reject'].includes(d.action) && (before.status!=='pending' || before.role!=='member')) throw new HttpsError('failed-precondition','Liitumistaotlus ei ole ootel.');
      if (d.action==='role' && !active(before)) throw new HttpsError('failed-precondition','Adminiks saab määrata aktiivse liikme.');
      const next=d.action==='role'?{role:d.role}:d.action==='approve'?{status:'active',isActive:true}:d.action==='reject'?{status:'rejected',isActive:false}:{status:'removed',isActive:false};
      requireOtherAdmin(roster,ref.id,next);
      tx.update(ref,{...next,updatedAt:timestamp(),updatedBy:request.auth.uid});
      tx.update(orgRef,{membershipRevision:(actor.organization.membershipRevision || 0)+1});
      tx.create(db.doc(`platformAudit/${auditId}`),{organizationId:actor.org,action:`membership.${d.action}`,targetId:d.userId,
        before:{role:before.role,status:before.status || 'active',isActive:active(before)},after:{role:next.role || before.role,status:next.status || before.status || 'active',isActive:next.isActive ?? active(before)},createdBy:request.auth.uid,createdAt:timestamp()});
      return {saved:true};
    });
  };
}
function createDutyHandler({db,timestamp}) {
  return async request=> {
    const d=request.data || {}, pauseId=randomUUID();
    if (typeof d.paused!=='boolean' || typeof d.reason!=='string' || d.reason.length>1000 || (d.paused&&!d.reason.trim())) throw new HttpsError('invalid-argument','Lisa valve peatamise põhjus.');
    return db.runTransaction(async tx=>{
      const actor=await access({doc:path=>({get:()=>tx.get(db.doc(path))})},request,{adminOnly:true});
      const old=actor.organization;
      if ((old.dutyPaused===true)===d.paused && (!d.paused || old.dutyPauseReason===d.reason.trim())) return {saved:true};
      const summaryRef=db.doc(`organizationReadinessSummaries/${actor.org}`);
      const summary=await tx.get(summaryRef);
      const now=timestamp();
      if (d.paused && !old.dutyPaused) tx.create(db.doc(`organizationDutyPauses/${pauseId}`),{organizationId:actor.org,startAt:now,endAt:null,reason:d.reason.trim(),createdBy:request.auth.uid});
      if (!d.paused && old.dutyPaused) {
        if (!validId(old.dutyPauseId)) throw new HttpsError('failed-precondition','Valvepausi ajalugu vajab kontrolli.');
        tx.update(db.doc(`organizationDutyPauses/${old.dutyPauseId}`),{endAt:now,endedBy:request.auth.uid});
      }
      tx.update(db.doc(`commands/${actor.org}`),{dutyPaused:d.paused,dutyPauseReason:d.paused?d.reason.trim():'',
        dutyPauseId:d.paused?(old.dutyPaused?old.dutyPauseId:pauseId):null,dutyUpdatedAt:now,dutyUpdatedBy:request.auth.uid});
      if (summary.exists) tx.update(summaryRef,{dutyPaused:d.paused,readinessStatus:d.paused?'notReady':'unknown',updatedAt:now});
      tx.create(db.doc(`platformAudit/${pauseId}`),{organizationId:actor.org,action:d.paused?'duty.paused':'duty.resumed',targetId:actor.org,createdBy:request.auth.uid,createdAt:now});
      return {saved:true};
    });
  };
}
function createPlatformOverviewHandler({db}) {
  return async request=> {
    await platformAccess(db,request);
    const [commands,audit]=await Promise.all([db.collection('commands').get(),db.collection('platformAudit').orderBy('createdAt','desc').limit(100).get()]);
    const organizations=[];
    for (const doc of commands.docs) {
      const [members,callouts,profile]=await Promise.all([organizationDocs(db,'memberships',doc.id),organizationDocs(db,'callouts',doc.id),db.doc(`organizationProfiles/${doc.id}`).get()]);
      const roster=members.filter(m=>m.id===`${m.data().userId}_${doc.id}` && active(m.data()));
      const d=doc.data();
      const times=[d.createdAt,d.reviewedAt,...callouts.map(c=>c.data().updatedAt),...members.map(m=>m.data().updatedAt)].filter(v=>v?.toMillis);
      organizations.push({id:doc.id,name:d.name || '',status:d.status || 'approved',memberCount:roster.length,adminCount:roster.filter(m=>isAdmin(m.data())).length,calloutCount:callouts.length,
        createdAt:d.createdAt || null,reviewedAt:d.reviewedAt || null,lastActivity:times.sort((a,b)=>b.toMillis()-a.toMillis())[0] || null,
        profile:profile.data() || {},createdBy:d.createdBy});
    }
    return serial({organizations,audit:audit.docs.map(d=>({id:d.id,...d.data()}))});
  };
}
function createPlatformStatusHandler({db,timestamp}) {
  return async request=>{
    const d=request.data || {};
    if (!validId(d.organizationId) || !['suspended','approved'].includes(d.status)) throw new HttpsError('invalid-argument','Kontrolli organisatsiooni staatust.');
    const auditId=randomUUID();
    return db.runTransaction(async tx=>{
      await platformAccess({doc:path=>({get:()=>tx.get(db.doc(path))})},request);
      const ref=db.doc(`commands/${d.organizationId}`),before=(await tx.get(ref)).data();
      if (!before || !['approved','suspended'].includes(before.status)) throw new HttpsError('failed-precondition','Ootel taotlus tuleb esmalt kinnitada või tagasi lükata.');
      if (d.status==='approved') {
        const docs=(await tx.get(db.collection('memberships').where('commandId','==',d.organizationId))).docs;
        const modern=(await tx.get(db.collection('memberships').where('organizationId','==',d.organizationId))).docs;
        if (![...docs,...modern].some(m=>m.id===`${m.data().userId}_${d.organizationId}` && orgId(m.data())===d.organizationId && isAdmin(m.data()))) throw new HttpsError('failed-precondition','Ühingul peab olema vähemalt üks aktiivne admin.');
      }
      tx.update(ref,{status:d.status,updatedAt:timestamp(),updatedBy:request.auth.uid});
      tx.create(db.doc(`platformAudit/${auditId}`),{organizationId:d.organizationId,action:'organization.status',targetId:d.organizationId,before:{status:before.status},after:{status:d.status},createdBy:request.auth.uid,createdAt:timestamp()});
      return {saved:true};
    });
  };
}
function createPlatformAccountsHandler({db,auth}) {
  return async request=>{
    await platformAccess(db,request);
    const page=await auth.listUsers(100, typeof request.data?.pageToken==='string'?request.data.pageToken:undefined);
    return {users:page.users.map(u=>({uid:u.uid,name:u.displayName || '',email:u.email || '',emailVerified:u.emailVerified,disabled:u.disabled,lastSignInTime:u.metadata.lastSignInTime || ''})),pageToken:page.pageToken || null};
  };
}
function createRevokeSessionsHandler({db,auth,timestamp}) {
  return async request=>{
    await platformAccess(db,request);
    if (!validId(request.data?.userId)) throw new HttpsError('invalid-argument','Kasutaja puudub.');
    await auth.revokeRefreshTokens(request.data.userId);
    await db.doc(`platformAudit/${randomUUID()}`).create({action:'account.sessionsRevoked',targetId:request.data.userId,createdBy:request.auth.uid,createdAt:timestamp()});
    return {saved:true};
  };
}
module.exports={createMembershipManagementHandler,createDutyHandler,createPlatformOverviewHandler,createPlatformStatusHandler,createPlatformAccountsHandler,createRevokeSessionsHandler,platformAccess,requireOtherAdmin,lastAdminMessage};
