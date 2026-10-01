const {randomUUID}=require('node:crypto');
const {FieldPath}=require('firebase-admin/firestore');
const {HttpsError}=require('firebase-functions/v2/https');
const {CENTERS,allowed}=require('./center-access');
const {access}=require('./statistics-handlers');
const {platformAccess}=require('./organization-management');
const {loadOrganizationCenterReadiness,transactionalDb}=require('./organization-center-readiness');
const {createEvidenceReader}=require('./center-readiness-evidence');
const millis=v=>v?.toMillis?.() ?? null;
const validId=v=>typeof v==='string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
// Use the actual saved coordinates, including existing records saved before
// the old extra checkbox was removed. Never invent or geocode a missing point.
function mapPosition(base,org) {
  const p=base?.position;
  return base?.organizationId===org && base.active===true &&
    Number.isFinite(p?.latitude) && Math.abs(p.latitude)<=90 &&
    Number.isFinite(p?.longitude) && Math.abs(p.longitude)<=180 ? p : null;
}
function createCenterBoardHandlers({db,timestamp,now=Date.now}) {
  const txDb=tx=>transactionalDb(db,tx);
  async function centerAccess(tx,request) {
    if(!request.auth?.uid) throw new HttpsError('unauthenticated','Logi sisse.');
    const id=request.data?.centerId;
    if(!Object.hasOwn(CENTERS,id)) throw new HttpsError('invalid-argument','Tundmatu keskus.');
    const c=(await tx.get(db.doc(`centers/${id}`))).data();
    const grant=(await tx.get(db.doc(`centerAccess/${request.auth.uid}/grants/${id}`))).data();
    if(!allowed(grant,c,CENTERS[id].service,now())) throw new HttpsError('permission-denied','Keskuse ligipääsuõigus puudub või on aegunud.');
    return {id,service:CENTERS[id].service,grant};
  }
  async function publicationPage(tx,request,query) {
    const pageSize=request.data?.pageSize ?? 100,cursor=request.data?.cursor ?? null;
    if(!Number.isInteger(pageSize) || pageSize<1 || pageSize>100 ||
      (cursor!==null && (typeof cursor!=='string' || !/^[A-Za-z0-9_-]{1,256}$/.test(cursor)))) {
      throw new HttpsError('invalid-argument','Vigane lehekülje päring.');
    }
    query=query.orderBy(FieldPath.documentId());
    if(cursor) query=query.startAfter(cursor);
    const rows=await tx.get(query.limit(pageSize+1)),more=rows.size>pageSize;
    // Legacy clients must fail visibly instead of displaying an incomplete list.
    if(more && request.data?.pageSize===undefined) throw new HttpsError('resource-exhausted','Uuenda rakendust kogu loendi laadimiseks.');
    const page=rows.docs.slice(0,pageSize);
    return {page,nextCursor:more?page.at(-1).id:null};
  }
  function changeData(d) {
    if(!d || !validId(d.organizationId) || !Object.hasOwn(CENTERS,d.centerId) || typeof d.enabled!=='boolean' ||
      !Number.isSafeInteger(d.expectedRevision) || d.expectedRevision<0 ||
      Object.keys(d).some(k=>!['organizationId','centerId','enabled','expectedRevision'].includes(k))) {
      throw new HttpsError('invalid-argument','Kontrolli keskusega jagamise andmeid.');
    }
  }
  async function publicationChange(request,platform) {
    const d=request.data;changeData(d);
    return db.runTransaction(async tx=>{
      if(platform) await platformAccess(txDb(tx),request); else await access(txDb(tx),request,{adminOnly:true});
      const ref=db.doc(`organizationCenterPublication/${d.organizationId}_${d.centerId}`),before=(await tx.get(ref)).data();
      if((before?.revision ?? 0)!==d.expectedRevision) throw new HttpsError('aborted','Jagamise seade muutus. Laadi uuesti.');
      if(platform && (!before?.requested || before.organizationId!==d.organizationId || before.centerId!==d.centerId)) {
        throw new HttpsError('failed-precondition','Ühingu jagamistaotlus puudub.');
      }
      const after={organizationId:d.organizationId,centerId:d.centerId,
        requested:platform?before.requested:d.enabled,approved:platform?d.enabled:false,
        revision:d.expectedRevision+1,updatedAt:timestamp(),updatedBy:request.auth.uid};
      tx.set(ref,after);
      tx.create(db.doc(`platformAudit/${randomUUID()}`),{action:platform?'centerPublication.reviewed':'centerPublication.requested',
        organizationId:d.organizationId,centerId:d.centerId,before:before || null,after,createdBy:request.auth.uid,createdAt:timestamp()});
      return {saved:true,revision:after.revision};
    });
  }
  return {
    setOrganizationCenterSharing:r=>publicationChange(r,false),
    reviewOrganizationCenterSharing:r=>publicationChange(r,true),
    getOrganizationCenterSharing:request=>db.runTransaction(async tx=>{
      const actor=await access(txDb(tx),request,{adminOnly:true});
      const org=(await tx.get(db.doc(`commands/${actor.org}`))).data();
      const base=validId(org?.primaryRescueBaseId)?(await tx.get(db.doc(`rescueBases/${org.primaryRescueBaseId}`))).data():null;
      const positionReady=mapPosition(base,actor.org)!==null;
      const entries=[];
      for(const [centerId,center] of Object.entries(CENTERS)) {
        const d=(await tx.get(db.doc(`organizationCenterPublication/${actor.org}_${centerId}`))).data();
        entries.push({centerId,name:center.name,requested:d?.requested===true,approved:d?.approved===true,revision:d?.revision ?? 0});
      }
      return {entries,positionReady};
    }),
    getCenterSharingRequests:request=>db.runTransaction(async tx=>{
      await platformAccess(txDb(tx),request);
      const {page,nextCursor}=await publicationPage(tx,request,db.collection('organizationCenterPublication').where('requested','==',true));
      const entries=[];
      for(const doc of page) {
        const d=doc.data(),org=(await tx.get(db.doc(`commands/${d.organizationId}`))).data();
        entries.push({organizationId:d.organizationId,name:org?.name || 'Ühing',centerId:d.centerId,
          approved:d.approved===true,revision:d.revision});
      }
      return {entries,nextCursor};
    }),
    getCenterReadinessBoard:request=>db.runTransaction(async tx=>{
      const center=await centerAccess(tx,request),at=now();
      const source=txDb(tx),evidenceReader=createEvidenceReader(source);
      const {page,nextCursor}=await publicationPage(tx,request,db.collection('organizationCenterPublication')
        .where('centerId','==',center.id).where('requested','==',true).where('approved','==',true));
      const items=[];
      for(const row of page) {
        const p=row.data(),org=p.organizationId;
        if(!p.requested || !p.approved || !validId(org)) continue;
        const organization=(await tx.get(db.doc(`commands/${org}`))).data();
        if(organization?.status!=='approved') continue;
        const settings=(await tx.get(db.doc(`organizationResponseSettings/${org}`))).data();
        const policy=settings?.services?.[center.service];
        if(policy?.enabled!==true) continue;
        const baseId=organization.primaryRescueBaseId;
        const base=validId(baseId)?(await tx.get(db.doc(`rescueBases/${baseId}`))).data():null;
        const position=mapPosition(base,org);
        const summary=await loadOrganizationCenterReadiness({db:source,org,service:center.service,now:at,settings,evidenceReader});
        items.push({id:org,name:organization.name || 'Ühing',latitude:position?.latitude ?? null,longitude:position?.longitude ?? null,
          contactName:settings.contactName || '',contactPhone:settings.contactPhone || '',...summary});
      }
      // Check expiry after the potentially long read, too.
      await centerAccess(tx,request);
      return {items,serverNowMs:now(),accessValidUntilMs:millis(center.grant.validUntil),nextCursor};
    }),
  };
}
module.exports={createCenterBoardHandlers,mapPosition};
