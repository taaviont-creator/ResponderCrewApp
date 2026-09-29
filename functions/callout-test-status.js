const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access} = require('./statistics-handlers');
const {orgId} = require('./statistics-history');

function createSetCalloutTestStatusHandler({db,timestamp}) {
  return async request => {
    const {calloutId,isTest,expectedIsTest} = request.data || {};
    if (typeof calloutId !== 'string' || !calloutId || calloutId.includes('/') || calloutId.length > 128 ||
        typeof isTest !== 'boolean' || typeof expectedIsTest !== 'boolean') {
      throw new HttpsError('invalid-argument','Kontrolli sündmuse tunnust.');
    }
    const auditId = randomUUID();
    return db.runTransaction(async tx => {
      const actor = await access({doc:path => ({get:() => tx.get(db.doc(path))})},request,{adminOnly:true});
      const ref = db.doc(`callouts/${calloutId}`), old = (await tx.get(ref)).data();
      if (orgId(old) !== actor.org) throw new HttpsError('permission-denied','Väljakutse ei kuulu sellesse ühingusse.');
      const before = old.isTest === true;
      if (before !== expectedIsTest) throw new HttpsError('aborted','Tunnust muudeti vahepeal. Ava sündmus uuesti.');
      if (before === isTest) return {saved:true};
      tx.update(ref,{isTest,updatedBy:request.auth.uid,updatedAt:timestamp()});
      const audit = {organizationId:actor.org,before:{isTest:before},after:{isTest},createdBy:request.auth.uid,createdAt:timestamp()};
      tx.create(db.doc(`callouts/${calloutId}/changeHistory/${auditId}`),audit);
      tx.create(db.doc(`platformAudit/${auditId}`),{...audit,action:'callout.testStatusChanged',targetId:calloutId,changedFields:['isTest']});
      return {saved:true};
    });
  };
}
module.exports = {createSetCalloutTestStatusHandler};
