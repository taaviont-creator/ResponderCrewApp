const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access} = require('./statistics-handlers');
const {loadReadiness} = require('./organization-readiness');
const {evaluateCenterReadiness} = require('./center-readiness');
const {orgId} = require('./statistics-history');
const {createEvidenceReader, inspectCenterEvidence} = require('./center-readiness-evidence');

const SERVICES = ['sar', 'tross'];
const validId = v => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const millis = v => v?.toMillis?.() ?? null;
function transactionalDb(db, tx) {
  const query = q => ({where: (...args) => query(q.where(...args)),
    limit: maximum => query(q.limit(maximum)), get: () => tx.get(q)});
  return {
    doc: path => ({get: () => tx.get(db.doc(path))}),
    collection: name => query(db.collection(name)),
  };
}
function confirmationView(data) {
  return {
    revision: data?.revision ?? 0,
    settingsRevision: data?.settingsRevision ?? null,
    confirmedAtMs: millis(data?.confirmedAt),
    validUntilMs: millis(data?.validUntil),
    validityMode: data?.validityMode === 'untilChanged' && data.validUntil === null ? 'untilChanged' : 'timed',
    expectedReadyAtMs: millis(data?.expectedReadyAt),
    unavailable: data?.unavailable === true,
    reason: typeof data?.reason === 'string' ? data.reason : '',
  };
}

// The organization and center call this same projection. Never copy member
// identities, private notes or certificate details into a center response.
async function loadOrganizationCenterReadiness({db, org, service, now, settings, readiness, evidenceReader}) {
  if (!SERVICES.includes(service)) throw new HttpsError('invalid-argument', 'Tundmatu teenus.');
  settings ??= (await db.doc(`organizationResponseSettings/${org}`).get()).data();
  readiness ??= await loadReadiness(db, org, now);
  const policy = settings?.services?.[service];
  const stored = (await db.doc(`organizationReadinessConfirmations/${org}_${service}`).get()).data();
  const confirmation = confirmationView(stored);
  // Normal operation follows existing organization duty + actual resources.
  // Only explicit restrictions need an extra admin action; no second "on duty" switch.
  const automatic = !confirmation.unavailable && confirmation.expectedReadyAtMs === null;
  const vessels = [];
  const vesselEntries = [];
  for (const id of (Array.isArray(policy?.vesselIds) ? policy.vesselIds : []).slice(0, 10)) {
    const e = validId(id) ? (await db.doc(`equipment/${id}`).get()).data() : null;
    if (orgId(e) === org && e.category === 'vessel' && e.scope !== 'personal' && !e.ownerUserId && !e.assignedToUserId) {
      vessels.push({name: e.name || 'Alus', status: ['ok','needsMaintenance','broken','outOfService'].includes(e.status) ? e.status : 'unknown'});
      vesselEntries.push({id});
    }
  }
  const future = confirmation.expectedReadyAtMs > now
    ? await loadReadiness(db, org, confirmation.expectedReadyAtMs) : null;
  const evidence = policy?.enabled === true ? await inspectCenterEvidence({
    reader: evidenceReader ?? createEvidenceReader(db), org, readiness, vesselEntries, now,
    departureAt: future ? confirmation.expectedReadyAtMs : now,
  }) : null;
  const eligible = r => r && evidence ? {...r, crew: r.crew.filter(m => evidence.eligibleMemberIds.includes(m.userId))} : r;
  const usableVessels = vessels.map((v, i) => !evidence || evidence.eligibleVesselIds.includes(vesselEntries[i].id) ? v :
    {...v, status: evidence.unverifiedVesselIds.includes(vesselEntries[i].id) ? 'unknown' : 'outOfService'});
  const summary = evaluateCenterReadiness({service, readiness: eligible(readiness), policy, vessels: usableVessels, now,
    revision: settings?.revision ?? 0,
    confirmation: {...confirmation, revision: confirmation.settingsRevision},
    futureReadiness: eligible(future),
    evidenceReady: true,
    automatic,
  });
  return {service, enabled: policy?.enabled === true, automatic, vessels, ...summary,
    reasons: [...summary.reasons, ...(evidence?.reasons ?? [])],
    freshUntilMs: Math.min(summary.freshUntilMs, evidence?.nextReviewAtMs ?? Infinity),
    restrictionReason: readiness.paused ? 'Ühing on valvest maas.' : automatic ? '' : confirmation.reason,
    confirmedAtMs: automatic ? null : summary.confirmedAtMs,
    confirmationValidUntilMs: automatic ? null : confirmation.validUntilMs};
}

