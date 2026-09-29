const {createHash}=require('node:crypto');
const {HttpsError}=require('firebase-functions/v2/https');
const {access}=require('./statistics-handlers');
const {orgId}=require('./statistics-history');
const MAX_BYTES=8*1024*1024;
const types={pdf:'application/pdf',jpg:'image/jpeg',jpeg:'image/jpeg',png:'image/png',heic:'image/heic',mp4:'video/mp4',mov:'video/quicktime',txt:'text/plain',docx:'application/vnd.openxmlformats-officedocument.wordprocessingml.document'};
const validId=v=>typeof v==='string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
async function authorize(db,request) {
 const actor=await access(db,request,{crewOnly:true});
 if(!validId(request.data?.calloutId))throw new HttpsError('invalid-argument','Sündmuse tunnus puudub.');
 const event=(await db.doc(`callouts/${request.data.calloutId}`).get()).data();
 if(orgId(event)!==actor.org)throw new HttpsError('permission-denied','Sündmus ei kuulu ühingule.');
 return actor;
}
function createAttachmentHandlers({db,bucket,timestamp}) {
 return {
  upload:async request=>{
   const actor=await authorize(db,request),d=request.data;
   if(!validId(d.requestId) || typeof d.name!=='string' || !d.name.trim() || d.name.length>160 || /[\\/\x00-\x1f]/.test(d.name) ||
      typeof d.base64!=='string' || d.base64.length>Math.ceil(MAX_BYTES/3)*4 || d.base64.length%4!==0)throw new HttpsError('invalid-argument','Kontrolli faili nime ja suurust (kuni 8 MB).');
   const contentType=types[d.name.split('.').pop().toLowerCase()];
   const bytes=Buffer.from(d.base64,'base64');
   if(!contentType || !bytes.length || bytes.length>MAX_BYTES || bytes.toString('base64')!==d.base64)throw new HttpsError('invalid-argument','Lubatud on foto, PDF, DOCX, tekst ja lühivideo, kuni 8 MB.');
   const attachmentId=createHash('sha256').update(`${request.auth.uid}:${d.calloutId}:${d.requestId}`).digest('hex');
   const ref=db.doc(`calloutAttachments/${attachmentId}`),hash=createHash('sha256').update(bytes).digest('hex');
   const storagePath=`calloutAttachments/${actor.org}/${d.calloutId}/${attachmentId}`;
   // Reserve a bounded, idempotent record first. An interrupted upload can resume
   // with the same request ID and content, without overwriting any other file.
   await db.runTransaction(async tx=>{
    await authorize({doc:p=>({get:()=>tx.get(db.doc(p))})},request);
    const old=(await tx.get(ref)).data();
    if(old){if(old.sha256!==hash || old.name!==d.name || old.createdBy!==request.auth.uid)throw new HttpsError('already-exists','Faili tunnus on juba kasutusel.');return;}
    const all=await tx.get(db.collection('calloutAttachments').where('calloutId','==',d.calloutId));
    if(all.size>=30)throw new HttpsError('resource-exhausted','Sündmusele saab lisada kuni 30 manust.');
    // Serialize the per-event capacity check, including an initially empty list.
    tx.update(db.doc(`callouts/${d.calloutId}`),{attachmentRevision:attachmentId});
    tx.create(ref,{organizationId:actor.org,calloutId:d.calloutId,name:d.name,contentType,size:bytes.length,storagePath,sha256:hash,status:'uploading',createdBy:request.auth.uid,createdAt:timestamp()});
   });
   const file=bucket.file(storagePath);
   try {await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType,cacheControl:'private, no-store',metadata:{sha256:hash}}});}
   catch(error){if(Number(error.code)!==412)throw error;const [metadata]=await file.getMetadata();if(metadata.metadata?.sha256!==hash)throw new HttpsError('failed-precondition','Faili sisu ei vasta manusele.');}
   await db.runTransaction(async tx=>{
    await authorize({doc:p=>({get:()=>tx.get(db.doc(p))})},request);
    const old=(await tx.get(ref)).data();
    if(old.status==='ready')return;
    tx.update(ref,{status:'ready',updatedAt:timestamp()});
    tx.create(db.doc(`platformAudit/attachment_${attachmentId}`),{organizationId:actor.org,action:'callout.attachmentAdded',targetId:d.calloutId,attachmentId,createdBy:request.auth.uid,createdAt:timestamp()});
   });
   return {attachmentId};
  },
  download:async request=>{
   const actor=await authorize(db,request),d=request.data;
   if(!validId(d.attachmentId))throw new HttpsError('invalid-argument','Manus puudub.');
   const item=(await db.doc(`calloutAttachments/${d.attachmentId}`).get()).data();
   const expected=`calloutAttachments/${actor.org}/${d.calloutId}/${d.attachmentId}`;
   if(item?.organizationId!==actor.org || item?.calloutId!==d.calloutId || item.status!=='ready' || item.storagePath!==expected || item.size>MAX_BYTES)throw new HttpsError('not-found','Manust ei leitud.');
   const [bytes]=await bucket.file(expected).download();
   if(bytes.length>MAX_BYTES || createHash('sha256').update(bytes).digest('hex')!==item.sha256)throw new HttpsError('data-loss','Manuse tervikluse kontroll ebaõnnestus.');
   return {name:item.name,contentType:item.contentType,base64:bytes.toString('base64')};
  },
 };
}
module.exports={createAttachmentHandlers,MAX_BYTES,types,authorize};
