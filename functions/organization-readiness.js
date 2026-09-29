const {randomUUID} = require('node:crypto');
const {organizationDocs} = require('./statistics-handlers');
const {evaluateReadiness} = require('./effective-readiness');
const {orgId} = require('./statistics-history');

async function loadReadiness(db,org,now) {
  const [organization,settings,...lists] = await Promise.all([
    db.doc(`commands/${org}`).get(),db.doc(`organizationReadinessSummaries/${org}`).get(),
    ...['memberships','availability','plannedUnavailability','plannedUnavailabilityRules'].map(name => organizationDocs(db,name,org)),
  ]);
  return evaluateReadiness({org,organization:organization.data() || {},settings:settings.data(),now,
    ...Object.fromEntries(['members','availability','periods','rules'].map((name,i) => [name,lists[i].map(d=>({...d.data(),id:d.id}))]))});
}

function readinessTransition(before,after) {
  if (!before) return {keys:[],started:[],ended:[]};
  const left = (before.dutyUserIds || []).filter(uid => !after.dutyUserIds.includes(uid));
  return {keys:[
    ...(before.ready && !after.ready ? ['readinessLost'] : []),
    ...(!before.ready && after.ready ? ['readinessRestored'] : []),
    ...(before.minimumMet && !after.minimumMet ? ['belowMinimum'] : []),
    ...(before.secondLevelMet && !after.secondLevelMet ? ['missingLevel2'] : []),
    ...(left.length ? ['memberOffDuty'] : []),
  ],started:after.unavailableUserIds.filter(uid => !(before.unavailableUserIds || []).includes(uid)),
    ended:(before.unavailableUserIds || []).filter(uid => !after.unavailableUserIds.includes(uid)),left};
}
function readinessMessage(after,keys) {
  const title = keys.includes('readinessRestored') ? 'Ühing on taas SAR-valmis' : !after.ready ? 'Ühing ei ole SAR-valmis' : 'Ühingu valmidus muutus';
  const body = after.paused ? `Ühing on valvest maas.${after.pauseReason ? ` ${after.pauseReason}` : ''}` :
    `Valves ${after.onDutyCount}/${after.minimum} liiget.${!after.secondLevelMet ? ' Puudub II astme merepäästja.' : ''}`;
  return {title,body};
}

function createReadinessEngine({db,now = Date.now}) {
  async function recompute(org) {
    const eventId = randomUUID();
    return db.runTransaction(async tx => {
      // Queries and settings are read in the same transaction as the cursor:
      // duplicate/out-of-order triggers cannot roll the state back.
      const transactional = {
        doc:path => ({get:() => tx.get(db.doc(path))}),
        collection:name => ({where:(...args) => ({get:() => tx.get(db.collection(name).where(...args))})}),
      };
      const state = db.doc(`readinessNotificationState/${org}`);
      const before = (await tx.get(state)).data();
      const after = await loadReadiness(transactional,org,now());
      const {crew,...operational} = after;
      const fingerprint = JSON.stringify(Object.keys(operational).sort().map(key=>[key,operational[key]]));
      if (before?.fingerprint === fingerprint) return;
      const transition = readinessTransition(before?.operational,operational);
      tx.set(state,{operational,fingerprint,updatedAt:new Date(now())});
      if (transition.keys.length || transition.started.length || transition.ended.length) {
        tx.create(db.doc(`readinessNotificationEvents/${eventId}`),{organizationId:org,...transition,after:operational,fingerprint,
          memberIds:crew.map(m => m.userId),createdAt:new Date(now())});
      }
    });
  }
  return {recompute,changed:async event => {
    const org = event.params.organizationId || orgId(event.data?.after.data()) || orgId(event.data?.before.data());
    if (org) await recompute(org);
  },scheduled:async () => {
    const organizations = await db.collection('commands').where('status','==','approved').get();
    for (const org of organizations.docs) await recompute(org.id);
  }};
}
function createReadinessDelivery({db,deliver,preferencesFor}) {
  return async event => {
    const d = event.data?.data();
    if (!d) return;
    if (db && (await db.doc(`readinessNotificationState/${d.organizationId}`).get()).data()?.fingerprint !== d.fingerprint) return;
    const source = event.params.eventId, message = readinessMessage(d.after,d.keys);
    for (const uid of d.memberIds) {
      const own = d.started.includes(uid) ? 'ownAbsenceStarted' : d.ended.includes(uid) ? 'ownAbsenceEnded' : null;
      const prefs = await preferencesFor(d.organizationId,uid);
      const orgKeys = d.keys.filter(key=>prefs[key]);
      const ownEnabled = own && prefs[own];
      const ownText = own === 'ownAbsenceStarted' ? 'Sinu planeeritud mittevalve algas.' : 'Sinu planeeritud mittevalve lõppes.';
      if (!orgKeys.length && !ownEnabled) continue;
      await deliver({sourceId:source,org:d.organizationId,uid,
        title:orgKeys.length ? message.title : ownText,
        body:orgKeys.length ? `${message.body}${ownEnabled ? ` ${ownText}` : ''}` : 'Vaata oma valmisolekut ja planeeringuid.',
        type:'availability',relatedType:orgKeys.length ? 'organizationReadiness' : 'personalAvailability',
        preferenceKeys:[...orgKeys,...(ownEnabled?[own]:[])]});
    }
  };
}
module.exports = {loadReadiness,readinessTransition,readinessMessage,createReadinessEngine,createReadinessDelivery};
