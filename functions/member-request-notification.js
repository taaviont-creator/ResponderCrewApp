const { createHash } = require('node:crypto');

const organizationId = (data) => data?.organizationId || data?.commandId;
const isPending = (data) => data?.role === 'member' &&
  data.status === 'pending' && data.isActive === false;
const isAdmin = (data, org) => organizationId(data) === org &&
  ['orgAdmin', 'admin'].includes(data.role) &&
  (data.status === 'active' || data.isActive === true) &&
  (data.status === undefined || data.status === 'active') &&
  (data.isActive === undefined || data.isActive === true);

// Dependencies are injected so recipient isolation and event retries can be tested.
function createMemberRequestHandler({db, messaging, logger, loadTokens}) {
  return async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!isPending(after) || isPending(before)) return;
    const org = organizationId(after);
    if (!org || !after.userId || !event.id) return;
    const latest = await event.data.after.ref.get();
    const current = latest.data();
    if (!isPending(current) || organizationId(current) !== org ||
        current.userId !== after.userId ||
        current.joinedAt?.toMillis() !== after.joinedAt?.toMillis()) return;

    const snapshots = await Promise.all(['organizationId', 'commandId'].map(
      field => db.collection('memberships').where(field, '==', org).get(),
    ));
    const userIds = [...new Set(snapshots.flatMap(s => s.docs)
      .map(d => d.data()).filter(d => isAdmin(d, org) && d.userId !== after.userId)
      .map(d => d.userId).filter(Boolean))];
    const tokens = await loadTokens(userIds);
    if (!tokens.length) {
      logger.info('No admin devices for member request', {organizationId: org});
      return;
    }
    // Claim before FCM: duplicate event deliveries must not alert admins twice.
    // No automatic resend after an ambiguous FCM failure; the live in-app queue
    // remains authoritative even when a phone cannot receive a push.
    const deliveryId = createHash('sha256').update(event.id).digest('hex');
    try {
      await db.collection('memberRequestPushDeliveries').doc(deliveryId).create({
        organizationId: org, membershipId: event.params.membershipId,
        createdAt: new Date(),
      });
    } catch (error) {
      if (error.code === 6 || error.code === 'already-exists') return;
      throw error;
    }
    let successCount = 0;
    let failureCount = 0;
    for (let start = 0; start < tokens.length; start += 500) {
      const response = await messaging.sendEachForMulticast({
        tokens: tokens.slice(start, start + 500).map(t => t.token),
        notification: {title: 'Liitumistaotlus', body: 'Liige ootab sinu ühingus kinnitamist.'},
        data: {type: 'member_request', organizationId: org,
          membershipId: event.params.membershipId},
        android: {priority: 'high', notification: {
          channelId: 'member_requests', tag: deliveryId,
        }},
        apns: {payload: {aps: {sound: 'default'}}},
      });
      successCount += response.successCount;
      failureCount += response.failureCount;
    }
    logger.info('Member request push send finished', {
      organizationId: org, membershipId: event.params.membershipId,
      successCount, failureCount,
    });
  };
}

module.exports = {createMemberRequestHandler};
