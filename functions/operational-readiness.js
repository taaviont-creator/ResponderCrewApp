const {loadReadiness} = require('./organization-readiness');
const {loadOrganizationCenterReadiness} = require('./organization-center-readiness');
const {createEvidenceReader} = require('./center-readiness-evidence');

// Existing phone rosters retain personal statuses. Operational availability is
// the same service projection used by the center, including resources/confirmation.
async function loadOperationalReadiness(db, org, now, readiness) {
  readiness ??= await loadReadiness(db, org, now);
  const settings = (await db.doc(`organizationResponseSettings/${org}`).get()).data();
  if (!settings) return readiness; // Legacy orgs need not configure center services yet.
  const evidenceReader = createEvidenceReader(db), services = [];
  for (const service of ['sar','tross']) services.push(await loadOrganizationCenterReadiness({
    db, org, service, now, settings, readiness, evidenceReader,
  }));
  const sar = services[0];
  return {...readiness, ready: sar.status === 'ready', operationalStatus: sar.status,
    minimumMet: sar.minimum > 0 && sar.onDutyCount >= sar.minimum,
    secondLevelMet: sar.secondLevelCount > 0, onDutyCount: sar.onDutyCount,
    secondLevelOnDutyCount: sar.secondLevelCount, missing: sar.reasons,
    centerServices: services};
}
module.exports = {loadOperationalReadiness};
