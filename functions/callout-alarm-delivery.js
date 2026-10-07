// Firestore may deliver the same create event more than once. FCM does not offer
// an idempotency key, so a claimed send must never be retried after an uncertain
// outcome. The callout itself remains available in the app independently of push.
function createCalloutAlarmHandler({db, loadMembers, loadTokens, sendAlarm, logger, filterRecipients = async (_org,ids) => ids, now = () => new Date()}) {
  return async event => {
    const snapshot = event.data, calloutId = event.params.calloutId;
    const original = snapshot?.data();
    const org = original?.organizationId || original?.commandId;
    if (!snapshot || original?.status !== 'active' || !org) return;
    const [latest, organization] = await Promise.all([
      snapshot.ref.get(), db.doc(`commands/${org}`).get(),
    ]);
    const current = latest.data();
    if (!current || current.status !== 'active' ||
        (current.organizationId || current.commandId) !== org ||
        !organization.exists || (organization.data().status || 'approved') !== 'approved') return;
    const tokenRecords = await loadTokens(await filterRecipients(org,await loadMembers(org)));
    if (!tokenRecords.length) {
      logger.warn('No enabled device tokens for callout alarm', {calloutId, organizationId: org});
      return;
    }
    const delivery = db.doc(`calloutPushDeliveries/${calloutId}`);
    try {
      await delivery.create({organizationId: org, calloutId, status: 'sending',
        startedAt: now(), tokenCount: tokenRecords.length});
    } catch (error) {
      if (error.code === 6 || error.code === 'already-exists') return;
      throw error;
    }
    let result;
    try {
      result = await sendAlarm({calloutId, organizationId: org, tokenRecords, calloutType: current.calloutType || 'sar', isTest: current.isTest === true});
    } catch (_) {
      await delivery.update({status: 'unknown', updatedAt: now()});
      logger.error('Callout push result unknown; automatic resend suppressed', {calloutId, organizationId: org});
      return;
    }
    await delivery.update({status: result.failureCount ? 'partialFailure' : 'accepted',
      successCount: result.successCount, failureCount: result.failureCount, updatedAt: now()});
  };
}
module.exports = {createCalloutAlarmHandler};
