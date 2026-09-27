const { HttpsError } = require('firebase-functions/v2/https');

function activeMembership(data, userId, organizationId) {
  return data && data.userId === userId &&
    (data.organizationId || data.commandId) === organizationId &&
    (!data.organizationId || !data.commandId || data.organizationId === data.commandId) &&
    (data.status === 'active' || data.isActive === true) &&
    (data.status === undefined || data.status === 'active') &&
    (data.isActive === undefined || data.isActive === true);
}

function createMemberContactHandler({ db }) {
  return async request => {
    if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Logi sisse.');
    const { organizationId, userId } = request.data || {};
    const validId = value => typeof value === 'string' && value.length > 0 && value.length <= 128 && !value.includes('/');
    if (!validId(organizationId) || !validId(userId)) throw new HttpsError('invalid-argument', 'Vigane kontaktipäring.');
    return db.runTransaction(async transaction => {
      const refs = [db.doc(`commands/${organizationId}`),
        db.doc(`memberships/${request.auth.uid}_${organizationId}`), db.doc(`memberships/${userId}_${organizationId}`)];
      const [org, caller, target] = await transaction.getAll(...refs);
      if (org.data()?.status !== 'approved' ||
          !activeMembership(caller.data(), request.auth.uid, organizationId) ||
          !activeMembership(target.data(), userId, organizationId)) {
        throw new HttpsError('permission-denied', 'Kontakt on nähtav ainult sama ühingu aktiivsetele liikmetele.');
      }
      const profile = await transaction.get(db.doc(`users/${userId}`));
      const rawPhone = profile.data()?.phone;
      // Only return the requested contact field, never the private profile.
      const phone = typeof rawPhone === 'string' ? rawPhone.trim() : '';
      return { phone: phone || null };
    });
  };
}
module.exports = { createMemberContactHandler };
