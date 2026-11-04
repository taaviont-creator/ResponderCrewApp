const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {platformAccess} = require('./organization-management');

const REGIONS = Object.freeze(['Ida', 'Lääne', 'Lõuna', 'Põhja']);
const ROLES = Object.freeze(['member', 'coordinator', 'admin']);
const validUid = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const validRegions = value => Array.isArray(value) && value.length >= 1 &&
  value.length <= 4 && new Set(value).size === value.length && value.every(r => REGIONS.includes(r));
function expiryMillis(value) {
  if (value === null) return null;
  const result = value?.toMillis?.();
  return Number.isSafeInteger(result) && Math.abs(result) <= 8640000000000000 ? result : undefined;
}
function membershipContext(data, now) {
  if (data?.active !== true || !ROLES.includes(data.role) || !validRegions(data.regions) ||
      !Number.isSafeInteger(data.revision) || data.revision < 1) return null;
  const expiry = expiryMillis(data.validUntil);
  if (expiry === undefined || (expiry !== null && expiry <= now)) return null;
  return {role: data.role, regions: data.regions, revision: data.revision, validUntilMs: expiry};
}

function createTruAccessHandlers({db, now = Date.now, timestamp, fromMillis}) {
  const transactionDb = tx => ({doc: path => ({get: () => tx.get(db.doc(path))})});
  return {
    getTruContext: async request => {
      if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Logi sisse.');
      // UID always comes from the verified Firebase session, never request data.
      const member = await db.doc(`truMemberships/${request.auth.uid}`).get();
      const serverNowMs = now();
      return {serverNowMs, membership: membershipContext(member.data(), serverNowMs)};
    },
    getPlatformTruAccess: async request => {
      if (!validUid(request.data?.userId)) throw new HttpsError('invalid-argument', 'Kasutaja puudub.');
      return db.runTransaction(async tx => {
        await platformAccess(transactionDb(tx), request);
        const data = (await tx.get(db.doc(`truMemberships/${request.data.userId}`))).data();
        return {active: data?.active === true, role: ROLES.includes(data?.role) ? data.role : 'member',
          regions: validRegions(data?.regions) ? data.regions : [],
          validUntilMs: expiryMillis(data?.validUntil) ?? null, revision: data?.revision ?? 0};
      });
    },
    setTruAccess: async request => {
      const d = request.data || {};
      if (!validUid(d.userId) || typeof d.active !== 'boolean' || !ROLES.includes(d.role) ||
          !validRegions(d.regions) || !Number.isSafeInteger(d.expectedRevision) || d.expectedRevision < 0 ||
          Object.keys(d).some(k => !['userId', 'active', 'role', 'regions', 'validUntilMs', 'expectedRevision'].includes(k)) ||
          (d.validUntilMs != null && (!Number.isSafeInteger(d.validUntilMs) ||
            d.validUntilMs <= now() || d.validUntilMs > 8640000000000000))) {
        throw new HttpsError('invalid-argument', 'Kontrolli TRU liikmesuse andmeid.');
      }
      const auditId = randomUUID();
      return db.runTransaction(async tx => {
        await platformAccess(transactionDb(tx), request);
        const target = await tx.get(db.doc(`users/${d.userId}`));
        if (!target.exists) throw new HttpsError('not-found', 'Kasutajakontot ei leitud.');
        const ref = db.doc(`truMemberships/${d.userId}`);
        const before = (await tx.get(ref)).data();
        if ((before?.revision ?? 0) !== d.expectedRevision) {
          throw new HttpsError('aborted', 'Liikmesust on vahepeal muudetud. Värskenda andmed.');
        }
        const after = {active: d.active, role: d.role, regions: d.regions,
          validUntil: d.active && d.validUntilMs != null ? fromMillis(d.validUntilMs) : null,
          revision: d.expectedRevision + 1, updatedAt: timestamp(), updatedBy: request.auth.uid};
        tx.set(ref, after);
        tx.create(db.doc(`platformAudit/${auditId}`), {action: d.active ? 'truAccess.granted' : 'truAccess.revoked',
          targetId: d.userId, before: before ? {active: before.active, role: before.role,
            regions: before.regions, revision: before.revision} : null,
          after: {active: after.active, role: after.role, regions: after.regions, revision: after.revision,
            validUntil: after.validUntil}, createdBy: request.auth.uid, createdAt: timestamp()});
        return {saved: true, revision: after.revision};
      });
    },
  };
}
module.exports = {REGIONS, ROLES, validRegions, membershipContext, createTruAccessHandlers};
