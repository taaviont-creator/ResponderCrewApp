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
  const title = after.operationalStatus === 'delayed' ? 'Ühing reageerib viivitusega' : after.operationalStatus === 'unknown' ? 'Ühingu SAR-valmidus on teadmata' : keys.includes('readinessRestored') ? 'Ühing on taas SAR-valmis' : !after.ready ? 'Ühing ei ole SAR-valmis' : 'Ühingu valmidus muutus';
  const body = after.paused ? `Ühing on valvest maas.${after.pauseReason ? ` ${after.pauseReason}` : ''}` :
    `Valves ${after.onDutyCount}/${after.minimum} liiget.${!after.secondLevelMet ? ' Puudub II astme merepäästja.' : ''}`;
  return {title,body:body + (!after.paused && keys.some(key=>['belowMinimum','missingLevel2'].includes(key))
    ? ' Admin: kontrolli koosseisu ning otsusta, kas ühing jätkab valves või tuleb valvest maha võtta.' : '')};
}

// Refresh timestamps are evidence freshness, not an operational transition.
// Keep queued notifications valid while the actual readiness stays unchanged.
function readinessFingerprint(operational) {
  const stable = {...operational};
  if (Array.isArray(stable.centerServices)) stable.centerServices = stable.centerServices.map(service => {
    const {computedAtMs, freshUntilMs, ...meaningful} = service;
    return meaningful;
  });
  return JSON.stringify(Object.keys(stable).sort().map(key => [key, stable[key]]));
}

function createReadinessEngine({db,now = Date.now}) {
  async function recompute(org) {
    const eventId = randomUUID();
    return db.runTransaction(async tx => {
      // Queries and settings are read in the same transaction as the cursor:
      // duplicate/out-of-order triggers cannot roll the state back.
      const transactional = require('./organization-center-readiness').transactionalDb(db,tx);
      const state = db.doc(`readinessNotificationState/${org}`);
      const before = (await tx.get(state)).data();
      const after = await require('./operational-readiness').loadOperationalReadiness(transactional,org,now());
      const {crew,...operational} = after;
      const fingerprint = readinessFingerprint(operational);
      if (before?.fingerprint === fingerprint && !after.centerServices) return;
      const transition = readinessTransition(before?.operational,operational);
      tx.set(state,{operational,fingerprint,updatedAt:new Date(now())});
      if (after.centerServices) tx.set(db.doc(`organizationOperationalReadiness/${org}`), {
        organizationId:org, services:after.centerServices, computedAt:new Date(now()),
        // Human confirmation time is kept separately in each service result.
        freshUntil:new Date(Math.min(...after.centerServices.map(s=>s.freshUntilMs))),
      });
      if (transition.keys.length || transition.started.length || transition.ended.length) {
        tx.create(db.doc(`readinessNotificationEvents/${eventId}`),{organizationId:org,...transition,after:operational,fingerprint,
          memberIds:crew.map(m => m.userId),createdAt:new Date(now())});
      }
    });
  }
  async function scheduled() {
    const organizations = await db.collection('commands').where('status','==','approved').get();
    const failures=[];
    for (const org of organizations.docs) {
      try { await recompute(org.id); } catch(error) { failures.push(error); }
    }
    if(failures.length) throw new AggregateError(failures,'Ühingute valmiduse värskendamine jäi osaliselt tegemata.');
  }
  return {recompute,changed:async event => {
    const org = event.params.organizationId || orgId(event.data?.after.data()) || orgId(event.data?.before.data());
    if (org) await recompute(org);
    // Shared members can change another organization's eligibility as well.
    const uid=event.data?.after.data()?.userId || event.data?.before.data()?.userId;
    if(uid) {
      const memberships=await db.collection('memberships').where('userId','==',uid).get();
      for(const other of new Set(memberships.docs.map(d=>orgId(d.data())).filter(o=>o && o!==org))) await recompute(other);
    }
  },sharedChanged:scheduled,scheduled};
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
module.exports = {loadReadiness,readinessTransition,readinessMessage,readinessFingerprint,createReadinessEngine,createReadinessDelivery};
