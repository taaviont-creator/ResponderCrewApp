const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {platformAccess} = require('./organization-management');

// V1 centers are contexts, never organizations or membership roles.
const CENTERS = Object.freeze({
  merevalvekeskus: {name: 'Merevalvekeskus', service: 'sar'},
  tross: {name: 'Trossi keskus', service: 'tross'},
});
const validId = value => typeof value === 'string' &&
  /^[A-Za-z0-9_-]{1,128}$/.test(value);
const millis = value => value?.toMillis?.() ?? null;

function allowed(grant, center, service, now) {
  return center?.active === true && center.services?.includes(service) &&
    grant?.active === true && Array.isArray(grant.services) &&
    grant.services.includes(service) &&
    (grant.validUntil === null ||
      (Number.isFinite(millis(grant.validUntil)) && millis(grant.validUntil) > now));
}

function createCenterAccessHandlers({db, timestamp, now = Date.now, fromMillis}) {
  const transactionDb = tx => ({doc: path => ({get: () => tx.get(db.doc(path))})});
  async function readAccess(tx, uid) {
    const result = [];
    for (const [id, definition] of Object.entries(CENTERS)) {
      const center = (await tx.get(db.doc(`centers/${id}`))).data();
      const grant = (await tx.get(db.doc(`centerAccess/${uid}/grants/${id}`))).data();
      result.push({id, definition, center, grant});
    }
    return result;
  }
  return {
    getCenterContexts: async request => {
      if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Logi sisse.');
      return db.runTransaction(async tx => {
        const entries = await readAccess(tx, request.auth.uid);
        const serverNowMs = now();
        return {serverNowMs, contexts: entries
          .filter(e => allowed(e.grant, e.center, e.definition.service, serverNowMs))
          .map(e => ({centerId: e.id, name: e.definition.name,
            service: e.definition.service, canDispatch: e.grant.canDispatch === true, validUntilMs: millis(e.grant.validUntil)}))};
      });
    },
    getPlatformCenterAccess: async request => {
      if (!validId(request.data?.userId)) throw new HttpsError('invalid-argument', 'Kasutaja puudub.');
      return db.runTransaction(async tx => {
        await platformAccess(transactionDb(tx), request);
        const entries = await readAccess(tx, request.data.userId);
        return {grants: entries.map(e => ({centerId: e.id, name: e.definition.name,
          active: e.grant?.active === true, canDispatch: e.grant?.canDispatch === true, validUntilMs: millis(e.grant?.validUntil),
          revision: e.grant?.revision ?? 0}))};
      });
    },
    setCenterAccess: async request => {
      const d = request.data || {};
      if (!validId(d.userId) || !Object.hasOwn(CENTERS, d.centerId) ||
          typeof d.active !== 'boolean' || !Number.isSafeInteger(d.expectedRevision) ||
          d.expectedRevision < 0 || (d.canDispatch !== undefined && typeof d.canDispatch !== 'boolean') ||
          Object.keys(d).some(k => !['userId','centerId','active','expectedRevision','validUntilMs','canDispatch'].includes(k)) ||
          (d.validUntilMs != null && (!Number.isSafeInteger(d.validUntilMs) ||
            d.validUntilMs <= now() || d.validUntilMs > 8640000000000000))) {
        throw new HttpsError('invalid-argument', 'Kontrolli keskuse õiguse andmeid.');
      }
      const auditId = randomUUID();
      return db.runTransaction(async tx => {
        await platformAccess(transactionDb(tx), request);
        const target = await tx.get(db.doc(`users/${d.userId}`));
        if (!target.exists) throw new HttpsError('not-found', 'Kasutajakontot ei leitud.');
        const centerRef = db.doc(`centers/${d.centerId}`);
        const center = await tx.get(centerRef);
        const ref = db.doc(`centerAccess/${d.userId}/grants/${d.centerId}`);
        const before = (await tx.get(ref)).data();
        if ((before?.revision ?? 0) !== d.expectedRevision) {
          throw new HttpsError('aborted', 'Õigust on vahepeal muudetud. Laadi andmed uuesti.');
        }
        const at = timestamp();
        const definition = CENTERS[d.centerId];
        if (!center.exists && d.active) tx.create(centerRef, {
          name: definition.name, services: [definition.service], active: true,
          createdAt: at, createdBy: request.auth.uid,
        });
        const after = {active: d.active, canDispatch: d.active && (d.canDispatch ?? before?.canDispatch ?? false), services: [definition.service],
          validUntil: d.active && d.validUntilMs != null ? fromMillis(d.validUntilMs) : null,
          revision: d.expectedRevision + 1, updatedAt: at, updatedBy: request.auth.uid,
          grantedAt: d.active ? at : before?.grantedAt ?? null,
          grantedBy: d.active ? request.auth.uid : before?.grantedBy ?? null,
          revokedAt: d.active ? null : at};
        tx.set(ref, after);
        tx.create(db.doc(`platformAudit/${auditId}`), {
          action: d.active ? 'centerAccess.granted' : 'centerAccess.revoked',
          targetId: d.userId, centerId: d.centerId,
          before: {active: before?.active === true, revision: before?.revision ?? 0},
          after: {active: after.active, canDispatch: after.canDispatch, services: after.services, validUntil: after.validUntil, revision: after.revision},
          createdAt: at, createdBy: request.auth.uid,
        });
        return {saved: true, revision: after.revision};
      });
    },
  };
}
module.exports = {CENTERS, allowed, createCenterAccessHandlers};
