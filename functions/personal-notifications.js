const {createHash} = require('node:crypto');
const {active} = require('./contribution-statistics');
const {orgId} = require('./statistics-history');
const {loadPreferences} = require('./notification-preferences');
const platformRole = role => ['platformAdmin','platformOwner'].includes(role);
const deliveryId = (...parts) => createHash('sha256').update(JSON.stringify(parts)).digest('hex');

// One durable inbox record per recipient and source event. Never blindly retry
// an uncertain FCM send. The inbox remains usable without registered devices.
function createPersonalDelivery({db,messaging,loadTokens,logger,now = () => new Date()}) {
  return async ({sourceId,org,uid,title,body,type = 'system',relatedType,relatedId = '',preferenceKeys = [],platform = false,pushType,urgent = false}) => {
    if (platform) {
      if (!platformRole((await db.doc(`users/${uid}`).get()).data()?.systemRole)) return;
    } else {
      const [m,o] = await Promise.all([db.doc(`memberships/${uid}_${org}`).get(),db.doc(`commands/${org}`).get()]);
      if (orgId(m.data()) !== org || m.data()?.userId !== uid || !active(m.data()) || o.data()?.status !== 'approved') return;
      if (relatedType === 'member_request' && !['admin','orgAdmin'].includes(m.data().role)) return;
      const prefs = await loadPreferences(db,org,uid,m.data().role);
      if (preferenceKeys.length && !preferenceKeys.some(key => prefs[key] === true)) return;
    }
    const id = deliveryId(sourceId,uid), ref = db.doc(`userNotifications/${id}`);
    try { await ref.create({id,organizationId:platform?'platform':org,commandId:platform?'platform':org,recipientUserId:uid,
      title,message:body,type,priority:type==='availability'?'high':'normal',relatedType,relatedId,
      createdBy:'system',createdAt:now(),updatedAt:now(),pushStatus:'pending'}); }
    catch (error) { if (error.code === 6 || error.code === 'already-exists') return; throw error; }
    try {
      const tokens = await loadTokens([uid]);
      let failed = 0;
      for (let start=0; start<tokens.length; start+=500) {
        const channelId = type === 'availability' ? 'readiness_changes' : urgent ? 'dispatch_updates' : 'respondcrew_info';
        const result = await messaging.sendEachForMulticast({tokens:tokens.slice(start,start+500).map(t => t.token),
          notification:{title,body},data:{type:pushType || relatedType,organizationId:org,relatedId,notificationId:id,...(urgent?{urgent:'true'}:{})},
          android:{priority:urgent?'high':'normal',notification:{channelId,tag:id}},apns:{payload:{aps:{sound:'default'}}}});
        failed += result.failureCount;
      }
      await ref.update({pushStatus:tokens.length ? failed?'partialFailure':'accepted' : 'noDevices'});
    } catch (_) {
      await ref.update({pushStatus:'unknown'});
      logger.error('Personal notification push outcome unknown',{id});
    }
  };
}
module.exports = {createPersonalDelivery,deliveryId,platformRole};
