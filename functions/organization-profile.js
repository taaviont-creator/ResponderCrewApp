const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access} = require('./statistics-handlers');
const fields = ['registrationCode','organizationType','region','address','contactName','contactPhone','contactEmail','organizationEmail','description','logoUrl'];
function validateProfile(data) {
  const profile = data.profile;
  if (typeof data.name !== 'string' || !data.name.trim() || data.name.length > 300 ||
      !Number.isInteger(data.revision) || data.revision < 0 || !profile || typeof profile !== 'object' || Array.isArray(profile) ||
      Object.keys(profile).some(key => !fields.includes(key)) || fields.some(key => typeof profile[key] !== 'string' || profile[key].length > (key === 'description' ? 2500 : 300)) ||
      !profile.contactName.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.contactEmail.trim()) ||
      (profile.organizationEmail.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.organizationEmail.trim()))) {
    throw new HttpsError('invalid-argument','Kontrolli ühingu nime ja kontaktandmeid.');
  }
  if (profile.logoUrl.trim()) {
    try {if (new URL(profile.logoUrl).protocol !== 'https:') throw Error();}
    catch (_) {throw new HttpsError('invalid-argument','Logo aadress peab algama https://.');}
  }
}
function createSaveOrganizationProfileHandler({db,timestamp}) {
  return async request => {
    const d = request.data || {}; validateProfile(d);
    const auditId = randomUUID();
    return db.runTransaction(async tx => {
      const actor = await access({doc:path=>({get:()=>tx.get(db.doc(path))})}, request, {adminOnly:true});
      const ref = db.doc(`organizationProfiles/${actor.org}`), current = await tx.get(ref), old = current.data();
      if ((old?.revision || 0) !== d.revision) throw new HttpsError('aborted','Ühingu andmeid muudeti vahepeal. Ava vorm uuesti.');
      const profile = Object.fromEntries(fields.map(key => [key,d.profile[key].trim()]));
      const next = {...profile,organizationId:actor.org,createdBy:old?.createdBy || actor.organization.createdBy || request.auth.uid,
        createdAt:old?.createdAt || actor.organization.createdAt || timestamp(),
        revision:d.revision+1,updatedAt:timestamp(),updatedBy:request.auth.uid};
      tx.set(ref,next);
      tx.update(db.doc(`commands/${actor.org}`),{name:d.name.trim(),updatedAt:timestamp(),updatedBy:request.auth.uid});
      tx.create(ref.collection('history').doc(auditId),{before:old || null,after:next,oldName:actor.organization.name || null,newName:d.name.trim(),createdBy:request.auth.uid,createdAt:timestamp()});
      tx.create(db.doc(`platformAudit/${auditId}`),{organizationId:actor.org,action:'organization.profileUpdated',targetId:actor.org,
        changedFields:[...fields.filter(key=>old?.[key]!==profile[key]),...(actor.organization.name!==d.name.trim()?['name']:[])],createdBy:request.auth.uid,createdAt:timestamp()});
      return {revision:next.revision};
    });
  };
}
module.exports = {createSaveOrganizationProfileHandler,validateProfile};
