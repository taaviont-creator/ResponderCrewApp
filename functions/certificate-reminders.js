const {createHash} = require('node:crypto');
const DAY = 86400000;
const orgId = d => d.organizationId || d.commandId;
const active = d => (d.status === 'active' || d.isActive === true) &&
  (d.status === undefined || d.status === 'active') && (d.isActive === undefined || d.isActive === true);
function expiryStage(value, now = new Date()) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const expiry = new Date(`${value}T00:00:00Z`);
  if (!Number.isFinite(+expiry) || expiry.toISOString().slice(0, 10) !== value) return null;
  const today = new Intl.DateTimeFormat('sv-SE', {timeZone: 'Europe/Tallinn', year: 'numeric', month: '2-digit', day: '2-digit'}).format(now);
  const days = Math.round((expiry - new Date(`${today}T00:00:00Z`)) / DAY);
  return days < 0 ? 'expired' : days <= 30 ? 'expiringSoon' : null;
}
function recipients(certificate, memberships) {
  const org = orgId(certificate);
  const members = memberships.filter(d => orgId(d) === org && active(d));
  if (!members.some(d => d.userId === certificate.userId)) return [];
  return [...new Set(members.filter(d => d.userId === certificate.userId || ['admin', 'orgAdmin'].includes(d.role)).map(d => d.userId).filter(Boolean))];
}
function reminderId(id, expiry, stage, uid) {
  return createHash('sha256').update(JSON.stringify([id, expiry, stage, uid])).digest('hex');
}
function createCertificateReminderJob({db, messaging, loadTokens, logger, now = () => new Date()}) {
  return async () => {
    const organizations = new Map();
    let cursor;
    let failures = 0;
    do {
      let query = db.collection('certificates').orderBy('__name__').limit(250);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const document of page.docs) {
        const certificate = document.data();
        const stage = expiryStage(certificate.expiresAt, now());
        if (!stage || certificate.status === 'missing' || !certificate.userId) continue;
        const org = orgId(certificate);
        if (!org) continue;
        try {
          if (!organizations.has(org)) {
            const organization = (await db.collection('commands').doc(org).get()).data();
            let members = [];
            if (organization?.status === 'approved') {
              const snapshots = await Promise.all(['organizationId', 'commandId'].map(field => db.collection('memberships').where(field, '==', org).get()));
              members = snapshots.flatMap(s => s.docs.map(d => d.data()));
            }
            organizations.set(org, members);
          }
          for (const uid of recipients(certificate, organizations.get(org))) {
            const id = reminderId(document.id, certificate.expiresAt, stage, uid);
            const ref = db.collection('certificateReminders').doc(id);
            const title = stage === 'expired' ? 'Tunnistus on aegunud' : 'Tunnistus aegub peagi';
            const body = `${certificate.userName || 'Liige'}: ${certificate.title || 'Tunnistus'}. Kehtib kuni ${certificate.expiresAt}.`;
            try {
              await ref.create({id, organizationId: org, commandId: org, recipientUserId: uid,
                title, message: body, type: 'certificate', priority: stage === 'expired' ? 'high' : 'normal',
                relatedType: 'certificate', relatedId: document.id, memberUserId: certificate.userId,
                createdBy: 'system', createdAt: now(), updatedAt: now(), expiresAt: certificate.expiresAt,
              });
            } catch (error) {
              if (error.code === 6 || error.code === 'already-exists') continue;
              throw error;
            }
            // The durable inbox is authoritative. Claim before FCM to avoid repeated
            // daily alerts after an ambiguous send. Renewals have a new date/key.
            const tokens = await loadTokens([uid]);
            for (let start = 0; start < tokens.length; start += 500) {
              const result = await messaging.sendEachForMulticast({tokens: tokens.slice(start, start + 500).map(t => t.token),
                notification: {title, body},
                data: {type: 'certificate_reminder', organizationId: org, memberUserId: certificate.userId, relatedId: document.id},
                android: {notification: {channelId: 'certificate_reminders', tag: id}},
                apns: {payload: {aps: {sound: 'default'}}},
              });
              if (result.failureCount) logger.warn('Certificate reminder device delivery failed', {id, failureCount: result.failureCount});
            }
          }
        } catch (error) { failures++; logger.error('Certificate reminder failed', {certificateId: document.id, code: error.code || 'unknown'}); }
      }
      cursor = page.size === 250 ? page.docs.at(-1) : null;
    } while (cursor);
    if (failures) throw new Error(`${failures} certificate reminders failed; see logs`);
  };
}
module.exports = {expiryStage, recipients, reminderId, createCertificateReminderJob};
