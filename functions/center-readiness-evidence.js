const {HttpsError} = require('firebase-functions/v2/https');
const {orgId} = require('./statistics-history');
const {loadReadiness} = require('./organization-readiness');
const {key} = require('./response-units');
const {allocationActive} = require('./center-resources');

const validId = v => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const milliseconds = v => v?.toMillis?.() ?? null;

// Request-scoped only: fresh transaction reads on every refresh; nothing is
// cached across users or requests. This also bounds repeated cross-org reads.
function createEvidenceReader(db) {
  const docs = new Map(), queries = new Map(), readiness = new Map();
  let reads = 0;
  function budget() {
    if (++reads > 500) throw new HttpsError('resource-exhausted', 'Valmiduse tõendite kontrolli maht vajab väiksemate osadena laadimist.');
  }
  return {
    doc(path) {
      if (!docs.has(path)) { budget(); docs.set(path, db.doc(path).get().then(d => d.data())); }
      return docs.get(path);
    },
    query(collection, field, value, maximum = 300) {
      const queryKey = JSON.stringify([collection, field, value, maximum]);
      if (!queries.has(queryKey)) {
        budget();
        queries.set(queryKey, db.collection(collection).where(field, '==', value).limit(maximum + 1).get().then(s => {
          if (s.size > maximum) throw new HttpsError('resource-exhausted', 'Valmiduse tõendite loend vajab väiksemate osadena laadimist.');
          return s.docs.map(d => ({...d.data(), id: d.id}));
        }));
      }
      return queries.get(queryKey);
    },
    readiness(org, at) {
      const cacheKey = JSON.stringify([org, at]);
      if (!readiness.has(cacheKey)) { budget(); readiness.set(cacheKey, loadReadiness(db, org, at)); }
      return readiness.get(cacheKey);
    },
  };
}

function reservedElsewhere(allocation, org, at) {
  return allocationActive(allocation, at) &&
    allocation.organizationId !== org;
}

// Resource IDs below are internal filtering evidence, never returned to centers.
async function inspectCenterEvidence({reader, org, readiness, vesselEntries, now, departureAt = now}) {
  const candidates = readiness.crew.filter(m => ['onDuty', 'delayed'].includes(m.status));
  if (candidates.length > 100) throw new HttpsError('resource-exhausted', 'Valmiduse koosseisu kontrolli piir on 100 reageerijat.');
  const times = [...new Set([now, departureAt])];
  const eligibleMemberIds = [], eligibleVesselIds = [], unverifiedVesselIds = [];
  const counts = {vesselUnverified: 0, vesselOverlap: 0, vesselReservedElsewhere: 0, duplicateVessel: 0};
  let nextReviewAtMs = null;
  function boundary(value) {
    if (Number.isFinite(value) && value > now) nextReviewAtMs = Math.min(nextReviewAtMs ?? Infinity, value);
  }
  // Personal availability belongs to this membership. Membership or duty in
  // another organization must not subtract a responder from this organization.
  for (const member of candidates) if (validId(member.userId)) eligibleMemberIds.push(member.userId);
  const physicalIds = new Set();
  for (const vessel of vesselEntries) {
    const identity = await reader.doc(`vesselIdentities/${vessel.id}`);
    if (identity?.verified !== true || identity.organizationId !== org || !validId(identity.physicalResourceId)) {
      counts.vesselUnverified++;
      unverifiedVesselIds.push(vessel.id);
      continue;
    }
    const duplicate = physicalIds.has(identity.physicalResourceId);
    if (duplicate) counts.duplicateVessel++;
    physicalIds.add(identity.physicalResourceId);
    const allocation = await reader.doc(`resourceAllocations/${key('vessel', identity.physicalResourceId)}`);
    boundary(milliseconds(allocation?.validUntil));
    const reserved = times.some(at => reservedElsewhere(allocation, org, at));
    const assignedHere = times.every(at => allocationActive(allocation, at) && allocation.organizationId === org);
    if (reserved) counts.vesselReservedElsewhere++;
    const identities = await reader.query('vesselIdentities', 'physicalResourceId', identity.physicalResourceId, 20);
    let overlap = false;
    for (const other of identities) {
      if (other.organizationId === org || !validId(other.organizationId) || other.verified !== true) continue;
      const organization = await reader.doc(`commands/${other.organizationId}`);
      if (organization?.status !== 'approved' || organization.dutyPaused === true) continue;
      const equipment = await reader.doc(`equipment/${other.id}`);
      if (orgId(equipment) !== other.organizationId || equipment?.category !== 'vessel' ||
          equipment.scope === 'personal' || equipment.ownerUserId || equipment.assignedToUserId ||
          ['broken', 'outOfService'].includes(equipment.status)) continue;
      const settings = await reader.doc(`organizationResponseSettings/${other.organizationId}`);
      if (['sar', 'tross'].some(s => settings?.services?.[s]?.enabled === true &&
          settings.services[s].vesselIds?.includes(other.id))) overlap = true;
    }
    if (overlap && !assignedHere) counts.vesselOverlap++;
    if (!reserved && !duplicate && (!overlap || assignedHere)) eligibleVesselIds.push(vessel.id);
  }
  const messages = {
    vesselUnverified: 'Aluse ühene identiteet on kontrollimata',
    vesselOverlap: 'Sama alus on valitud ka teise ühingu teenusele',
    vesselReservedElsewhere: 'Alus on määratud teise ühingu üksusele',
    duplicateVessel: 'Sama füüsiline alus on valitud mitme varustuskirjena',
  };
  return {checkedAtMs: now, nextReviewAtMs, counts, eligibleMemberIds, eligibleVesselIds, unverifiedVesselIds,
    reasons: Object.entries(counts).filter(([, count]) => count > 0).map(([name, count]) => `${messages[name]} (${count}).`)};
}
module.exports = {createEvidenceReader, inspectCenterEvidence};
