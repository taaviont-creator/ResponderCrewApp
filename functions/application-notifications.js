const {orgId,millis} = require('./statistics-history');
const {active} = require('./contribution-statistics');
const {organizationDocs} = require('./statistics-handlers');
const {deliverOnce} = require('./transactional-email');
const {deliveryId,platformRole} = require('./personal-notifications');
const pending = d => d?.role === 'member' && d.status === 'pending' && d.isActive === false;
// eslint-disable-next-line no-control-regex -- Intentionally reject/remove control characters from untrusted input.
const safe = value => String(value || '').replace(/[\r\n\u0000-\u001f\u007f]/g,' ').slice(0,200);
const validEmail = s => typeof s === 'string' && /^[^\s@<>;,]+@[^\s@<>;,]+\.[^\s@<>;,]+$/.test(s) && s.length <= 254;

async function memberRequestContext(db,event) {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!pending(after) || pending(before) || !event.id) return null;
  const org = orgId(after);
  if (!org || event.params.membershipId !== `${after.userId}_${org}`) return null;
  const current = (await event.data.after.ref.get()).data();
  if (!pending(current) || orgId(current) !== org || current.userId !== after.userId || millis(current.joinedAt) !== millis(after.joinedAt)) return null;
  const organization = (await db.doc(`commands/${org}`).get()).data();
  if (organization?.status !== 'approved') return null;
  const members = await organizationDocs(db,'memberships',org);
  const admins = members.filter(d => d.id === `${d.data().userId}_${org}` && active(d.data()) &&
    ['admin','orgAdmin'].includes(d.data().role) && d.data().userId !== after.userId).map(d=>d.data().userId);
  return {org,organization,applicant:current.displayName || 'Liige',admins};
}
function createMemberApplicationNotification({db,deliver}) {
  return async event => {
    const context = await memberRequestContext(db,event);
    if (!context) return;
    const {org,organization,applicant,admins} = context;
    for (const uid of admins) await deliver({sourceId:`membership:${event.id}`,org,uid,title:'Uus liitumistaotlus',
      body:`${safe(applicant)} ootab ühingus „${safe(organization.name)}“ kinnitamist.`,relatedType:'member_request',relatedId:event.params.membershipId});
  };
}
function createMemberApplicationEmail({db,auth,sendMail,logger,now = Date.now}) {
  return async event => {
    const context = await memberRequestContext(db,event);
    if (!context) return;
    for (const uid of context.admins) {
      // Role can change after the initial query; verify before sending.
      const member = (await db.doc(`memberships/${uid}_${context.org}`).get()).data();
      if (orgId(member) !== context.org || member?.userId !== uid || !active(member) || !['admin','orgAdmin'].includes(member.role)) continue;
      let account;
      try { account = await auth.getUser(uid); }
      catch (e) { if (e.code === 'auth/user-not-found') continue; throw e; }
      if (account.disabled || !validEmail(account.email)) continue;
      await deliverOnce({ref:db.doc(`memberApplicationEmailDeliveries/${deliveryId(event.id,uid)}`),sendMail,logger,now,to:account.email,
        subject:'RespondCrew: liitumistaotlus ootab kinnitamist',
        text:`${safe(context.applicant)} esitas ühinguga „${safe(context.organization.name)}“ liitumise taotluse.\n\nAva RespondCrew liikmete vaade ning vaata taotlus üle.\n\nRespondCrew`});
    }
  };
}
function createOrganizationApplicationNotification({db,deliver}) {
  return async event => {
    const original = event.data?.data();
    if (original?.status !== 'pending') return;
    const current = (await event.data.ref.get()).data();
    if (current?.status !== 'pending' || current.createdBy !== original.createdBy || millis(current.createdAt) !== millis(original.createdAt)) return;
    const admins = await db.collection('users').where('systemRole','in',['platformAdmin','platformOwner']).get();
    for (const user of admins.docs) if (platformRole(user.data().systemRole)) {
      await deliver({sourceId:`organization:${event.params.organizationId}:${millis(current.createdAt)}`,org:event.params.organizationId,
        uid:user.id,platform:true,title:'Ühing ootab kinnitamist',body:`„${safe(current.name)}“ taotlus ootab ülevaatamist.`,
        relatedType:'platformApplication',relatedId:event.params.organizationId});
    }
  };
}
module.exports = {memberRequestContext,createMemberApplicationNotification,createMemberApplicationEmail,createOrganizationApplicationNotification};
