const {HttpsError} = require('firebase-functions/v2/https');
const {access} = require('./statistics-handlers');
const KEYS = ['newCallout','readinessLost','readinessRestored','belowMinimum','missingLevel2','memberOffDuty','ownAbsenceStarted','ownAbsenceEnded','certificates'];
function preferences(role, stored = {}) {
  const admin = ['admin','orgAdmin'].includes(role);
  const result = {newCallout:true,readinessLost:admin,readinessRestored:admin,belowMinimum:admin,missingLevel2:admin,
    memberOffDuty:false,ownAbsenceStarted:true,ownAbsenceEnded:true,certificates:true};
  for (const key of KEYS) if (typeof stored?.[key] === 'boolean') result[key] = stored[key];
  return result;
}
async function loadPreferences(db, org, uid, role) {
  const data = (await db.doc(`notificationPreferences/${uid}_${org}`).get()).data();
  return preferences(role, data?.preferences);
}
function createSetNotificationPreferenceHandler({db,timestamp}) {
  return async request => {
    const {key,enabled} = request.data || {};
    if (!KEYS.includes(key) || typeof enabled !== 'boolean') throw new HttpsError('invalid-argument','Kontrolli teavituse valikut.');
    return db.runTransaction(async tx => {
      const {org} = await access({doc:path => ({get:() => tx.get(db.doc(path))})},request);
      tx.set(db.doc(`notificationPreferences/${request.auth.uid}_${org}`),{organizationId:org,userId:request.auth.uid,
        preferences:{[key]:enabled},updatedAt:timestamp()},{merge:true});
      return {saved:true};
    });
  };
}
module.exports = {KEYS,preferences,loadPreferences,createSetNotificationPreferenceHandler};