function createOrganizationCenterReadinessHandlers({db, timestamp, fromMillis, now = Date.now}) {
  return {
    getOrganizationCenterReadiness: request => db.runTransaction(async tx => {
      const source = transactionalDb(db, tx);
      const actor = await access(source, request);
      const at = now();
      const settings = (await tx.get(db.doc(`organizationResponseSettings/${actor.org}`))).data();
      const readiness = await loadReadiness(source, actor.org, at);
      const evidenceReader = createEvidenceReader(source);
      const entries = [];
      for (const service of SERVICES) {
        const stored = (await tx.get(db.doc(`organizationReadinessConfirmations/${actor.org}_${service}`))).data();
        entries.push({
          ...await loadOrganizationCenterReadiness({db: source, org: actor.org, service, now: at, settings, readiness, evidenceReader}),
          confirmation: confirmationView(stored),
        });
      }
      return {entries, canManage: actor.admin, settingsRevision: settings?.revision ?? 0, serverNowMs: now()};
    }),
    setOrganizationReadinessConfirmation: async request => {
      const d = request.data;
      const keys = ['organizationId','service','action','expectedRevision','settingsRevision','validForMinutes','validityMode','delayMinutes','reason'];
      const indefinite = d?.validityMode === 'untilChanged' && d?.validForMinutes === null;
      if (!d || Object.keys(d).some(k => !keys.includes(k)) || !SERVICES.includes(d.service) ||
          !['confirm','unavailable','withdraw'].includes(d.action) ||
          !Number.isSafeInteger(d.expectedRevision) || d.expectedRevision < 0 ||
          !Number.isSafeInteger(d.settingsRevision) || d.settingsRevision < 0 ||
          typeof d.reason !== 'string' || d.reason.length > 240 ||
          (!indefinite && (d.validityMode != null && d.validityMode !== 'timed' || ![720,1440].includes(d.validForMinutes))) ||
          !Number.isInteger(d.delayMinutes) || d.delayMinutes < 0 || d.delayMinutes > 60 ||
          (d.action !== 'confirm' && d.delayMinutes !== 0)) {
        throw new HttpsError('invalid-argument', 'Kontrolli kinnituse kestust, viivitust ja selgitust.');
      }
      return db.runTransaction(async tx => {
        const source = transactionalDb(db, tx);
        const actor = await access(source, request, {adminOnly: true});
        const config = (await tx.get(db.doc(`organizationResponseSettings/${actor.org}`))).data();
        const ref = db.doc(`organizationReadinessConfirmations/${actor.org}_${d.service}`);
        const before = (await tx.get(ref)).data();
        if ((before?.revision ?? 0) !== d.expectedRevision || (config?.revision ?? 0) !== d.settingsRevision) {
          throw new HttpsError('aborted', 'Valmiduse andmeid on vahepeal muudetud. Laadi vaade uuesti.');
        }
        if (d.action !== 'withdraw' && config?.services?.[d.service]?.enabled !== true) {
          throw new HttpsError('failed-precondition', 'Lülita teenus esmalt ühingu teenuste seadetes sisse.');
        }
        const at = now();
        const after = {
          organizationId: actor.org, service: d.service, revision: d.expectedRevision + 1,
          settingsRevision: d.settingsRevision, confirmedAt: d.action === 'withdraw' ? null : fromMillis(at),
          validityMode: indefinite ? 'untilChanged' : 'timed',
          validUntil: d.action === 'withdraw' || indefinite ? null : fromMillis(at + d.validForMinutes * 60000),
          expectedReadyAt: d.delayMinutes ? fromMillis(at + d.delayMinutes * 60000) : null,
          unavailable: d.action === 'unavailable', reason: d.action === 'withdraw' ? '' : d.reason.trim(),
          updatedBy: request.auth.uid, updatedAt: timestamp(),
        };
        tx.set(ref, after);
        tx.create(db.doc(`platformAudit/${randomUUID()}`), {
          action: 'organization.readinessConfirmation', organizationId: actor.org,
          targetId: ref.id, before: confirmationView(before), after: confirmationView(after),
          createdBy: request.auth.uid, createdAt: timestamp(),
        });
        return {saved: true, revision: after.revision};
      });
    },
  };
}
module.exports = {loadOrganizationCenterReadiness, createOrganizationCenterReadinessHandlers, transactionalDb};
