const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createEmailHandlers, smtpTransport, SENDER} = require('./transactional-email');

const timestamp = n => ({toMillis: () => n});
const invite = {organizationId: 'org', commandId: 'org', invitedBy: 'admin',
  email: 'member@example.ee', role: 'member', status: 'pending',
  createdAt: timestamp(100), expiresAt: timestamp(300)};
const membership = {userId: 'admin', organizationId: 'org', commandId: 'org',
  role: 'orgAdmin', status: 'active', isActive: true};
const organization = {name: 'Pääste', createdBy: 'admin', status: 'approved', createdAt: timestamp(100)};
function fixture({latest = invite, member = membership, org = organization,
  send, users = {}, accounts = {}} = {}) {
  const records = new Map(Object.entries({
    'organizationInvites/invite': latest, 'memberships/admin_org': member,
    'commands/org': org, ...Object.fromEntries(Object.entries(users).map(([id, data]) => [`users/${id}`, data])),
  }).filter(([, value]) => value != null));
  const doc = path => ({path, id: path.split('/').at(-1),
    get: async () => ({exists: records.has(path), data: () => records.get(path), ref: doc(path)}),
    collection: name => ({doc: id => doc(`${path}/${name}/${id}`)}),
    create: async data => {
      if (records.has(path)) throw Object.assign(new Error('exists'), {code: 6});
      records.set(path, data);
    },
    update: async data => records.set(path, {...records.get(path), ...data}),
  });
  const db = {doc, collection: () => ({where: (field, op, roles) => ({get: async () => ({
    docs: Object.entries(users).filter(([, data]) => roles.includes(data[field]))
      .map(([id]) => ({id, ref: doc(`users/${id}`)})),
  })})})};
  const sends = [], logs = [];
  const handlers = createEmailHandlers({db,
    auth: {getUser: async uid => accounts[uid] || {disabled: true}},
    sendMail: async message => {sends.push(message); return send ? send(message) : {accepted: [message.to.address]};},
    logger: {info: (...a) => logs.push(a), error: (...a) => logs.push(a)}, now: () => 200,
  });
  const event = {params: {inviteId: 'invite', organizationId: 'org'}, data: {
    data: () => invite, ref: doc('organizationInvites/invite'),
  }};
  const orgEvent = {...event, data: {data: () => org, ref: doc('commands/org')}};
  return {...handlers, event, orgEvent, sends, logs, records};
}

test('valid invite uses fixed sender and separate server-owned delivery state', async () => {
  const f = fixture();
  await f.sendOrganizationInviteEmail(f.event);
  assert.equal(f.sends[0].from.address, SENDER);
  assert.equal(f.sends[0].to.address, invite.email);
  assert.match(f.sends[0].text, /Pääste/);
  assert.match(f.sends[0].text, /kutsete vaates/);
  assert.equal(f.records.get('organizationInvites/invite/emailDelivery/status').status, 'accepted');
  assert.deepEqual(f.records.get('organizationInvites/invite'), invite);
});

test('concurrent event delivery and later retry send only one email', async () => {
  const f = fixture();
  await Promise.all([f.sendOrganizationInviteEmail(f.event), f.sendOrganizationInviteEmail(f.event)]);
  await f.sendOrganizationInviteEmail(f.event);
  assert.equal(f.sends.length, 1);
});

test('cancelled, accepted, expired, deleted or changed invitations never send', async () => {
  for (const latest of [null, {...invite, status: 'cancelled'}, {...invite, status: 'accepted'},
    {...invite, expiresAt: timestamp(200)}, {...invite, email: 'other@example.ee'},
    {...invite, commandId: 'other'}, {...invite, createdAt: timestamp(101)},
    {...invite, role: 'orgAdmin'}]) {
    const f = fixture({latest}); await f.sendOrganizationInviteEmail(f.event);
    assert.equal(f.sends.length, 0);
  }
});

