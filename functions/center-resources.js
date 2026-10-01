const {randomUUID, createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access, organizationDocs} = require('./statistics-handlers');
const {active} = require('./contribution-statistics');
const {orgId} = require('./statistics-history');
const {key} = require('./response-units');

const validId = v => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
function allocationActive(a, at) {
  return !!a && ((a.validityMode === 'untilChanged' && a.validUntil === null) ||
    Number.isFinite(a.validUntil?.toMillis?.()) && a.validUntil.toMillis() > at);
}
function registrationIdentity(country, registration) {
  if (typeof country !== 'string' || !/^[A-Z]{2}$/.test(country) || typeof registration !== 'string') {
    throw new HttpsError('invalid-argument', 'Sisesta registririigi kahetäheline kood ja aluse registrinumber.');
  }
  const number = registration.toUpperCase().replace(/[\s-]/g, '');
  if (!/^[A-Z0-9]{2,30}$/.test(number)) throw new HttpsError('invalid-argument', 'Kontrolli aluse registrinumbrit.');
  return {country, registration: number, physicalResourceId: createHash('sha256').update(`${country}:${number}`).digest('hex')};
}
function createCenterResourceHandlers({db, timestamp, now = Date.now}) {
  const source = tx => ({doc: p => ({get: () => tx.get(db.doc(p))}),
    collection: c => ({where: (...a) => ({get: () => tx.get(db.collection(c).where(...a))})})});
  function audit(tx, request, org, action, targetId, before, after) {
    tx.create(db.doc(`platformAudit/${randomUUID()}`), {organizationId: org, action, targetId,
      before: before ?? null, after, createdBy: request.auth.uid, createdAt: timestamp()});
  }
  async function ownResource(tx, org, kind, resourceId) {
    if (kind === 'member') {
      const m = (await tx.get(db.doc(`memberships/${resourceId}_${org}`))).data();
      if (!active(m) || orgId(m) !== org || m.userId !== resourceId) throw new HttpsError('permission-denied', 'Liige ei kuulu selle ühingu aktiivsesse koosseisu.');
      return {key: key('member', resourceId)};
    }
    const e = (await tx.get(db.doc(`equipment/${resourceId}`))).data();
    if (orgId(e) !== org || e?.category !== 'vessel' || e.scope === 'personal' || e.ownerUserId || e.assignedToUserId) {
      throw new HttpsError('permission-denied', 'Alus ei kuulu ühingu ühiskasutuses varustusse.');
    }
    const identity = (await tx.get(db.doc(`vesselIdentities/${resourceId}`))).data();
    if(identity && identity.organizationId !== org) throw new HttpsError('permission-denied', 'Aluse identiteet ei kuulu sellele ühingule.');
    return {identity, key: identity?.verified === true && identity.organizationId === org && validId(identity.physicalResourceId)
      ? key('vessel', identity.physicalResourceId) : null};
  }
  return {
    getOrganizationCenterResources: request => db.runTransaction(async tx => {
      const actor = await access(source(tx), request, {adminOnly: true});
      const vessels = await organizationDocs(source(tx), 'equipment', actor.org);
      const candidates = [
        ...vessels.filter(d => d.data().category === 'vessel' && d.data().scope !== 'personal' && !d.data().ownerUserId && !d.data().assignedToUserId).map(d => ({kind: 'vessel', resourceId: d.id, name: d.data().name || 'Alus'})),
      ];
      if (candidates.length > 150) throw new HttpsError('resource-exhausted', 'Ressursside loendi piir on 150 kirjet.');
      const entries = [];
      for (const row of candidates) {
        const r = await ownResource(tx, actor.org, row.kind, row.resourceId);
        const a = r.key ? (await tx.get(db.doc(`resourceAllocations/${r.key}`))).data() : null;
        entries.push({...row, identityVerified: row.kind === 'member' || !!r.key,
          country: r.identity?.country ?? '', registration: r.identity?.registration ?? '',
          identityRevision: r.identity?.revision ?? 0, allocationRevision: a?.revision ?? 0,
          allocation: allocationActive(a, now()) ? (a.organizationId === actor.org ? 'own' : 'other') : 'free',
          // No foreign org name, membership or contact is returned.
        });
      }
      // Keep former/deleted resources releasable without restoring membership or equipment.
      const prior = await tx.get(db.collection('resourceAllocations').where('organizationId','==',actor.org).limit(201));
      if(prior.size>200) throw new HttpsError('resource-exhausted','Jaotuste loendi piir on 200 kirjet.');
      for(const document of prior.docs) {
        const a=document.data();
        if(!allocationActive(a,now()) || a.kind!=='vessel' || !validId(a.resourceId) ||
          entries.some(e=>e.kind===a.kind && e.resourceId===a.resourceId)) continue;
        entries.push({kind:a.kind,resourceId:a.resourceId,name:a.kind==='member'?'Endise liikme jaotus':'Eemaldatud aluse jaotus',
          identityVerified:true,country:'',registration:'',identityRevision:0,allocationRevision:a.revision??0,allocation:'own',releaseOnly:true});
      }
      return {entries};
    }),
    saveCenterVesselIdentity: async request => {
      const d = request.data;
      if (!d || Object.keys(d).some(k => !['organizationId','resourceId','country','registration','expectedRevision'].includes(k)) ||
          !validId(d.resourceId) || !Number.isSafeInteger(d.expectedRevision) || d.expectedRevision < 0) throw new HttpsError('invalid-argument', 'Kontrolli aluse andmeid.');
      const value = registrationIdentity(d.country, d.registration);
      return db.runTransaction(async tx => {
        const actor = await access(source(tx), request, {adminOnly: true});
        const r = await ownResource(tx, actor.org, 'vessel', d.resourceId);
        if ((r.identity?.revision ?? 0) !== d.expectedRevision) throw new HttpsError('aborted', 'Aluse andmed muutusid. Laadi uuesti.');
        const allocation = r.key ? (await tx.get(db.doc(`resourceAllocations/${r.key}`))).data() : null;
        if (allocationActive(allocation, now()) && r.identity.physicalResourceId !== value.physicalResourceId) {
          throw new HttpsError('failed-precondition', 'Vabasta aluse senine valmiduse jaotus enne registriandmete muutmist.');
        }
        const after = {...value, organizationId: actor.org, verified: true, verificationSource: 'organizationAdmin',
          revision: d.expectedRevision + 1, updatedBy: request.auth.uid, updatedAt: timestamp()};
        tx.set(db.doc(`vesselIdentities/${d.resourceId}`), after);
        audit(tx, request, actor.org, 'center.vesselIdentity', d.resourceId, r.identity, after);
        return {saved: true};
      });
    },
    setOrganizationCenterResource: async request => {
      const d = request.data;
      if (!d || Object.keys(d).some(k => !['organizationId','resourceId','kind','action','expectedRevision'].includes(k)) ||
          !validId(d.resourceId) || !['member','vessel'].includes(d.kind) || !['claim','release'].includes(d.action) ||
          !Number.isSafeInteger(d.expectedRevision) || d.expectedRevision < 0) throw new HttpsError('invalid-argument', 'Kontrolli ressursi valikut.');
      return db.runTransaction(async tx => {
        const actor = await access(source(tx), request, {adminOnly: true});
        if(d.kind==='member') throw new HttpsError('failed-precondition','Liikmeid arvestatakse nende ühingupõhise valvesoleku järgi. Eraldi liikmete jagamist ei kasutata.');
        let r;
        if(d.action==='release') {
          const prior=await tx.get(db.collection('resourceAllocations').where('resourceId','==',d.resourceId).limit(21));
          if(prior.size>20) throw new HttpsError('resource-exhausted','Ressursi jaotuste piir on ületatud.');
          const own=prior.docs.find(x=>x.data().organizationId===actor.org && x.data().kind===d.kind);
          if(!own) throw new HttpsError('permission-denied','Enda ühingu jaotust ei leitud.');
          r={key:own.id};
        } else r = await ownResource(tx, actor.org, d.kind, d.resourceId);
        if (!r.key) throw new HttpsError('failed-precondition', 'Kinnita kõigepealt aluse registriandmed.');
        const ref = db.doc(`resourceAllocations/${r.key}`), before = (await tx.get(ref)).data();
        if ((before?.revision ?? 0) !== d.expectedRevision) throw new HttpsError('aborted', 'Ressursi jaotus muutus. Laadi uuesti.');
        if (allocationActive(before, now()) && before.organizationId !== actor.org) throw new HttpsError('failed-precondition', 'Ressurss on teise ühingu valmiduses. Senise ühingu admin peab selle esmalt vabastama.');
        if (d.action === 'release' && before?.organizationId !== actor.org) throw new HttpsError('permission-denied', 'Vabastada saab ainult enda ühingu jaotust.');
        const after = {organizationId: actor.org, kind: d.kind, resourceId: d.resourceId,
          ...(r.identity ? {physicalResourceId: r.identity.physicalResourceId} : {}),
          identityVerified: true, validityMode: d.action === 'claim' ? 'untilChanged' : 'released',
          validUntil: null, revision: d.expectedRevision + 1, updatedBy: request.auth.uid, updatedAt: timestamp()};
        tx.set(ref, after);
        audit(tx, request, actor.org, 'center.resourceAllocation', r.key, before, after);
        return {saved: true};
      });
    },
  };
}
module.exports = {createCenterResourceHandlers, allocationActive, registrationIdentity};
