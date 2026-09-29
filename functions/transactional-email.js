const {createHash} = require('node:crypto');

const SENDER = 'respondercrew@purtsesar.ee';
const SMTP_HOST = 'smtp.zone.eu';
const platformRoles = ['platformAdmin', 'platformOwner'];
const orgOf = data => data?.organizationId || data?.commandId;
const millis = value => value?.toMillis?.() ?? 0;
const safeText = value => String(value || '').replace(/[\r\n\u0000-\u001f\u007f]/g, ' ').slice(0, 200);
const validEmail = value => typeof value === 'string' && value.length <= 254 &&
  /^[^\s@<>;,]+@[^\s@<>;,]+\.[^\s@<>;,]+$/.test(value);

function activeAdmin(data, uid, org) {
  return data?.userId === uid && orgOf(data) === org &&
    (!data.commandId || data.commandId === org) &&
    ['orgAdmin', 'admin'].includes(data.role) &&
    (data.status === 'active' || data.isActive === true) &&
    (data.status === undefined || data.status === 'active') &&
    (data.isActive === undefined || data.isActive === true);
}

function smtpTransport(nodemailer, password) {
  return nodemailer.createTransport({
    host: SMTP_HOST, port: 587, secure: false, requireTLS: true,
    auth: {user: SENDER, pass: password},
    tls: {minVersion: 'TLSv1.2', rejectUnauthorized: true},
    connectionTimeout: 15000, greetingTimeout: 15000, socketTimeout: 30000,
    disableFileAccess: true, disableUrlAccess: true,
  });
}

// Claim before SMTP. An accepted message is not proof of inbox delivery.
// Unknown outcomes are deliberately not retried: SMTP has no idempotency key.
async function deliverOnce({ref, sendMail, logger, now, to, subject, text}) {
  const messageId = `<${createHash('sha256').update(ref.path).digest('hex')}@purtsesar.ee>`;
  try {
    await ref.create({status: 'sending', startedAt: new Date(now())});
  } catch (error) {
    if (error.code === 6 || error.code === 'already-exists') return;
    throw error;
  }
  let status;
  try {
    const result = await sendMail({
      from: {name: 'RespondCrew', address: SENDER}, to: {address: to},
      subject, text, messageId,
    });
    status = result.accepted?.some(address => String(address).toLowerCase() === to.toLowerCase())
      ? 'accepted' : 'failed';
  } catch (error) {
    status = ['EAUTH', 'EENVELOPE', 'EDNS', 'ECONNECTION'].includes(error.code)
      ? 'failed' : 'unknown';
    // Never log SMTP errors verbatim: responses may contain addresses or credentials.
    logger.error('Transactional email not confirmed', {deliveryPath: ref.path, status});
  }
  await ref.update({status, updatedAt: new Date(now())});
  logger.info('Transactional email attempt finished', {deliveryPath: ref.path, status});
}

function createEmailHandlers({db, auth, sendMail, logger, now = Date.now}) {
  async function sendOrganizationInviteEmail(event) {
    if (!event.data) return;
    const original = event.data.data();
    const snapshot = await event.data.ref.get();
    const invite = snapshot.data();
    const org = orgOf(invite);
    if (!invite || !org || invite.status !== 'pending' || invite.role !== 'member' ||
        (invite.commandId && invite.commandId !== org) ||
        !validEmail(invite.email) || !invite.invitedBy || millis(invite.expiresAt) <= now() ||
        orgOf(original) !== org || original.email !== invite.email ||
        original.invitedBy !== invite.invitedBy || millis(original.createdAt) !== millis(invite.createdAt)) return;
    const [organization, membership] = await Promise.all([
      db.doc(`commands/${org}`).get(),
      db.doc(`memberships/${invite.invitedBy}_${org}`).get(),
    ]);
    if (!organization.exists || (organization.data().status ?? 'approved') !== 'approved' ||
        !activeAdmin(membership.data(), invite.invitedBy, org)) return;
    const expires = new Date(millis(invite.expiresAt)).toLocaleDateString('et-EE', {timeZone: 'Europe/Tallinn'});
    await deliverOnce({ref: snapshot.ref.collection('emailDelivery').doc('status'),
      sendMail, logger, now, to: invite.email,
      subject: 'Kutse RespondCrew ühingusse',
      text: `Tere!\n\nSind on kutsutud liituma ühinguga „${safeText(organization.data().name)}“ RespondCrew rakenduses.\n\n` +
        `Ava RespondCrew ning registreeru või logi sisse selle e-posti aadressiga, millele kutse saabus. ` +
        `Võta kutse vastu äpi kutsete vaates. Kutse kehtib kuni ${expires}.\n\n` +
        'Kui sa seda kutset ei oodanud, võid kirja tähelepanuta jätta.\n\nRespondCrew',
    });
  }

  async function sendOrganizationApplicationEmail(event) {
    if (!event.data || event.data.data()?.status !== 'pending') return;
    const original = event.data.data();
    const current = await event.data.ref.get();
    const organization = current.data();
    if (!organization || organization.status !== 'pending' ||
        organization.createdBy !== original.createdBy ||
        millis(organization.createdAt) !== millis(original.createdAt)) return;
    const admins = await db.collection('users').where('systemRole', 'in', platformRoles).get();
    for (const user of admins.docs) {
      // Re-check roles and Auth accounts; never send to applicant-supplied contacts.
      const latest = await user.ref.get();
      if (!platformRoles.includes(latest.data()?.systemRole)) continue;
      let account;
      try { account = await auth.getUser(user.id); }
      catch (error) { if (error.code === 'auth/user-not-found') continue; throw error; }
      if (account.disabled || !account.emailVerified || !validEmail(account.email)) continue;
      await deliverOnce({
        ref: db.doc(`organizationApplicationEmailDeliveries/${event.params.organizationId}/recipients/${user.id}`),
        sendMail, logger, now, to: account.email,
        subject: 'RespondCrew: uus ühing ootab kinnitamist',
        text: `Ühing „${safeText(organization.name)}“ ootab kinnitamist.\n\n` +
          'Ava RespondCrew rakenduses „RespondCrew haldus“, vaata taotlus üle ning kinnita või lükka see tagasi.\n\n' +
          'RespondCrew',
      });
    }
  }
  return {sendOrganizationInviteEmail, sendOrganizationApplicationEmail};
}

module.exports = {createEmailHandlers, smtpTransport, deliverOnce, SENDER};