test('platform role alone, inactive, cross-org, ordinary or removed admin cannot send invites', async () => {
  for (const member of [null, {...membership, role: 'member'}, {...membership, isActive: false},
    {...membership, status: 'removed'}, {...membership, commandId: 'other'},
    {...membership, userId: 'other'}, {...membership, organizationId: 'other'}]) {
    const f = fixture({member, users: {admin: {systemRole: 'platformAdmin'}}});
    await f.sendOrganizationInviteEmail(f.event); assert.equal(f.sends.length, 0);
  }
  for (const status of ['pending', 'suspended', 'rejected']) {
    const f = fixture({org: {...organization, status}});
    await f.sendOrganizationInviteEmail(f.event); assert.equal(f.sends.length, 0);
  }
});

test('SMTP rejection and unknown outcomes are visible and never blindly resent', async () => {
  for (const [code, status] of [['EAUTH', 'failed'], ['ETIMEDOUT', 'unknown']]) {
    const f = fixture({send: async () => {throw Object.assign(new Error('SECRET with PII'), {code});}});
    await f.sendOrganizationInviteEmail(f.event); await f.sendOrganizationInviteEmail(f.event);
    assert.equal(f.sends.length, 1);
    assert.equal(f.records.get('organizationInvites/invite/emailDelivery/status').status, status);
    assert.doesNotMatch(JSON.stringify(f.logs), /SECRET|member@example/);
  }
  const f = fixture({send: async () => ({accepted: [], rejected: [invite.email]})});
  await f.sendOrganizationInviteEmail(f.event);
  assert.equal(f.records.get('organizationInvites/invite/emailDelivery/status').status, 'failed');
});

test('new organization notifies only platform admins at enabled Auth account addresses', async () => {
  const f = fixture({org: {...organization, status: 'pending', email: 'applicant@example.ee'},
    users: {owner: {systemRole: 'platformOwner', email: 'spoof@example.ee'},
      platform: {systemRole: 'platformAdmin'}, disabled: {systemRole: 'platformAdmin'},
      unverified: {systemRole: 'platformAdmin'}, admin: {systemRole: 'user', role: 'orgAdmin'}},
    accounts: {owner: {email: 'owner@example.ee', emailVerified: true},
      platform: {email: 'platform@example.ee', emailVerified: true},
      disabled: {email: 'disabled@example.ee', disabled: true, emailVerified: true},
      unverified: {email: 'unverified@example.ee', emailVerified: false}},
  });
  await f.sendOrganizationApplicationEmail(f.orgEvent);
  await f.sendOrganizationApplicationEmail(f.orgEvent);
  assert.deepEqual(f.sends.map(m => m.to.address), ['owner@example.ee', 'platform@example.ee', 'unverified@example.ee']);
});

test('reviewed or replaced organization application is not emailed', async () => {
  for (const patch of [{status: 'approved'}, {createdAt: timestamp(101)}, {createdBy: 'other'}]) {
    const f = fixture({org: {...organization, status: 'pending'},
      users: {p: {systemRole: 'platformAdmin'}}, accounts: {p: {email: 'p@example.ee', emailVerified: true}}});
    f.records.set('commands/org', {...organization, status: 'pending', ...patch});
    await f.sendOrganizationApplicationEmail(f.orgEvent);
    assert.equal(f.sends.length, 0);
  }
});

test('SMTP enforces TLS and fixed account and disables remote/local attachment access', () => {
  let options;
  smtpTransport({createTransport: value => {options = value;}}, 'test-only');
  assert.equal(options.host, 'smtp.zone.eu');
  assert.equal(options.port, 587);
  assert.equal(options.requireTLS, true);
  assert.equal(options.tls.rejectUnauthorized, true);
  assert.equal(options.auth.user, SENDER);
  assert.equal(options.disableFileAccess, true);
  assert.equal(options.disableUrlAccess, true);
});
