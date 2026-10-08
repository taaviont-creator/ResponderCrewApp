const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  query,
  collection,
  where,
  limit,
  or,
  and,
  runTransaction,
  writeBatch,
  serverTimestamp,
  setDoc,
  updateDoc,
  deleteDoc,
} = require('firebase/firestore');

const projectId = 'demo-respondcrew';
const organizationId = 'approved-org';
const memberId = 'member-user';
const otherUserId = 'other-user';
const orgAdminId = 'org-admin';
const activeMemberId = 'active-member';
const targetMemberId = 'target-member';
const otherOrganizationId = 'other-org';
const membershipId = `${memberId}_${organizationId}`;

test('contribution workflow: own pending work, admin confirmation, separate scheduling and one statistics entry', async () => {
  const assert = require('node:assert/strict');
  const {createRecordContributionHandler,createStatisticsHandler}=serverRequire('./statistics-handlers');
  const db=serverDb(),now=()=>Date.parse('2026-10-07T12:00:00Z');
  const record=createRecordContributionHandler({db,now,timestamp:()=>new Date(now())});
  const data={organizationId,requestId:'workflow',title:'Paadi puhastamine',description:'Pesin teki',type:'maintenance',date:'2026-10-06',hours:2.5,memberIds:[activeMemberId]};
  await record({auth:{uid:activeMemberId},data});await record({auth:{uid:activeMemberId},data});
  const client=testEnv.authenticatedContext(activeMemberId).firestore(),admin=testEnv.authenticatedContext(orgAdminId).firestore();
  const activityPath='activities/contribution_workflow',participantPath=`activityParticipants/contribution_workflow_${activeMemberId}`;
  const activity=(await assertSucceeds(getDoc(doc(client,activityPath)))).data();
  assert.equal(activity.entryKind,'contribution');assert.equal(activity.description,'Pesin teki');
  await assertSucceeds(getDoc(doc(client,participantPath)));
  await assertSucceeds(getDocs(query(collection(admin,'activityParticipants'),where('organizationId','==',organizationId))));
  await assertFails(updateDoc(doc(client,participantPath),{attendanceStatus:'confirmed',confirmedBy:activeMemberId,confirmedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(client,participantPath),{status:'attending',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(admin,activityPath),{entryKind:'scheduled'}));
  await assertFails(getDoc(doc(testEnv.authenticatedContext(otherUserId).firestore(),activityPath)));
  await assert.rejects(record({auth:{uid:activeMemberId},data:{...data,requestId:'peer',memberIds:[targetMemberId]}}),{code:'permission-denied'});
  const stats=createStatisticsHandler({db,now}),request={auth:{uid:orgAdminId},data:{organizationId,from:'2026-10-06',to:'2026-10-07'}};
  const before=(await stats(request)).members.find(m=>m.userId===activeMemberId);assert.equal(before.contributionHours,0);assert.equal(before.pendingCount,1);
  await assertSucceeds(updateDoc(doc(admin,participantPath),{attendanceStatus:'confirmed',hours:2.5,confirmedBy:orgAdminId,confirmedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  const after=(await stats(request)).members.find(m=>m.userId===activeMemberId);assert.equal(after.contributionHours,2.5);assert.equal(after.entries.length,1);
  await db.doc(`commands/${organizationId}`).update({allowMembersToCreateActivities:true});
  for(const id of ['direct','contribution_direct']) await assertFails(setDoc(doc(client,'activities',id),{...activity,id,createdBy:activeMemberId,entryKind:id==='direct'?'contribution':'scheduled'}));
  await assertFails(setDoc(doc(client,'activityParticipants',`contribution_workflow_${targetMemberId}`),{id:`contribution_workflow_${targetMemberId}`,organizationId,commandId:organizationId,activityId:'contribution_workflow',userId:targetMemberId,status:'attendedSelfReported',createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});

let testEnv;
const serverRequire = require('node:module').createRequire(path.resolve(__dirname, '../functions/package.json'));
let serverApp;
function serverDb() {
  const {initializeApp} = serverRequire('firebase-admin/app');
  const {getFirestore} = serverRequire('firebase-admin/firestore');
  serverApp ||= initializeApp({projectId}, 'workflow-integration');
  return getFirestore(serverApp);
}
after(async () => { if (serverApp) await serverRequire('firebase-admin/app').deleteApp(serverApp); });

require('./center-dispatch.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./center-access.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./response-units.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./organization-map-location.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./geofence.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./organization-response-settings.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./center-board.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./center-confirmation.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./center-completion.cases')({getEnv: () => testEnv, serverDb, serverRequire});
require('./certificate-self-service.cases')({getEnv: () => testEnv, serverDb});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    storage: { rules: fs.readFileSync(path.resolve(__dirname, '..', 'storage.rules'), 'utf8') },
    firestore: {
      rules: fs.readFileSync(
        process.env.RULES_TEST_FILE || path.resolve(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();

    await updateDocOrCreate(
      firestore,
      `commands/${organizationId}`,
      {
        createdBy: 'org-admin',
        status: 'approved',
      },
    );

    await updateDocOrCreate(
      firestore,
      `memberships/${membershipId}`,
      removedMembership(),
    );

    await updateDocOrCreate(
      firestore,
      `memberships/${orgAdminId}_${organizationId}`,
      {
        userId: orgAdminId,
        organizationId,
        commandId: organizationId,
        role: 'orgAdmin',
        seaRescueLevel: 'level2',
        displayName: 'Org Admin',
        status: 'active',
        isActive: true,
        joinedAt: new Date('2026-01-01T00:00:00.000Z'),
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      },
    );

    for (const userId of [activeMemberId, targetMemberId]) {
      await updateDocOrCreate(
        firestore,
        `memberships/${userId}_${organizationId}`,
        activeMembership(userId, organizationId),
      );
    }

    await updateDocOrCreate(firestore, `users/${orgAdminId}`, {
      name: 'Org Admin',
      activeOrganizationId: organizationId,
      activeCommandId: organizationId,
      commandId: organizationId,
    });
    await updateDocOrCreate(firestore, `users/${targetMemberId}`, {
      name: 'Target Member',
    });
    await updateDocOrCreate(firestore, `users/${activeMemberId}`, {
      name: 'Active Member',
    });

    await updateDocOrCreate(
      firestore,
      `commands/${otherOrganizationId}`,
      {
        createdBy: 'other-admin',
        status: 'approved',
      },
    );

    await updateDocOrCreate(
      firestore,
      'equipment/other-org-equipment',
      {
        id: 'other-org-equipment',
        organizationId: otherOrganizationId,
        commandId: otherOrganizationId,
        scope: 'organization',
        name: 'Other org radio',
        category: 'radio',
        status: 'ok',
        location: '',
        note: '',
        createdBy: 'other-admin',
      },
    );

    await updateDocOrCreate(
      firestore,
      'equipment/target-personal-equipment',
      {
        id: 'target-personal-equipment',
        organizationId,
        commandId: organizationId,
        scope: 'personal',
        ownerUserId: targetMemberId,
        name: 'Target personal PFD',
        category: 'safety',
        status: 'ok',
        location: '',
        note: '',
        createdBy: targetMemberId,
      },
    );
  });
});

after(async () => {
  await testEnv.cleanup();
});

test('calendar editing and checkbox attendance keep admin and organization boundaries', async () => {
  const admin = testEnv.authenticatedContext(orgAdminId).firestore();
  const member = testEnv.authenticatedContext(activeMemberId).firestore();
  const activityId = 'calendar-training';
  const activity = {id:activityId, organizationId, commandId:organizationId,
    title:'Koolitus', description:'', type:'training', startTime:'2026-10-06T11:00:00Z',
    endTime:'2026-10-06T13:00:00Z', location:'Sadam', createdBy:orgAdminId,
    createdAt:serverTimestamp(), updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(admin,'activities',activityId),activity));
  await assertSucceeds(updateDoc(doc(admin,'activities',activityId),{startTime:'2026-10-07T11:00:00Z',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(member,'activities',activityId),{startTime:'2026-10-07T12:00:00Z',updatedAt:serverTimestamp()}));
  const lookup = db => query(collection(db,'activityParticipants'),where('organizationId','==',organizationId),
    where('activityId','==',activityId),where('userId','==',targetMemberId));
  await assertSucceeds(getDocs(lookup(admin)));
  await assertFails(getDocs(lookup(member)));
  await assertFails(getDocs(query(collection(admin,'activityParticipants'),where('organizationId','==',otherOrganizationId))));
  const id = `${activityId}_${targetMemberId}`;
  const attendance = {id,activityId,userId:targetMemberId,organizationId,commandId:organizationId,
    status:'notResponded',attendanceStatus:'confirmed',hours:2,confirmedBy:orgAdminId,
    confirmedAt:serverTimestamp(),createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(admin,'activityParticipants',id),attendance));
  await assertFails(updateDoc(doc(member,'activityParticipants',id),{attendanceStatus:'confirmed',confirmedBy:activeMemberId,confirmedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(admin,'activityParticipants',id),{attendanceStatus:'absent',hours:null,confirmedBy:orgAdminId,confirmedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});

test('removed member cannot reactivate without admin approval', async () => {
  const firestore = testEnv.authenticatedContext(memberId).firestore();

  await assertFails(
    updateDoc(
      doc(firestore, 'memberships', membershipId),
      reactivatedMembership(),
    ),
  );
});

function joinRequest(userId = 'new-member', orgId = organizationId) {
  return {
    ...activeMembership(userId, orgId),
    status: 'pending',
    isActive: false,
    joinedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

async function seedPendingRequest(userId = 'new-member') {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'memberships', `${userId}_${organizationId}`),
      joinRequest(userId));
  });
}

test('new member can read missing own membership and submit pending request', async () => {
  const firestore = testEnv.authenticatedContext('new-member').firestore();
  const ref = doc(firestore, 'memberships', `new-member_${organizationId}`);
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(setDoc(ref, joinRequest()));
  await assertSucceeds(getDoc(ref));
  await assertFails(getDoc(doc(firestore, 'equipment', 'target-personal-equipment')));
  await assertFails(getDocs(query(collection(firestore, 'memberships'),
    where('organizationId', '==', organizationId))));
  await assertFails(updateDoc(ref, {
    status: 'active', isActive: true, updatedAt: serverTimestamp(),
  }));
});

test('code lookup, request transaction and administrator approval work together', async () => {
  const uid = 'code-join-member';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await updateDoc(doc(db, 'commands', organizationId), { joinCode: 'ABC234' });
    await setDoc(doc(db, 'users', uid), { name: 'Test Member' });
  });
  const memberDb = testEnv.authenticatedContext(uid).firestore();
  const code = ' abc234 '.trim().toUpperCase();
  const organizations = await assertSucceeds(getDocs(query(
    collection(memberDb, 'commands'), where('joinCode', '==', code), limit(1),
  )));
  const orgId = organizations.docs[0].id;
  const memberRef = doc(memberDb, 'memberships', `${uid}_${orgId}`);
  await assertSucceeds(getDoc(doc(memberDb, 'users', uid)));
  await assertSucceeds(runTransaction(memberDb, async (transaction) => {
    const existing = await transaction.get(memberRef);
    if (existing.exists()) throw new Error('Expected a new membership');
    transaction.set(memberRef, joinRequest(uid, orgId), { merge: true });
  }));
  await assertFails(updateDoc(memberRef, {
    status: 'active', isActive: true, updatedAt: serverTimestamp(),
  }));
  const adminDb = testEnv.authenticatedContext(orgAdminId).firestore();
  const requests = await assertSucceeds(getDocs(query(collection(adminDb, 'memberships'),
    or(where('organizationId', '==', orgId), where('commandId', '==', orgId)),
  )));
  if (!requests.docs.some(d => d.id === memberRef.id && d.data().status === 'pending')) {
    throw new Error('Administrator must see the pending request');
  }
  await assertSucceeds(updateDoc(doc(adminDb, 'memberships', memberRef.id), {
    status: 'active', isActive: true, updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDocs(query(collection(memberDb, 'memberships'),
    where('organizationId', '==', orgId))));
});

test('old app immediate-activation batch remains denied by approval rules', async () => {
  const uid = 'old-app-member';
  const db = testEnv.authenticatedContext(uid).firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'memberships', `${uid}_${organizationId}`), {
    ...joinRequest(uid), status: 'active', isActive: true,
  }, { merge: true });
  batch.set(doc(db, 'users', uid), {
    activeOrganizationId: organizationId, activeCommandId: organizationId,
    commandId: organizationId,
  }, { merge: true });
  await assertFails(batch.commit());
});

for (const [name, overrides] of Object.entries({
  active: { status: 'active', isActive: true },
  contradictory: { isActive: true },
  admin: { role: 'orgAdmin' },
  level: { seaRescueLevel: 'level2' },
  owner: { userId: otherUserId },
  organization: { commandId: otherOrganizationId },
  timestamp: { joinedAt: new Date('2000-01-01') },
  oversizedName: { displayName: 'x'.repeat(81) },
  extraField: { systemRole: 'platformAdmin' },
  missingTimestamp: { updatedAt: null },
})) {
  test(`join request rejects invalid ${name}`, async () => {
    const firestore = testEnv.authenticatedContext('new-member').firestore();
    await assertFails(setDoc(doc(firestore, 'memberships', `new-member_${organizationId}`),
      { ...joinRequest(), ...overrides }));
  });
}

test('join request rejects wrong document id and unapproved or missing organization', async () => {
  const firestore = testEnv.authenticatedContext('new-member').firestore();
  await assertFails(setDoc(doc(firestore, 'memberships', 'wrong-id'), joinRequest()));
  await assertFails(setDoc(doc(firestore, 'memberships', 'new-member_missing'),
    joinRequest('new-member', 'missing')));
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'commands', organizationId), { status: 'pending' });
  });
  await assertFails(setDoc(doc(firestore, 'memberships', `new-member_${organizationId}`), joinRequest()));
});

test('removed member can request rejoin but has no access until approved', async () => {
  const firestore = testEnv.authenticatedContext(memberId).firestore();
  await assertSucceeds(updateDoc(doc(firestore, 'memberships', membershipId), {
    ...reactivatedMembership(), status: 'pending', isActive: false,
  }));
  await assertFails(getDocs(query(collection(firestore, 'memberships'),
    where('organizationId', '==', organizationId))));
});

test('pending request cannot switch active organization before approval', async () => {
  const firestore = testEnv.authenticatedContext('new-member').firestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', 'new-member'), { systemRole: 'user' });
  });
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'memberships', `new-member_${organizationId}`), joinRequest());
  batch.update(doc(firestore, 'users', 'new-member'), {
    activeOrganizationId: organizationId, activeCommandId: organizationId, commandId: organizationId,
  });
  await assertFails(batch.commit());
});

for (const approve of [true, false]) {
  test(`org admin can ${approve ? 'approve' : 'reject'} a pending member`, async () => {
    await seedPendingRequest();
    const firestore = testEnv.authenticatedContext(orgAdminId).firestore();
    await assertSucceeds(getDocs(query(collection(firestore, 'memberships'),
      where('organizationId', '==', organizationId))));
    const ref = doc(firestore, 'memberships', `new-member_${organizationId}`);
    await assertSucceeds(updateDoc(ref, {
      status: approve ? 'active' : 'rejected', isActive: approve,
      updatedAt: serverTimestamp(),
    }));
    const memberDb = testEnv.authenticatedContext('new-member').firestore();
    const readMembers = getDocs(query(collection(memberDb, 'memberships'),
      where('organizationId', '==', organizationId)));
    await (approve ? assertSucceeds(readMembers) : assertFails(readMembers));
    if (!approve) {
      await assertFails(updateDoc(ref, {
        status: 'active', isActive: true, updatedAt: serverTimestamp(),
      }));
    }
  });
}

test('request cannot be approved by self, ordinary member, outsider or other org admin', async () => {
  await seedPendingRequest();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'memberships', `other-admin_${otherOrganizationId}`), {
      ...activeMembership('other-admin', otherOrganizationId), role: 'orgAdmin',
    });
  });
  for (const uid of ['new-member', activeMemberId, otherUserId, 'other-admin']) {
    const firestore = testEnv.authenticatedContext(uid).firestore();
    await assertFails(updateDoc(doc(firestore, 'memberships', `new-member_${organizationId}`), {
      status: 'active', isActive: true, updatedAt: serverTimestamp(),
    }));
  }
});

test('approval cannot also alter identity, role, qualification or protected fields', async () => {
  await seedPendingRequest();
  const firestore = testEnv.authenticatedContext(orgAdminId).firestore();
  for (const overrides of [
    { userId: otherUserId }, { role: 'orgAdmin' }, { seaRescueLevel: 'level2' },
    { organizationId: otherOrganizationId, commandId: otherOrganizationId },
    { joinedAt: serverTimestamp() }, { displayName: 'Changed' }, { unexpected: true },
    { isActive: false }, { updatedAt: null },
  ]) {
    await assertFails(updateDoc(doc(firestore, 'memberships', `new-member_${organizationId}`), {
      status: 'active', isActive: true, updatedAt: serverTimestamp(), ...overrides,
    }));
  }
});

test('unauthenticated and other users cannot submit or inspect someone else request', async () => {
  const anonymous = testEnv.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(anonymous, 'memberships', `new-member_${organizationId}`), joinRequest()));
  const outsider = testEnv.authenticatedContext(otherUserId).firestore();
  await assertFails(getDoc(doc(outsider, 'memberships', `new-member_${organizationId}`)));
  await seedPendingRequest();
  await assertFails(getDoc(doc(outsider, 'memberships', `new-member_${organizationId}`)));
});

for (const previousStatus of ['missing', 'pending', 'removed']) {
test(`admin-issued email invite approves its recipient with ${previousStatus} membership`, async () => {
  const uid = 'invited-member';
  const email = 'member@example.test';
  const adminDb = testEnv.authenticatedContext(orgAdminId).firestore();
  await assertSucceeds(setDoc(doc(adminDb, 'organizationInvites', 'admin-invite'), {
    organizationId, commandId: organizationId, email, role: 'member',
    status: 'pending', invitedBy: orgAdminId, createdAt: serverTimestamp(),
    expiresAt: new Date(Date.now() + 86400000), acceptedBy: null, acceptedAt: null,
  }));
  const memberDb = testEnv.authenticatedContext(uid, { email }).firestore();
  if (previousStatus !== 'missing') {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'memberships', `${uid}_${organizationId}`), {
        ...joinRequest(uid), status: previousStatus,
      });
    });
  }
  await assertSucceeds(getDoc(doc(memberDb, 'memberships', `${uid}_${organizationId}`)));
  const batch = writeBatch(memberDb);
  batch.update(doc(memberDb, 'organizationInvites', 'admin-invite'), {
    status: 'accepted', acceptedBy: uid, acceptedAt: serverTimestamp(),
  });
  batch.set(doc(memberDb, 'memberships', `${uid}_${organizationId}`), {
    ...joinRequest(uid), status: 'active', isActive: true, acceptedInviteId: 'admin-invite',
  });
  await assertSucceeds(batch.commit());
});
}

test('fake invite cannot bypass join approval', async () => {
  const firestore = testEnv.authenticatedContext('new-member', { email: 'new@example.test' }).firestore();
  await assertFails(setDoc(doc(firestore, 'memberships', `new-member_${organizationId}`), {
    ...joinRequest(), status: 'active', isActive: true, acceptedInviteId: 'does-not-exist',
  }));
});

test('email delivery status is server-owned and visible only to this organization admin', async () => {
  const adminDb = testEnv.authenticatedContext(orgAdminId).firestore();
  const inviteRef = doc(adminDb, 'organizationInvites', 'email-invite');
  await assertSucceeds(setDoc(inviteRef, {
    organizationId, commandId: organizationId, email: 'invitee@example.test', role: 'member',
    status: 'pending', invitedBy: orgAdminId, createdAt: serverTimestamp(),
    expiresAt: new Date(Date.now() + 86400000), acceptedBy: null, acceptedAt: null,
  }));
  const deliveryPath = 'organizationInvites/email-invite/emailDelivery/status';
  await assertSucceeds(getDoc(doc(adminDb, deliveryPath))); // Absent status must also be readable.
  await assertFails(setDoc(doc(adminDb, deliveryPath), {status: 'accepted'}));
  const backend = serverDb();
  await backend.doc(deliveryPath).set({status: 'accepted'});
  await backend.doc('users/platform-only').set({systemRole: 'platformAdmin'});
  await assertSucceeds(getDoc(doc(adminDb, deliveryPath)));
  for (const uid of [activeMemberId, otherUserId, 'platform-only', 'invitee']) {
    const client = testEnv.authenticatedContext(uid, {email: 'invitee@example.test'}).firestore();
    await assertFails(getDoc(doc(client, deliveryPath)));
    await assertFails(setDoc(doc(client, deliveryPath), {status: 'sending'}));
  }
  await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), deliveryPath)));
  await assertFails(updateDoc(doc(adminDb, deliveryPath), {status: 'failed'}));
  await assertFails(deleteDoc(doc(adminDb, deliveryPath)));
  await assertFails(getDocs(collection(adminDb, 'organizationApplicationEmailDeliveries')));
});

test('mail handler integration keeps invitation usable and writes delivery state only once', async () => {
  const {createEmailHandlers} = serverRequire('./transactional-email');
  const backend = serverDb();
  const ref = backend.doc('organizationInvites/handler-invite');
  await ref.set({organizationId, commandId: organizationId, email: 'invitee@example.test',
    role: 'member', status: 'pending', invitedBy: orgAdminId,
    createdAt: new Date(), expiresAt: new Date(Date.now() + 86400000)});
  const sent = [];
  const handler = createEmailHandlers({db: backend, auth: {},
    logger: {info() {}, error() {}}, sendMail: async message => {
      sent.push(message); return {accepted: [message.to.address]};
    },
  }).sendOrganizationInviteEmail;
  const event = {params: {inviteId: 'handler-invite'}, data: await ref.get()};
  await Promise.all([handler(event), handler(event)]);
  const assert = require('node:assert/strict');
  assert.equal(sent.length, 1);
  assert.equal((await ref.get()).data().status, 'pending');
  assert.equal((await ref.collection('emailDelivery').doc('status').get()).data().status, 'accepted');
});

test('another user cannot reactivate a removed membership', async () => {
  const firestore = testEnv.authenticatedContext(otherUserId).firestore();

  await assertFails(
    updateDoc(
      doc(firestore, 'memberships', membershipId),
      reactivatedMembership(),
    ),
  );
});

test('rejected membership cannot use the removed-member reactivation path', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'memberships', membershipId),
      {
        status: 'rejected',
        isActive: false,
      },
    );
  });

  const firestore = testEnv.authenticatedContext(memberId).firestore();

  await assertFails(
    updateDoc(
      doc(firestore, 'memberships', membershipId),
      reactivatedMembership(),
    ),
  );
});

test('ordinary member cannot change another member role or sea rescue level', async () => {
  const firestore = testEnv.authenticatedContext(activeMemberId).firestore();
  const targetRef = doc(
    firestore,
    'memberships',
    `${targetMemberId}_${organizationId}`,
  );

  await assertFails(
    updateDoc(targetRef, {
      role: 'orgAdmin',
      updatedAt: serverTimestamp(),
    }),
  );

  await assertFails(
    updateDoc(targetRef, {
      seaRescueLevel: 'level2',
      updatedAt: serverTimestamp(),
    }),
  );

  await assertFails(
    updateDoc(targetRef, {
      membershipStartedAt: new Date('2015-01-01T00:00:00.000Z'),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('org admin can change own sea rescue level but not own role', async () => {
  const firestore = testEnv.authenticatedContext(orgAdminId).firestore();
  const ownMembershipRef = doc(
    firestore,
    'memberships',
    `${orgAdminId}_${organizationId}`,
  );

  await assertSucceeds(
    updateDoc(ownMembershipRef, {
      seaRescueLevel: 'level1',
      updatedAt: serverTimestamp(),
    }),
  );

  await assertFails(
    updateDoc(ownMembershipRef, {
      role: 'member',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('member and org admin can set membership start date within their scope', async () => {
  const selfDb = testEnv.authenticatedContext(activeMemberId).firestore();
  const ownRef = doc(
    selfDb,
    'memberships',
    `${activeMemberId}_${organizationId}`,
  );
  await assertSucceeds(updateDoc(ownRef, {
    membershipStartedAt: new Date('2018-05-12T00:00:00.000Z'),
    updatedAt: serverTimestamp(),
  }));

  const adminDb = testEnv.authenticatedContext(orgAdminId).firestore();
  const targetRef = doc(
    adminDb,
    'memberships',
    `${targetMemberId}_${organizationId}`,
  );
  await assertSucceeds(updateDoc(targetRef, {
    membershipStartedAt: new Date('2012-03-04T00:00:00.000Z'),
    updatedAt: serverTimestamp(),
  }));

  await assertFails(updateDoc(ownRef, {
    membershipStartedAt: new Date('2100-01-01T00:00:00.000Z'),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(targetRef, {
    joinedAt: new Date('2012-03-04T00:00:00.000Z'),
    updatedAt: serverTimestamp(),
  }));
});

test('only the same organization admin can update a member phone', async () => {
  const adminDb = testEnv.authenticatedContext(orgAdminId).firestore();
  const targetRef = doc(adminDb, 'users', targetMemberId);
  await assertSucceeds(updateDoc(targetRef, {
    phone: '+372 555 1234',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(targetRef, {
    name: 'Changed by admin',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(targetRef, {
    phone: '1'.repeat(41),
    updatedAt: serverTimestamp(),
  }));

  const memberDb = testEnv.authenticatedContext(activeMemberId).firestore();
  await assertFails(updateDoc(doc(memberDb, 'users', targetMemberId), {
    phone: '+372 555 9999',
    updatedAt: serverTimestamp(),
  }));
});

test('ordinary member can create own personal equipment but not organization equipment', async () => {
  const firestore = testEnv.authenticatedContext(activeMemberId).firestore();

  await assertSucceeds(
    setDoc(doc(firestore, 'equipment', 'member-personal-equipment'), {
      id: 'member-personal-equipment',
      organizationId,
      commandId: organizationId,
      scope: 'personal',
      ownerUserId: activeMemberId,
      name: 'My PFD',
      category: 'safety',
      status: 'ok',
      location: '',
      note: '',
      createdBy: activeMemberId,
    }),
  );

  await assertFails(
    setDoc(doc(firestore, 'equipment', 'member-org-equipment'), {
      id: 'member-org-equipment',
      organizationId,
      commandId: organizationId,
      scope: 'organization',
      name: 'Organization radio',
      category: 'radio',
      status: 'ok',
      location: '',
      note: '',
      createdBy: activeMemberId,
    }),
  );
});

test('ordinary member cannot read another member personal equipment', async () => {
  const firestore = testEnv.authenticatedContext(activeMemberId).firestore();

  await assertFails(
    getDoc(doc(firestore, 'equipment', 'target-personal-equipment')),
  );
});

test('ordinary member cannot read equipment from another organization', async () => {
  const firestore = testEnv.authenticatedContext(activeMemberId).firestore();

  await assertFails(
    getDoc(doc(firestore, 'equipment', 'other-org-equipment')),
  );
});

test('org admin can create readiness settings with neutral compatibility fields', async () => {
  const firestore = testEnv.authenticatedContext(orgAdminId).firestore();

  await assertSucceeds(
    setDoc(doc(firestore, 'organizationReadinessSummaries', organizationId), {
      id: organizationId,
      organizationId,
      commandId: organizationId,
      organizationName: 'Approved Org',
      region: '',
      contactName: '',
      contactPhone: '',
      readinessStatus: 'unknown',
      onDutyCount: 0,
      delayedCount: 0,
      minimumCrewRequired: 3,
      minimumCrewMet: false,
      primaryVesselStatus: 'unknown',
      equipmentStatus: 'unknown',
      criticalIssues: '',
      lastUpdatedBy: orgAdminId,
      lastUpdatedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdAt: serverTimestamp(),
    }),
  );
});

test('operation log can progress from open to enRoute', async () => {
  const logId = 'log-forward';
  await seedOperationLog(logId, 'open');

  const firestore = testEnv.authenticatedContext(orgAdminId).firestore();
  await assertSucceeds(
    updateDoc(doc(firestore, 'operationLogs', logId), {
      status: 'enRoute',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('completed operation log can move only to returnedToBase', async () => {
  const logId = 'log-returned';
  await seedOperationLog(logId, 'completed');

  const firestore = testEnv.authenticatedContext(orgAdminId).firestore();
  await assertSucceeds(
    updateDoc(doc(firestore, 'operationLogs', logId), {
      status: 'returnedToBase',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('completed operation log cannot be reopened', async () => {
  const logId = 'log-reopen';
  await seedOperationLog(logId, 'completed');

  const firestore = testEnv.authenticatedContext(orgAdminId).firestore();
  await assertFails(
    updateDoc(doc(firestore, 'operationLogs', logId), {
      status: 'open',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('operation log cannot move backwards from onScene to enRoute', async () => {
  const logId = 'log-backwards';
  await seedOperationLog(logId, 'onScene');

  const firestore = testEnv.authenticatedContext(orgAdminId).firestore();
  await assertFails(
    updateDoc(doc(firestore, 'operationLogs', logId), {
      status: 'enRoute',
      updatedAt: serverTimestamp(),
    }),
  );
});

async function seedOperationLog(logId, status) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDocOrCreate(
      context.firestore(),
      `operationLogs/${logId}`,
      {
        id: logId,
        organizationId,
        commandId: organizationId,
        createdBy: orgAdminId,
        createdByName: 'Org Admin',
        type: 'note',
        title: 'Test log',
        description: '',
        status,
        timestamp: new Date('2026-01-01T00:00:00.000Z'),
        createdAt: new Date('2026-01-01T00:00:00.000Z'),
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      },
    );
  });
}

function activeMembership(userId, orgId) {
  return {
    userId,
    organizationId: orgId,
    commandId: orgId,
    role: 'member',
    seaRescueLevel: 'none',
    displayName: userId,
    status: 'active',
    isActive: true,
    joinedAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  };
}

function removedMembership() {
  return {
    userId: memberId,
    organizationId,
    commandId: organizationId,
    role: 'member',
    seaRescueLevel: 'none',
    displayName: 'Test Member',
    status: 'removed',
    isActive: false,
    joinedAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  };
}

function reactivatedMembership() {
  return {
    organizationId,
    commandId: organizationId,
    role: 'member',
    seaRescueLevel: 'none',
    displayName: 'Test Member',
    status: 'active',
    isActive: true,
    joinedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

async function updateDocOrCreate(firestore, documentPath, data) {
  await setDoc(doc(firestore, documentPath), data);
}

test('operation timeline requires organization-scoped query and persists after completion', async () => {
  const logId = 'timeline-regression';
  await seedOperationLog(logId, 'open');
  const db = testEnv.authenticatedContext(orgAdminId).firestore();
  const logRef = doc(db, 'operationLogs', logId);
  const eventRef = doc(db, 'operationLogs', logId, 'events', 'departure');
  const batch = writeBatch(db);
  batch.update(logRef, {status: 'enRoute', updatedAt: serverTimestamp()});
  batch.set(eventRef, {id: 'departure', operationLogId: logId, organizationId,
    commandId: organizationId, type: 'statusChange', status: 'enRoute',
    title: 'Teel', description: '', createdBy: orgAdminId,
    latitude: 59.45, longitude: 24.75, accuracyMeters: 8, createdAt: serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(getDocs(collection(db, 'operationLogs', logId, 'events')));
  const timeline = query(collection(db, 'operationLogs', logId, 'events'), or(
    where('organizationId', '==', organizationId), where('commandId', '==', organizationId)));
  let saved = await assertSucceeds(getDocs(timeline));
  if (saved.size !== 1 || saved.docs[0].data().latitude !== 59.45 || !saved.docs[0].data().createdAt) {
    throw new Error('Timeline did not preserve time and location');
  }
  await updateDoc(logRef, {status: 'completed', updatedAt: serverTimestamp()});
  await updateDoc(logRef, {status: 'returnedToBase', updatedAt: serverTimestamp()});
  saved = await assertSucceeds(getDocs(timeline));
  if (saved.size !== 1) throw new Error('Completed log lost its events');
  const outsider = testEnv.authenticatedContext(otherUserId).firestore();
  await assertFails(getDocs(query(collection(outsider, 'operationLogs', logId, 'events'),
    where('organizationId', '==', organizationId))));
});

test('final summary and audit event can be saved after returning to base', async () => {
  const logId = 'summary-after-return';
  await seedOperationLog(logId, 'returnedToBase');
  const db = testEnv.authenticatedContext(orgAdminId).firestore();
  const batch = writeBatch(db);
  batch.update(doc(db, 'operationLogs', logId), {summary: 'Sündmuse kirjeldus', outcome: 'Kõik baasis',
    completedBy: orgAdminId, completedAt: serverTimestamp(), updatedAt: serverTimestamp()});
  batch.set(doc(db, 'operationLogs', logId, 'events', 'summary'), {
    id: 'summary', operationLogId: logId, organizationId, commandId: organizationId,
    type: 'summarySaved', status: 'returnedToBase', title: 'Lõppkokkuvõte salvestatud',
    description: 'Kõik baasis', createdBy: orgAdminId, createdAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  const saved = await getDoc(doc(db, 'operationLogs', logId));
  if (saved.data().status !== 'returnedToBase' || saved.data().summary !== 'Sündmuse kirjeldus') {
    throw new Error('Final summary changed operational status or was not saved');
  }
});

test('summary edits remain forbidden for active operations and unauthorized users', async () => {
  for (const [status, user] of [['open', orgAdminId], ['returnedToBase', activeMemberId], ['returnedToBase', otherUserId]]) {
    const logId = `summary-denied-${status}-${user}`;
    await seedOperationLog(logId, status);
    const db = testEnv.authenticatedContext(user).firestore();
    await assertFails(updateDoc(doc(db, 'operationLogs', logId), {
      summary: 'Not allowed', outcome: 'Not allowed', completedBy: user,
      completedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
  }
});

function calloutData(id, extra = {}) {
  return { id, organizationId, commandId: organizationId, title: 'SAR title does not define type',
    description: '', location: '', status: 'active', priority: 'normal',
    createdBy: orgAdminId, createdByName: 'Admin', createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(), closedAt: null, ...extra };
}

test('last admin cannot bypass client rules and concurrent server removals retain one admin', async () => {
  const db = serverDb();
  await db.doc(`memberships/${activeMemberId}_${organizationId}`).update({role:'orgAdmin'});
  const client = testEnv.authenticatedContext(orgAdminId).firestore();
  await assertFails(updateDoc(doc(client, 'memberships', `${orgAdminId}_${organizationId}`), {status:'removed',isActive:false,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(client, 'memberships', `${activeMemberId}_${organizationId}`), {role:'member',updatedAt:serverTimestamp()}));
  const {createMembershipManagementHandler} = require('../functions/organization-management');
  const {FieldValue} = serverRequire('firebase-admin/firestore');
  const handler=createMembershipManagementHandler({db,timestamp:()=>FieldValue.serverTimestamp()});
  const results=await Promise.allSettled([orgAdminId,activeMemberId].map(uid=>handler({auth:{uid},data:{organizationId,userId:uid,action:'remove'}})));
  const assert=require('node:assert/strict');
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.match(results.find(r=>r.status==='rejected').reason.message,/ainus administraator/);
  const members=await db.collection('memberships').where('organizationId','==',organizationId).get();
  assert.equal(members.docs.filter(m=>m.data().role==='orgAdmin'&&m.data().status==='active').length,1);
});

test('report reuses log and attendance, restricts private persons, rejects stale edits and platform-only role', async () => {
  const db=serverDb(), assert=require('node:assert/strict');
  const {FieldValue}=serverRequire('firebase-admin/firestore');
  const {createSaveReportHandler,createGetReportHandler}=require('../functions/callout-report');
  const save=createSaveReportHandler({db,timestamp:()=>FieldValue.serverTimestamp()}),read=createGetReportHandler({db});
  await seedOperationLog('report-log','onScene');
  await db.doc('operationLogs/report-log').update({calloutId:'report-callout'});
  await db.doc('callouts/report-callout').set({organizationId,commandId:organizationId,status:'active',title:'Pääste',createdAt:new Date('2026-09-01T10:00:00Z')});
  await db.doc(`commands/${organizationId}`).update({allowMembersToStartOperationLog:true});
  const data={organizationId,calloutId:'report-callout',operationLogId:'report-log',revision:0,expectedSummary:'',expectedOutcome:'',authorUserId:orgAdminId,leaderUserId:'',equipmentIds:[],status:'draft',summary:'Lühikokkuvõte',outcome:'Abi osutatud',suggestions:'Õppuse vajadus',persons:[{name:'Abivajaja',contact:'5555555',identifier:'TEST',role:'Abivajaja',notes:''}]};
  const req=(uid,d=data)=>({auth:{uid},data:d});
  await assert.rejects(save(req(activeMemberId)),{code:'permission-denied'});
  await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
  await assert.rejects(save(req('platform-only')),{code:'permission-denied'});
  await save(req(orgAdminId));
  assert.equal((await db.doc('operationLogs/report-log').get()).data().summary,data.summary);
  data.expectedSummary=data.summary;data.expectedOutcome=data.outcome;
  const report=(await db.doc('calloutReports/report-callout').get()).data();
  assert.equal(report.summary,undefined);assert.equal(report.reportLog,undefined);
  const memberReport=await read(req(activeMemberId));
  assert.equal(memberReport.summary,data.summary);assert.equal(memberReport.canEdit,false);assert.equal(Object.hasOwn(memberReport,'persons'),false);
  const adminReport=await read(req(orgAdminId));assert.equal(adminReport.persons[0].identifier,'TEST');
  await assert.rejects(save(req(orgAdminId)),{code:'aborted'});
  await assert.rejects(save(req(orgAdminId,{...data,revision:1,status:'completed'})),{code:'failed-precondition'});
  await db.doc('callouts/report-callout').update({status:'closed',closedAt:new Date('2026-09-01T12:00:00Z')});
  await save(req(orgAdminId,{...data,revision:1,status:'completed'}));
  assert.equal((await db.collection('callouts/report-callout/reportHistory').get()).size,2);
  const memberClient=testEnv.authenticatedContext(activeMemberId).firestore();
  await assertSucceeds(getDoc(doc(memberClient,'calloutReports','report-callout')));
  await assertFails(getDoc(doc(memberClient,'calloutPrivate','report-callout')));
  await assertFails(updateDoc(doc(memberClient,'operationLogs','report-log'),{summary:'Bypass',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(memberClient,'calloutReports','report-callout'),{status:'draft'}));
  await db.doc(`memberships/${activeMemberId}_${organizationId}`).update({seaRescueLevel:'level2'});
  await save(req(activeMemberId,{...data,revision:2,status:'completed',summary:'Juhi parandus'}));
  assert.equal((await read(req(activeMemberId))).summary,'Juhi parandus');
});

test('report technique selection and equipment incidents preserve history and enforce membership', async () => {
  const db=serverDb(), assert=require('node:assert/strict');
  const {FieldValue}=serverRequire('firebase-admin/firestore');
  const {createSaveReportHandler,createGetReportHandler}=require('../functions/callout-report');
  const save=createSaveReportHandler({db,timestamp:()=>FieldValue.serverTimestamp()}),read=createGetReportHandler({db});
  await seedOperationLog('gear-log','returnedToBase');
  await db.doc('operationLogs/gear-log').update({calloutId:'gear-callout'});
  await db.doc('callouts/gear-callout').set({organizationId,status:'closed',title:'Varustuse katse'});
  for (const [name,category,org] of [['boat','vessel',organizationId],['suit','safety',organizationId],['radio','radio',organizationId],['legacy','',organizationId],['foreign','vessel','another-org']]) {
    await db.doc(`equipment/${name}`).set({organizationId:org,name,category,scope:'organization'});
  }
  const data={organizationId,calloutId:'gear-callout',operationLogId:'gear-log',revision:0,expectedSummary:'',expectedOutcome:'',authorUserId:orgAdminId,leaderUserId:'',equipmentIds:['boat'],status:'completed',summary:'',outcome:'',suggestions:'',persons:[],equipmentIncidents:[{name:'Raadiojaam',status:'lost',description:'Kukkus üle parda.'}]};
  const req=(uid,d=data)=>({auth:{uid},data:d});
  const choices=(await read(req(orgAdminId))).equipment.map(e=>e.id);
  assert(choices.includes('boat'));assert(!choices.includes('suit'));assert(!choices.includes('radio'));assert(!choices.includes('foreign'));assert(!choices.includes('legacy'));
  for(const equipmentIds of [['suit'],['radio'],['foreign'],['legacy']]) await assert.rejects(save(req(orgAdminId,{...data,equipmentIds})),{code:'invalid-argument'});
  await assert.rejects(save(req(activeMemberId)),{code:'permission-denied'});
  await assert.rejects(save(req(orgAdminId,{...data,equipmentIncidents:[{name:'',status:'lost',description:'x'}]})),{code:'invalid-argument'});
  await assert.rejects(save(req(orgAdminId,{...data,equipmentIncidents:[{name:'x',status:'ok',description:'x'}]})),{code:'invalid-argument'});
  await save(req(orgAdminId));
  assert.deepEqual((await read(req(activeMemberId))).report.equipmentIncidents,data.equipmentIncidents);
  assert.equal((await db.doc('equipment/radio').get()).data().status,undefined);
  // An older client that knows nothing about incident records cannot erase them.
  const {equipmentIncidents:ignored,...older}=data;
  await save(req(orgAdminId,{...older,revision:1}));
  assert.deepEqual((await read(req(orgAdminId))).report.equipmentIncidents,data.equipmentIncidents);
  // Previously linked non-technical equipment remains readable/removable, never silently lost.
  await db.doc('calloutReports/gear-callout').update({equipmentIds:['boat','suit']});
  assert((await read(req(orgAdminId))).equipment.some(e=>e.id==='suit'));
  await save(req(orgAdminId,{...data,revision:2,equipmentIds:['boat','suit'],equipmentIncidents:[{name:'Raadiojaam',status:'damaged',description:'Leitud; korpus purunenud.'}]}));
  const history=await db.collection('callouts/gear-callout/reportHistory').get();
  assert.equal(history.size,3);
  assert(history.docs.some(d=>d.data().after.equipmentIncidents[0].status==='damaged'));
  const audit=await db.collection('platformAudit').where('targetId','==','gear-callout').get();
  assert(audit.docs.some(d=>d.data().changedFields.includes('equipmentIncidents')));
  // Removing active inventory must not erase equipment from old reports or
  // prevent their subsequent correction. An archive is not a new selection.
  const manage=serverRequire('./equipment-lifecycle').createEquipmentLifecycle({db,timestamp:()=>FieldValue.serverTimestamp()});
  await manage({auth:{uid:orgAdminId},data:{organizationId,action:'delete',id:'boat'}});
  assert((await read(req(activeMemberId))).equipment.some(e=>e.id==='boat'));
  await save(req(orgAdminId,{...data,revision:3,equipmentIds:['boat','suit']}));
  await db.doc('calloutReports/gear-callout').update({equipmentIds:[]});
  assert(!(await read(req(orgAdminId))).equipment.some(e=>e.id==='boat'));
  await assert.rejects(save(req(orgAdminId,{...data,revision:4})),{code:'invalid-argument'});
  await assertFails(updateDoc(doc(testEnv.authenticatedContext(activeMemberId).firestore(),'calloutReports','gear-callout'),{equipmentIncidents:[]}));
});

test('organization duty pause is admin-only, persistent, idempotent and cannot be forged by client', async () => {
  const db=serverDb(),assert=require('node:assert/strict');
  const {FieldValue}=serverRequire('firebase-admin/firestore');
  const {createDutyHandler}=require('../functions/organization-management');
  const handler=createDutyHandler({db,timestamp:()=>FieldValue.serverTimestamp()});
  const request=(uid,paused)=>({auth:{uid},data:{organizationId,paused,reason:'Hooaeg lõppenud'}});
  await assert.rejects(handler(request(activeMemberId,true)),{code:'permission-denied'});
  await handler(request(orgAdminId,true));await handler(request(orgAdminId,true));
  let pauses=await db.collection('organizationDutyPauses').where('organizationId','==',organizationId).get();
  assert.equal(pauses.size,1);assert.equal(pauses.docs[0].data().endAt,null);
  const client=testEnv.authenticatedContext(orgAdminId).firestore();
  await assertFails(updateDoc(doc(client,'commands',organizationId),{dutyPaused:false}));
  await handler(request(orgAdminId,false));
  pauses=await db.collection('organizationDutyPauses').where('organizationId','==',organizationId).get();
  assert.ok(pauses.docs[0].data().endAt.toMillis()>=pauses.docs[0].data().startAt.toMillis());
  assert.equal((await db.doc(`commands/${organizationId}`).get()).data().dutyPaused,false);
});

test('closed callout permits admin summary amendments with audit even when log milestones are incomplete', async () => {
  const id = 'closed-incomplete-log', calloutId = 'closed-summary-callout';
  await seedOperationLog(id, 'enRoute');
  await testEnv.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await updateDoc(doc(db, 'memberships', `${orgAdminId}_${organizationId}`), {seaRescueLevel: 'none'});
    await setDoc(doc(db, 'callouts', calloutId), calloutData(calloutId, {status: 'closed'}));
    await updateDoc(doc(db, 'operationLogs', id), {calloutId});
  });
  const db = testEnv.authenticatedContext(orgAdminId).firestore();
  for (const summary of ['Esimene kokkuvõte', 'Täiendatud kokkuvõte']) {
    const batch = writeBatch(db), event = doc(collection(db, 'operationLogs', id, 'events'));
    batch.update(doc(db, 'operationLogs', id), {summary, outcome: 'Kõik baasis',
      completedBy: orgAdminId, completedAt: serverTimestamp(), updatedAt: serverTimestamp()});
    batch.set(event, {id: event.id, operationLogId: id, organizationId, commandId: organizationId,
      type: 'summarySaved', status: 'enRoute', title: 'Lõppkokkuvõte salvestatud',
      description: 'Kõik baasis', summarySnapshot: summary, createdBy: orgAdminId, createdAt: serverTimestamp()});
    await assertSucceeds(batch.commit());
  }
  const saved = (await getDoc(doc(db, 'operationLogs', id))).data();
  require('node:assert/strict').equal(saved.status, 'enRoute');
  require('node:assert/strict').equal(saved.summary, 'Täiendatud kokkuvõte');
  const comment = doc(collection(db, 'operationLogs', id, 'events'));
  await assertSucceeds(setDoc(comment, {id: comment.id, operationLogId: id, organizationId, commandId: organizationId,
    type: 'manualNote', status: 'enRoute', title: 'Tagantjärele täiendus', text: 'Tagantjärele täiendus', description: '',
    occurredAt: new Date('2026-01-01T10:00:00Z'), createdBy: orgAdminId, createdAt: serverTimestamp()}));
  await testEnv.withSecurityRulesDisabled(async ctx => {
    await updateDoc(doc(ctx.firestore(), 'memberships', `${activeMemberId}_${organizationId}`), {seaRescueLevel: 'level2'});
  });
  const leaderDb = testEnv.authenticatedContext(activeMemberId).firestore();
  const leaderBatch = writeBatch(leaderDb), leaderEvent = doc(collection(leaderDb, 'operationLogs', id, 'events'));
  leaderBatch.update(doc(leaderDb, 'operationLogs', id), {summary: 'Meeskonnavanema täiendus', outcome: '',
    completedBy: activeMemberId, completedAt: serverTimestamp(), updatedAt: serverTimestamp()});
  leaderBatch.set(leaderEvent, {id: leaderEvent.id, operationLogId: id, organizationId, commandId: organizationId,
    type: 'summarySaved', status: 'enRoute', title: 'Lõppkokkuvõte salvestatud', description: '',
    summarySnapshot: 'Meeskonnavanema täiendus', createdBy: activeMemberId, createdAt: serverTimestamp()});
  await assertSucceeds(leaderBatch.commit());
});

test('closed-callout summary exception rejects active callouts, cross-org links and unauthorized members', async () => {
  for (const [name, status, org, user] of [
    ['active', 'active', organizationId, orgAdminId],
    ['cross-org', 'closed', otherOrganizationId, orgAdminId],
    ['member', 'closed', organizationId, activeMemberId],
    ['outsider', 'closed', organizationId, otherUserId],
  ]) {
    const id = `summary-${name}`, calloutId = `callout-${name}`;
    await seedOperationLog(id, 'open');
    await testEnv.withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(), 'callouts', calloutId), calloutData(calloutId, {status, organizationId: org, commandId: org}));
      await updateDoc(doc(ctx.firestore(), 'operationLogs', id), {calloutId});
    });
    const db = testEnv.authenticatedContext(user).firestore();
    await assertFails(updateDoc(doc(db, 'operationLogs', id), {summary: 'Forbidden', outcome: '',
      completedBy: user, completedAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  }
});

test('TROSS activation succeeds with one unqualified admin and no responders; SAR legacy stays valid', async () => {
  const org = 'single-member-org';
  await testEnv.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, `commands/${org}`), {createdBy: orgAdminId, status: 'approved', minimumCrewRequired: 3});
    await setDoc(doc(db, `memberships/${orgAdminId}_${org}`), {
      ...activeMembership(orgAdminId, org), role: 'orgAdmin', seaRescueLevel: 'none'});
  });
  const db = testEnv.authenticatedContext(orgAdminId).firestore();
  const id = 'solo-tross';
  await assertSucceeds(setDoc(doc(db, `callouts/${id}`), calloutData(id, {
    organizationId: org, commandId: org, calloutType: 'tross', responseTargetMinutes: 60})));
  const saved = (await getDoc(doc(db, `callouts/${id}`))).data();
  require('node:assert/strict').equal(saved.calloutType, 'tross');
  require('node:assert/strict').equal(saved.status, 'active');
  await assertSucceeds(setDoc(doc(db, 'callouts/legacy-sar'), calloutData('legacy-sar')));
  await assertSucceeds(setDoc(doc(db, 'callouts/new-sar'), calloutData('new-sar', {calloutType: 'sar', responseTargetMinutes: null})));
});

test('callout policy enforces TROSS target bounds and explicit type independently of title', async () => {
  const db = testEnv.authenticatedContext(orgAdminId).firestore();
  for (const [i, extra] of [
    {calloutType: 'tross'}, {calloutType: 'tross', responseTargetMinutes: 0},
    {calloutType: 'tross', responseTargetMinutes: 61}, {calloutType: 'tross', responseTargetMinutes: 1.5},
    {calloutType: 'tross', responseTargetMinutes: '60'}, {calloutType: 'unknown'},
    {calloutType: 'sar', responseTargetMinutes: 15},
  ].entries()) await assertFails(setDoc(doc(db, `callouts/invalid-${i}`), calloutData(`invalid-${i}`, extra)));
  await assertSucceeds(setDoc(doc(db, 'callouts/short-tross'), calloutData('short-tross', {calloutType:'tross', responseTargetMinutes:1})));
  await assertFails(updateDoc(doc(db, 'callouts/short-tross'), {calloutType:'sar', responseTargetMinutes:null}));
  const memberDb = testEnv.authenticatedContext(activeMemberId).firestore();
  await assertFails(setDoc(doc(memberDb, 'callouts/member-tross'), calloutData('member-tross', {
    createdBy:activeMemberId, calloutType:'tross', responseTargetMinutes:60})));
});

for (const calloutType of ['sar','tross']) {
for (const isTest of [false,true]) {
test(`quick ${calloutType} ${isTest ? 'drill' : 'real event'} creates callout, notification and own log without a location or description`, async () => {
  const db = testEnv.authenticatedContext(orgAdminId).firestore();
  const id='batch-tross', logId=`callout_${id}_created`;
  const batch=writeBatch(db);
  batch.set(doc(db,`callouts/${id}`),calloutData(id,{isTest,title:calloutType==='sar'?'SAR sündmus':'TROSSI mereabi',calloutType,responseTargetMinutes:calloutType==='tross'?60:null}));
  batch.set(doc(db,'notifications/batch-tross'),{id:'batch-tross',organizationId,commandId:organizationId,
    title:'Väljakutse: TROSSI mereabi',message:'Tehniline rike.',type:'callout',priority:'high',relatedType:'callout',relatedId:id,
    createdBy:orgAdminId,createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.set(doc(db,`operationLogs/${logId}`),{id:logId,organizationId,commandId:organizationId,
    createdBy:orgAdminId,createdByName:'Admin',type:'note',title:'Väljakutse loodud',description:'',status:'open',calloutId:id,
    timestamp:serverTimestamp(),createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.set(doc(db,`operationLogs/${logId}/events/created`),{id:'created',organizationId,commandId:organizationId,
    operationLogId:logId,type:'statusChange',status:'open',title:'Avatud',description:'',createdBy:orgAdminId,createdByName:'Admin',createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  const log=(await getDoc(doc(db,`operationLogs/${logId}`))).data();
  require('node:assert/strict').equal(log.status,'open');
  require('node:assert/strict').equal(log.calloutId,id);
  const stored=(await serverDb().doc(`callouts/${id}`).get()).data();
  require('node:assert/strict').equal(stored.isTest,isTest);
  await assertFails(setDoc(doc(testEnv.authenticatedContext(activeMemberId).firestore(),'callouts/member-drill'),
    calloutData('member-drill',{isTest:true,createdBy:activeMemberId})));
  const {FieldValue}=serverRequire('firebase-admin/firestore');
  const amend=serverRequire('./callout-report').createAmendCalloutHandler({db:serverDb(),timestamp:()=>FieldValue.serverTimestamp()});
  await amend({auth:{uid:orgAdminId},data:{organizationId,calloutId:id,version:stored.updatedAt.toMillis(),
    title:stored.title,description:'Täpsustus pärast alarmeerimist',location:'Purtse sadama lähistel'}});
  const member=testEnv.authenticatedContext(activeMemberId).firestore();
  const updated=(await assertSucceeds(getDoc(doc(member,`callouts/${id}`)))).data();
  require('node:assert/strict').equal(updated.description,'Täpsustus pärast alarmeerimist');
  require('node:assert/strict').equal(updated.status,'active');
  require('node:assert/strict').equal(updated.isTest,isTest);
  require('node:assert/strict').equal((await serverDb().collection(`callouts/${id}/changeHistory`).get()).size,1);
  await assertFails(setDoc(doc(db,'callouts/fake-time'),calloutData('fake-time',{
    calloutType:'tross',responseTargetMinutes:60,createdAt:new Date('2020-01-01')})));
});

}
}

test('first availability transaction reads missing own record and writes status with notification', async () => {
  const db = testEnv.authenticatedContext(activeMemberId).firestore();
  const id = `${activeMemberId}_${organizationId}`;
  await assertSucceeds(runTransaction(db, async tx => {
    const ref = doc(db, `availability/${id}`);
    const snapshot = await tx.get(ref);
    if (snapshot.exists()) throw new Error('Expected a new member without availability');
    tx.set(ref, {id, userId: activeMemberId, organizationId, commandId: organizationId,
      status: 'onDuty', responseMinutes: null, note: null,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
    tx.set(doc(db, 'notifications/first-duty'), {id:'first-duty', organizationId, commandId:organizationId,
      title:'Valvesoleku muudatus', message:'Liige märkis ennast valvesse.', type:'availability', priority:'normal',
      relatedType:'availability', relatedId:id, createdBy:activeMemberId,
      createdAt:serverTimestamp(), updatedAt:serverTimestamp()});
  }));
  const snapshot = await assertSucceeds(getDoc(doc(db, `availability/${id}`)));
  if(snapshot.data().status !== 'onDuty') throw new Error('Status not persisted');
});

test('missing availability read does not grant other-user, other-org, removed or anonymous access', async () => {
  const db = testEnv.authenticatedContext(activeMemberId).firestore();
  await assertFails(getDoc(doc(db, `availability/${targetMemberId}_${organizationId}`)));
  await assertFails(getDoc(doc(db, `availability/${activeMemberId}_${otherOrganizationId}`)));
  const removedDb = testEnv.authenticatedContext(memberId).firestore();
  await assertFails(getDoc(doc(removedDb, `availability/${memberId}_${organizationId}`)));
  await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), `availability/${activeMemberId}_${organizationId}`)));
});

test('organization permits are admin-managed and cannot change organization or creator', async () => {
  const admin = testEnv.authenticatedContext(orgAdminId).firestore();
  const member = testEnv.authenticatedContext(activeMemberId).firestore();
  const data = {id:'permit',organizationId,title:'Raadioside luba',number:'123',issuer:'TTJA',issuedAt:'2026-09-01',expiresAt:'',note:'',createdBy:orgAdminId,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(admin,'organizationPermits/permit'),data));
  await assertSucceeds(getDocs(query(collection(admin,'organizationPermits'),where('organizationId','==',organizationId))));
  await assertFails(getDoc(doc(member,'organizationPermits/permit')));
  await assertFails(setDoc(doc(member,'organizationPermits/member'),{...data,id:'member',createdBy:activeMemberId}));
  await assertSucceeds(updateDoc(doc(admin,'organizationPermits/permit'),{number:'456',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(admin,'organizationPermits/permit'),{organizationId:otherOrganizationId,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(admin,'organizationPermits/permit'),{createdBy:activeMemberId,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(admin,'organizationPermits/permit'),{unexpected:true,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(admin,'organizationPermits/permit'),{title:'',updatedAt:serverTimestamp()}));
});

test('certificate calendar metadata preserves admin/owner scope and validates lifetime and archive fields', async () => {
  const admin = testEnv.authenticatedContext(orgAdminId).firestore();
  const owner = testEnv.authenticatedContext(activeMemberId).firestore();
  const peer = testEnv.authenticatedContext(targetMemberId).firestore();
  const value = {id: 'calendar-cert', organizationId, commandId: organizationId,
    userId: activeMemberId, userName: 'Member', title: 'Radio', type: 'radio', issuer: 'Issuer',
    issuedAt: '2025-01-01', expiresAt: '2027-01-01', status: 'valid', note: '', createdBy: orgAdminId};
  const ref = doc(admin, 'certificates/calendar-cert');
  await assertSucceeds(setDoc(ref, value));
  await assertSucceeds(getDoc(doc(owner, 'certificates/calendar-cert')));
  await assertFails(getDoc(doc(peer, 'certificates/calendar-cert')));
  await assertSucceeds(updateDoc(ref, {number: 'ABC-123', noExpiry: false}));
  await assertFails(updateDoc(ref, {number: 123}));
  await assertFails(updateDoc(ref, {number: 'a'.repeat(101)}));
  await assertFails(updateDoc(ref, {noExpiry: true}));
  await assertSucceeds(updateDoc(ref, {noExpiry: true, expiresAt: ''}));
  await assertFails(updateDoc(ref, {archived: 'true'}));
  await assertSucceeds(updateDoc(ref, {archived: true}));
  await assertFails(updateDoc(doc(owner, 'certificates/calendar-cert'), {archived: false}));
  await assertFails(updateDoc(ref, {userId: targetMemberId}));
  await assertFails(updateDoc(ref, {organizationId: otherOrganizationId, commandId: otherOrganizationId}));
});

test('certificate reminders are server-only, recipient-private and can be marked read', async () => {
  await testEnv.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'certificateReminders/reminder'),{id:'reminder',organizationId,commandId:organizationId,recipientUserId:activeMemberId,memberUserId:activeMemberId,title:'Tunnistus aegub'});
  });
  const owner = testEnv.authenticatedContext(activeMemberId).firestore();
  const peer = testEnv.authenticatedContext(targetMemberId).firestore();
  await assertSucceeds(getDocs(query(collection(owner,'certificateReminders'),where('organizationId','==',organizationId),where('recipientUserId','==',activeMemberId))));
  await assertFails(getDoc(doc(peer,'certificateReminders/reminder')));
  await assertFails(getDocs(collection(owner,'certificateReminders')));
  await assertFails(setDoc(doc(owner,'certificateReminders/forged'),{organizationId,recipientUserId:activeMemberId}));
  const read = {id:`reminder_${activeMemberId}`,notificationId:'reminder',userId:activeMemberId,organizationId,commandId:organizationId,readAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(owner,`notificationReads/${read.id}`),read));
  await assertFails(setDoc(doc(peer,`notificationReads/reminder_${targetMemberId}`),{...read,id:`reminder_${targetMemberId}`,userId:targetMemberId}));
});

test('warehouse assignment keeps condition and requires active same-org recipient', async () => {
  const admin = testEnv.authenticatedContext(orgAdminId).firestore();
  const member = testEnv.authenticatedContext(activeMemberId).firestore();
  const ref = doc(admin,'equipment/warehouse');
  await assertSucceeds(setDoc(ref,{id:'warehouse',organizationId,commandId:organizationId,scope:'organization',storage:'warehouse',name:'Vest',category:'safety',status:'needsMaintenance',location:'Ladu',note:'',createdBy:orgAdminId}));
  await assertSucceeds(updateDoc(ref,{assignedToUserId:activeMemberId,assignedToName:'Liige',issuedAt:serverTimestamp(),issuedBy:orgAdminId}));
  require('node:assert/strict').equal((await getDoc(ref)).data().status,'needsMaintenance');
  await assertFails(updateDoc(doc(member,'equipment/warehouse'),{assignedToUserId:targetMemberId}));
  await assertFails(updateDoc(ref,{assignedToUserId:otherUserId}));
  await assertSucceeds(updateDoc(ref,{assignedToUserId:'',assignedToName:'',storage:'warehouse',returnedAt:serverTimestamp(),returnedBy:orgAdminId}));
  await assertFails(updateDoc(ref,{storage:'invalid'}));
});


test('statistics history and activation settings cannot be read or forged by clients', async () => {
  for (const uid of [orgAdminId, activeMemberId]) {
    const db = testEnv.authenticatedContext(uid).firestore();
    for (const path of ['statisticsHistory/entry', 'statisticsSettings/tracking']) {
      await assertFails(setDoc(doc(db, path), {organizationId, userId: uid, startedAt: serverTimestamp()}));
      await assertFails(getDoc(doc(db, path)));
    }
  }
});
test('callout crew is readable by active peers but only server-written', async () => {
  await testEnv.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'calloutAttendance/c_user'), {organizationId, calloutId: 'c', userId: activeMemberId, status: 'confirmed', hours: 2});
  });
  const adminDb = testEnv.authenticatedContext(orgAdminId).firestore();
  const selfDb = testEnv.authenticatedContext(activeMemberId).firestore();
  const peerDb = testEnv.authenticatedContext(targetMemberId).firestore();
  await assertSucceeds(getDocs(query(collection(adminDb, 'calloutAttendance'), where('organizationId', '==', organizationId), where('calloutId', '==', 'c'))));
  await assertSucceeds(getDoc(doc(selfDb, 'calloutAttendance/c_user')));
  await assertSucceeds(getDoc(doc(peerDb, 'calloutAttendance/c_user')));
  await assertFails(getDoc(doc(testEnv.authenticatedContext(otherUserId).firestore(), 'calloutAttendance/c_user')));
  for (const db of [adminDb, selfDb]) await assertFails(setDoc(doc(db, 'calloutAttendance/forged'), {organizationId, userId: activeMemberId, calloutId: 'c', status: 'confirmed'}));
});

test('II-level member can append a retrospective note and edit final summary after return; original events stay immutable', async()=>{
 const id='leader-log';await seedOperationLog(id,'returnedToBase');
 await testEnv.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),`memberships/${activeMemberId}_${organizationId}`),{seaRescueLevel:'level2'}));
 const db=testEnv.authenticatedContext(activeMemberId).firestore();
 const note={id:'note',operationLogId:id,organizationId,commandId:organizationId,type:'manualNote',status:'returnedToBase',title:'Täiendus',text:'Täiendus',description:'',createdBy:activeMemberId,createdAt:serverTimestamp(),occurredAt:new Date('2026-09-01T10:00:00Z')};
 await assertSucceeds(setDoc(doc(db,`operationLogs/${id}/events/note`),note));
 await assertFails(updateDoc(doc(db,`operationLogs/${id}/events/note`),{text:'Rewrite'}));
 await assertFails(setDoc(doc(db,`operationLogs/${id}/events/future`),{...note,id:'future',occurredAt:new Date('2099-01-01')}));
 const batch=writeBatch(db);batch.update(doc(db,`operationLogs/${id}`),{summary:'Täiendatud kokkuvõte',outcome:'Valmis',completedBy:activeMemberId,completedAt:serverTimestamp(),updatedAt:serverTimestamp()});
 batch.set(doc(db,`operationLogs/${id}/events/summary`),{id:'summary',operationLogId:id,organizationId,commandId:organizationId,type:'summarySaved',status:'returnedToBase',title:'Lõppkokkuvõte salvestatud',description:'Valmis',summarySnapshot:'Täiendatud kokkuvõte',createdBy:activeMemberId,createdAt:serverTimestamp()});
 await assertSucceeds(batch.commit());
});
test('log access does not follow II-level qualification into other organizations or survive removal',async()=>{
 await seedOperationLog('leader-denied','open');
 for(const extra of [{seaRescueLevel:'level1'},{seaRescueLevel:'level2',status:'removed',isActive:false},{seaRescueLevel:'level2',organizationId:otherOrganizationId,commandId:otherOrganizationId}]) {
  await testEnv.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),`memberships/${activeMemberId}_${organizationId}`),{...activeMembership(activeMemberId,organizationId),...extra}));
  const db=testEnv.authenticatedContext(activeMemberId).firestore();
  await assertFails(updateDoc(doc(db,'operationLogs/leader-denied'),{status:'enRoute',updatedAt:serverTimestamp()}));
 }
});
test('crew audit can be read with scoped queries and cannot be forged',async()=>{
 const path='callouts/c/attendanceHistory/change';
 await testEnv.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),path),{organizationId,calloutId:'c',userId:activeMemberId,createdBy:orgAdminId,createdAt:serverTimestamp()}));
 const db=testEnv.authenticatedContext(activeMemberId).firestore();
 await assertSucceeds(getDocs(query(collection(db,'callouts/c/attendanceHistory'),where('organizationId','==',organizationId),where('calloutId','==','c'))));
 await assertFails(setDoc(doc(db,path),{organizationId,calloutId:'c',userId:activeMemberId}));
 await assertFails(getDoc(doc(testEnv.authenticatedContext(otherUserId).firestore(),path)));
});

test('II-level member can register a live status event with general member log permission disabled',async()=>{
 await seedOperationLog('live-leader','open');
 await testEnv.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),`memberships/${activeMemberId}_${organizationId}`),{seaRescueLevel:'level2'}));
 const db=testEnv.authenticatedContext(activeMemberId).firestore(),batch=writeBatch(db);
 batch.update(doc(db,'operationLogs/live-leader'),{status:'enRoute',updatedAt:serverTimestamp()});
 batch.set(doc(db,'operationLogs/live-leader/events/departure'),{id:'departure',operationLogId:'live-leader',organizationId,commandId:organizationId,type:'statusChange',status:'enRoute',title:'Teel',description:'',createdBy:activeMemberId,createdAt:serverTimestamp()});
 await assertSucceeds(batch.commit());
});


test('new organization profile is atomic with pending creator and restricted from unrelated users',async()=>{
 const client=testEnv.authenticatedContext(activeMemberId).firestore(), org='new-profile-org',batch=writeBatch(client);
 batch.set(doc(client,'commands',org),{name:'Uus ühing',joinCode:'ABCD12',createdBy:activeMemberId,status:'pending',allowMembersToCreateActivities:false,allowMembersToViewStatistics:false,allowMembersToStartOperationLog:false,createdAt:serverTimestamp(),isOnDuty:false});
 batch.set(doc(client,'memberships',`${activeMemberId}_${org}`),{userId:activeMemberId,organizationId:org,commandId:org,role:'orgAdmin',seaRescueLevel:'none',status:'pending',isActive:false,joinedAt:serverTimestamp()});
 const profile={organizationId:org,createdBy:activeMemberId,createdAt:serverTimestamp(),registrationCode:'',organizationType:'MTÜ',region:'',address:'',contactName:'Kontakt',contactPhone:'',contactEmail:'contact@example.test',organizationEmail:'',description:'',logoUrl:''};
 batch.set(doc(client,'organizationProfiles',org),profile);
 await assertSucceeds(batch.commit());
 await assertSucceeds(getDoc(doc(client,'organizationProfiles',org)));
 await assertFails(getDoc(doc(testEnv.authenticatedContext(otherUserId).firestore(),'organizationProfiles',org)));
 await assertFails(updateDoc(doc(client,'organizationProfiles',org),{createdBy:otherUserId}));
});

test('ordinary member response cannot grant operational editing even with legacy permission enabled',async()=>{
 const db=serverDb();await db.doc(`commands/${organizationId}`).update({allowMembersToStartOperationLog:true});
 await db.doc('callouts/scoped-response').set({organizationId,commandId:organizationId,status:'active'});
 await db.doc('calloutResponses/scoped-response_active-member').set({organizationId,commandId:organizationId,calloutId:'scoped-response',userId:activeMemberId,response:'responding'});
 const admin=testEnv.authenticatedContext(orgAdminId).firestore();
 await assertSucceeds(getDocs(query(collection(admin,'calloutResponses'),and(where('calloutId','==','scoped-response'),or(where('organizationId','==',organizationId),where('commandId','==',organizationId))))));
 const member=testEnv.authenticatedContext(activeMemberId).firestore();
 await assertFails(updateDoc(doc(member,'callouts/scoped-response'),{status:'closed',updatedAt:serverTimestamp()}));
 await seedOperationLog('legacy-setting-log','onScene');
 await assertFails(updateDoc(doc(member,'operationLogs/legacy-setting-log'),{status:'returning',updatedAt:serverTimestamp()}));
});
const assert = require('node:assert/strict');
test('organization profile changes are admin-only, versioned and audited including legacy organizations',async()=>{
 const {createSaveOrganizationProfileHandler}=require('../functions/organization-profile');const db=serverDb();
 const handler=createSaveOrganizationProfileHandler({db,timestamp:()=>new Date()});
 const profile=Object.fromEntries(['registrationCode','organizationType','region','address','contactName','contactPhone','contactEmail','organizationEmail','description','logoUrl'].map(k=>[k,'']));
 Object.assign(profile,{contactName:'Kontakt',contactEmail:'contact@example.test'});
 const data={organizationId,name:'Uuendatud ühing',revision:0,profile};
 const admin=testEnv.authenticatedContext(orgAdminId).firestore();
 await assertSucceeds(getDoc(doc(admin,'organizationProfiles',organizationId)));
 await assert.rejects(handler({auth:{uid:activeMemberId},data}),e=>e.code==='permission-denied');
 await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
 await assert.rejects(handler({auth:{uid:'platform-only'},data}),e=>e.code==='permission-denied');
 await handler({auth:{uid:orgAdminId},data});
 assert.equal((await db.doc(`commands/${organizationId}`).get()).data().name,data.name);
 assert.equal((await db.doc(`organizationProfiles/${organizationId}`).get()).data().revision,1);
 assert.equal((await db.collection(`organizationProfiles/${organizationId}/history`).get()).size,1);
 await assert.rejects(handler({auth:{uid:orgAdminId},data}),e=>e.code==='aborted');
 await assertFails(updateDoc(doc(admin,'organizationProfiles',organizationId),{contactEmail:'bypass@example.test'}));
 await assertFails(getDocs(collection(testEnv.authenticatedContext(activeMemberId).firestore(),`organizationProfiles/${organizationId}/history`)));
 await assert.rejects(handler({auth:{uid:orgAdminId},data:{...data,revision:1,profile:{...profile,logoUrl:'javascript:alert(1)'}}}),e=>e.code==='invalid-argument');
});

test('retrospective event date and type amendment preserves original chronology and enforces operational rights',async()=>{
 const {createAmendCalloutHandler}=require('../functions/callout-report');const db=serverDb();
 const original=new Date('2026-09-01T10:00:00Z'),end=new Date('2026-09-01T12:00:00Z');
 await db.doc('callouts/amend-date').set({organizationId,commandId:organizationId,status:'closed',title:'Vana',description:'',location:'Sadam',createdAt:original,closedAt:end,calloutType:'sar'});
 const handler=createAmendCalloutHandler({db,timestamp:()=>new Date('2026-09-03T12:00:00Z'),now:()=>Date.parse('2026-09-04T12:00:00Z')});
 const data={organizationId,calloutId:'amend-date',title:'Parandatud',description:'',location:'Sadam',version:0,startedAt:'2026-08-31T10:00:00Z',endedAt:'2026-08-31T12:00:00Z',calloutType:'tross',responseTargetMinutes:45};
 await assert.rejects(handler({auth:{uid:activeMemberId},data}),e=>e.code==='permission-denied');
 await assert.rejects(handler({auth:{uid:orgAdminId},data:{...data,endedAt:'2026-08-30T12:00:00Z'}}),e=>e.code==='invalid-argument');
 await handler({auth:{uid:orgAdminId},data});
 const saved=(await db.doc('callouts/amend-date').get()).data();
 assert.equal(saved.startedAt.toDate().toISOString(),data.startedAt.replace('Z','.000Z'));
 assert.equal(saved.createdAt.toMillis(),+original);assert.equal(saved.closedAt.toMillis(),+end);assert.equal(saved.calloutType,'tross');
 assert.equal((await db.collection('callouts/amend-date/changeHistory').get()).size,1);
 await assert.rejects(handler({auth:{uid:orgAdminId},data}),e=>e.code==='aborted');
 await assertFails(updateDoc(doc(testEnv.authenticatedContext(activeMemberId).firestore(),'callouts/amend-date'),{startedAt:new Date()}));
 await db.doc(`memberships/${activeMemberId}_${organizationId}`).update({seaRescueLevel:'level2'});
 await handler({auth:{uid:activeMemberId},data:{...data,version:saved.updatedAt.toMillis(),calloutType:'sar',responseTargetMinutes:null}});
});

test('attachments are private, scoped, idempotent and audited with no direct client access',async()=>{
 const {createAttachmentHandlers}=require('../functions/callout-attachments');const db=serverDb();
 await db.doc('callouts/attachment-event').set({organizationId,commandId:organizationId,status:'closed'});
 const objects=new Map();let writes=0;
 const bucket={file:p=>({save:async(bytes,options)=>{if(objects.has(p))throw {code:412};writes++;objects.set(p,{bytes,metadata:options.metadata});},getMetadata:async()=>[objects.get(p).metadata],download:async()=>[objects.get(p).bytes]})};
 const handlers=createAttachmentHandlers({db,bucket,timestamp:()=>new Date()});
 const data={organizationId,calloutId:'attachment-event',requestId:'unique-file',name:'test.txt',base64:Buffer.from('Õppuse fail').toString('base64')};
 await assert.rejects(handlers.upload({auth:{uid:activeMemberId},data}),e=>e.code==='permission-denied');
 await assert.rejects(handlers.upload({auth:{uid:orgAdminId},data:{...data,name:'../path.txt'}}),e=>e.code==='invalid-argument');
 const result=await handlers.upload({auth:{uid:orgAdminId},data});
 await handlers.upload({auth:{uid:orgAdminId},data});assert.equal(writes,1);
 assert.equal((await db.collection('platformAudit').where('action','==','callout.attachmentAdded').get()).size,1);
 const download={organizationId,calloutId:data.calloutId,attachmentId:result.attachmentId};
 await assert.rejects(handlers.download({auth:{uid:activeMemberId},data:download}),e=>e.code==='permission-denied');
 assert.equal((await handlers.download({auth:{uid:orgAdminId},data:download})).base64,data.base64);
 await assert.rejects(handlers.upload({auth:{uid:orgAdminId},data:{...data,base64:Buffer.from('Changed').toString('base64')}}),e=>e.code==='already-exists');
 await assert.rejects(handlers.upload({auth:{uid:orgAdminId},data:{...data,organizationId:otherOrganizationId}}),e=>e.code==='permission-denied');
 for(const uid of [activeMemberId,orgAdminId]){
  const client=testEnv.authenticatedContext(uid).firestore();
  await assertFails(getDoc(doc(client,'calloutAttachments',result.attachmentId)));
  await assertFails(setDoc(doc(client,'calloutAttachments','bypass'),{organizationId}));
  await assertFails(getDoc(doc(client,'calloutPushDeliveries','alarm')));
 }
});


test('Storage denies direct reads, writes and listing even to an organization admin',async()=>{
 const {ref,uploadBytes,getMetadata,listAll}=require('firebase/storage');
 for(const context of [testEnv.unauthenticatedContext(),testEnv.authenticatedContext(activeMemberId),testEnv.authenticatedContext(orgAdminId)]) {
  const storage=context.storage('gs://demo-respondcrew.firebasestorage.app');
  const target=ref(storage,`calloutAttachments/${organizationId}/event/file`);
  await assertFails(uploadBytes(target,Buffer.from('private'),{contentType:'text/plain'}));
  await assertFails(getMetadata(target));
  await assertFails(listAll(ref(storage,'calloutAttachments')));
 }
});


test('attachment maximum size works and concurrent uploads cannot exceed the event limit',async()=>{
 const {createAttachmentHandlers,MAX_BYTES}=require('../functions/callout-attachments');const db=serverDb();
 await db.doc('callouts/attachment-capacity').set({organizationId,commandId:organizationId,status:'closed'});
 let writes=0;
 const bucket={file:()=>({save:async bytes=>{writes++;assert.equal(bytes.length,MAX_BYTES);}})};
 const handlers=createAttachmentHandlers({db,bucket,timestamp:()=>new Date()});
 const batch=db.batch();for(let i=0;i<29;i++)batch.set(db.doc(`calloutAttachments/old-${i}`),{organizationId,calloutId:'attachment-capacity',status:'ready'});await batch.commit();
 const data={organizationId,calloutId:'attachment-capacity',name:'large.txt',base64:Buffer.alloc(MAX_BYTES,65).toString('base64')};
 const results=await Promise.allSettled(['one','two'].map(requestId=>handlers.upload({auth:{uid:orgAdminId},data:{...data,requestId}})));
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal(results.find(r=>r.status==='rejected').reason.code,'resource-exhausted');
 assert.equal(writes,1);assert.equal((await db.collection('calloutAttachments').where('calloutId','==',data.calloutId).get()).size,30);
 await assert.rejects(handlers.upload({auth:{uid:orgAdminId},data:{...data,requestId:'bad',base64:'****'}}),e=>e.code==='invalid-argument');
});


test('member readiness returns only current unavailability while private schedules and duty controls remain protected', async () => {
  const assert = require('node:assert/strict');
  const {createReadinessAvailabilityHandler} = serverRequire('./readiness-availability');
  const db = serverDb(), now = Date.parse('2026-09-29T09:00:00Z');
  const {Timestamp} = serverRequire('firebase-admin/firestore');
  await db.doc(`commands/${organizationId}`).update({dutyPaused:true,dutyPauseReason:'Season ended'});
  await db.doc('plannedUnavailability/private-peer').set({organizationId,commandId:organizationId,
    userId:targetMemberId,status:'active',startAt:Timestamp.fromMillis(now),endAt:Timestamp.fromMillis(now+10000),note:'PRIVATE MEDICAL NOTE'});
  await db.doc('plannedUnavailability/private-other-org').set({organizationId:otherOrganizationId,
    userId:otherUserId,status:'active',startAt:Timestamp.fromMillis(now),endAt:Timestamp.fromMillis(now+10000)});
  const handler = createReadinessAvailabilityHandler({db,now:()=>now});
  const readiness = await handler({auth:{uid:activeMemberId},data:{organizationId}});
  assert.deepEqual(readiness.unavailableUserIds,[targetMemberId]);
  assert.equal(readiness.paused,true);
  assert.doesNotMatch(JSON.stringify(readiness),/PRIVATE MEDICAL NOTE/);
  const client=testEnv.authenticatedContext(activeMemberId).firestore();
  await assertFails(getDoc(doc(client,'plannedUnavailability/private-peer')));
  await assertFails(getDocs(query(collection(client,'plannedUnavailability'),where('organizationId','==',organizationId))));
  assert.equal((await assertSucceeds(getDoc(doc(client,`commands/${organizationId}`)))).data().dutyPauseReason,'Season ended');
  await assertFails(updateDoc(doc(client,`commands/${organizationId}`),{dutyPaused:false}));
  for(const uid of [memberId,otherUserId,'platform-only']) {
    await assert.rejects(handler({auth:{uid},data:{organizationId}}),e=>e.code==='permission-denied');
  }
  await assert.rejects(handler({data:{organizationId}}),e=>e.code==='unauthenticated');
  await assert.rejects(handler({auth:{uid:activeMemberId},data:{organizationId:otherOrganizationId}}),e=>e.code==='permission-denied');
});
async function seedPhoneCallout({response = 'responding', attendance, status = 'active'} = {}) {
  const db=serverDb();
  await db.doc('callouts/phone-callout').set({id:'phone-callout',organizationId,commandId:organizationId,status});
  await seedOperationLog('phone-log','enRoute');
  await db.doc('operationLogs/phone-log').update({calloutId:'phone-callout'});
  if(response) await db.doc(`calloutResponses/phone-callout_${activeMemberId}`).set({id:`phone-callout_${activeMemberId}`,organizationId,commandId:organizationId,calloutId:'phone-callout',userId:activeMemberId,response});
  if(attendance) await db.doc(`calloutAttendance/phone-callout_${activeMemberId}`).set({organizationId,calloutId:'phone-callout',userId:activeMemberId,status:attendance});
  return testEnv.authenticatedContext(activeMemberId).firestore();
}
function phoneNote(id, overrides={}) {
  return {id,operationLogId:'phone-log',organizationId,commandId:organizationId,type:'manualNote',status:'enRoute',
    title:'Kontakt abivajajaga',text:'Kontakt abivajajaga',description:'',createdBy:activeMemberId,createdByName:'Liige',createdAt:serverTimestamp(),...overrides};
}
test('phone participant appends notes and informational end without changing callout or log status',async()=>{
  const db=await seedPhoneCallout();
  await assertSucceeds(setDoc(doc(db,'operationLogs/phone-log/events/note'),phoneNote('note',{occurredAt:new Date('2026-01-01'),latitude:59.44,longitude:27.01,accuracyMeters:8})));
  const event=phoneNote('end',{type:'quickAction',title:'Sündmus lõpetatud'});delete event.text;
  await assertSucceeds(setDoc(doc(db,'operationLogs/phone-log/events/end'),event));
  assert.equal((await serverDb().doc('callouts/phone-callout').get()).data().status,'active');
  assert.equal((await serverDb().doc('operationLogs/phone-log').get()).data().status,'enRoute');
  assert.equal((await serverDb().doc('operationLogs/phone-log/events/note').get()).data().createdBy,activeMemberId);
  await assertFails(updateDoc(doc(db,'operationLogs/phone-log/events/note'),{title:'Muudetud'}));
  await assertFails(deleteDoc(doc(db,'operationLogs/phone-log/events/note')));
  await assertFails(updateDoc(doc(db,'operationLogs/phone-log'),{status:'onScene',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'operationLogs/phone-log'),{summary:'Bypass',outcome:'',completedBy:activeMemberId,completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'callouts/phone-callout'),{status:'closed',closedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('phone delayed and confirmed participants append, absent attendance overrides responding',async()=>{
  const db=await seedPhoneCallout({response:'delayed'});
  await assertSucceeds(setDoc(doc(db,'operationLogs/phone-log/events/delayed'),phoneNote('delayed')));
  await serverDb().doc(`calloutAttendance/phone-callout_${activeMemberId}`).set({organizationId,calloutId:'phone-callout',userId:activeMemberId,status:'absent'});
  await assertFails(setDoc(doc(db,'operationLogs/phone-log/events/absent'),phoneNote('absent')));
  await serverDb().doc(`calloutAttendance/phone-callout_${activeMemberId}`).update({status:'confirmed'});
  await serverDb().doc(`calloutResponses/phone-callout_${activeMemberId}`).delete();
  await assertSucceeds(setDoc(doc(db,'operationLogs/phone-log/events/confirmed'),phoneNote('confirmed')));
});
test('phone no response and unavailable members cannot append; changing response revokes access',async()=>{
  const db=await seedPhoneCallout({response:null});
  await assertFails(setDoc(doc(db,'operationLogs/phone-log/events/none'),phoneNote('none')));
  const ref=serverDb().doc(`calloutResponses/phone-callout_${activeMemberId}`);
  await ref.set({organizationId,commandId:organizationId,calloutId:'phone-callout',userId:activeMemberId,response:'responding'});
  await assertSucceeds(setDoc(doc(db,'operationLogs/phone-log/events/yes'),phoneNote('yes')));
  await ref.update({response:'unavailable'});
  await assertFails(setDoc(doc(db,'operationLogs/phone-log/events/no'),phoneNote('no')));
});
test('phone closed/cancelled callouts, finished logs, suspended organizations and removed members deny append',async()=>{
  const db=await seedPhoneCallout(), server=serverDb();
  for(const status of ['closed','cancelled']) {
    await server.doc('callouts/phone-callout').update({status});
    await assertFails(setDoc(doc(db,`operationLogs/phone-log/events/${status}`),phoneNote(status)));
  }
  await server.doc('callouts/phone-callout').update({status:'active'});
  await server.doc('operationLogs/phone-log').update({status:'returnedToBase'});
  await assertFails(setDoc(doc(db,'operationLogs/phone-log/events/finished'),phoneNote('finished',{status:'returnedToBase'})));
  await server.doc('operationLogs/phone-log').update({status:'enRoute'});
  await server.doc(`commands/${organizationId}`).update({status:'suspended'});
  await assertFails(setDoc(doc(db,'operationLogs/phone-log/events/suspended'),phoneNote('suspended')));
  await server.doc(`commands/${organizationId}`).update({status:'approved'});
  await server.doc(`memberships/${activeMemberId}_${organizationId}`).update({isActive:false,status:'removed'});
  await assertFails(setDoc(doc(db,'operationLogs/phone-log/events/removed'),phoneNote('removed')));
});
test('phone append rejects forged author, event type, fields, oversized text, future time and other org',async()=>{
  const db=await seedPhoneCallout();
  const mutations=[{createdBy:orgAdminId},{type:'statusChange'},{type:'summarySaved'},{summarySnapshot:'fake'},
    {title:'x'.repeat(4001),text:'x'.repeat(4001)},{occurredAt:new Date('2099-01-01')},{organizationId:otherOrganizationId,commandId:otherOrganizationId},
    {status:'onScene'},{createdByName:7}];
  for(let i=0;i<mutations.length;i++) await assertFails(setDoc(doc(db,`operationLogs/phone-log/events/bad${i}`),phoneNote(`bad${i}`,mutations[i])));
  await serverDb().doc('callouts/phone-callout').update({organizationId:otherOrganizationId,commandId:otherOrganizationId});
  await assertFails(setDoc(doc(db,'operationLogs/phone-log/events/crossOrg'),phoneNote('crossOrg')));
});
test('phone response and attendance subscription queries work before first response and stay private',async()=>{
  const db=await seedPhoneCallout({response:null});
  for(const name of ['calloutResponses','calloutAttendance']) await assertSucceeds(getDocs(query(collection(db,name),where('organizationId','==',organizationId),where('calloutId','==','phone-callout'),where('userId','==',activeMemberId))));
  await assertSucceeds(getDocs(query(collection(db,'calloutResponses'),and(where('userId','==',activeMemberId),where('calloutId','==','phone-callout'),or(where('organizationId','==',organizationId),where('commandId','==',organizationId))))));
  await assertFails(getDocs(query(collection(db,'calloutResponses'),where('organizationId','==',organizationId),where('calloutId','==','phone-callout'),where('userId','==',orgAdminId))));
});


test('pack23 shared planning projects times and names without private notes and rejects outsiders',async()=>{
 const {createReadinessPlanningHandler}=serverRequire('./readiness-planning');const db=serverDb(),now=Date.parse('2026-09-29T09:00:00Z');
 await db.doc('plannedUnavailability/shared-plan').set({organizationId,userId:targetMemberId,status:'active',startAt:new Date(now),endAt:new Date(now+3600000),note:'SECRET REASON'});
 await db.doc('plannedUnavailability/cancelled-plan').set({organizationId,userId:targetMemberId,status:'cancelled',startAt:new Date(now),endAt:new Date(now+3600000),note:'SECRET CANCEL'});
 const handler=createReadinessPlanningHandler({db,now:()=>now});
 const result=await handler({auth:{uid:activeMemberId},data:{organizationId}});
 assert.equal(result.rows.length,1);assert.equal(result.rows[0].userId,targetMemberId);assert.doesNotMatch(JSON.stringify(result),/SECRET|note/);
 assert.equal((await handler({auth:{uid:activeMemberId},data:{organizationId,includeCancelled:true}})).rows.length,2);
 await assert.rejects(handler({auth:{uid:otherUserId},data:{organizationId}}),e=>e.code==='permission-denied');
 await assert.rejects(handler({auth:{uid:memberId},data:{organizationId}}),e=>e.code==='permission-denied');
});

test('pack23 test marker is admin-only, cross-org safe, version checked and audited without deletion',async()=>{
 const {createSetCalloutTestStatusHandler}=serverRequire('./callout-test-status');const db=serverDb();
 const handler=createSetCalloutTestStatusHandler({db,timestamp:()=>new Date()});
 await db.doc('callouts/keep-test').set({organizationId,status:'closed',title:'Exercise'});
 await db.doc(`memberships/${activeMemberId}_${organizationId}`).update({seaRescueLevel:'level2'});
 const request={calloutId:'keep-test',organizationId,isTest:true,expectedIsTest:false};
 for(const uid of [activeMemberId,targetMemberId,otherUserId,'platform-only']) {
  await assert.rejects(handler({auth:{uid},data:request}),e=>e.code==='permission-denied');
 }
 await assertFails(updateDoc(doc(testEnv.authenticatedContext(orgAdminId).firestore(),'callouts/keep-test'),{isTest:true,updatedAt:serverTimestamp()}));
 await handler({auth:{uid:orgAdminId},data:request});
 assert.equal((await db.doc('callouts/keep-test').get()).data().isTest,true);
 assert.equal((await db.collection('callouts/keep-test/changeHistory').get()).size,1);
 assert.equal((await db.collection('platformAudit').where('action','==','callout.testStatusChanged').get()).size,1);
 await assert.rejects(handler({auth:{uid:orgAdminId},data:request}),e=>e.code==='aborted');
 await handler({auth:{uid:orgAdminId},data:{...request,isTest:false,expectedIsTest:true}});
 assert.equal((await db.doc('callouts/keep-test').get()).data().isTest,false);
});

test('pack23 notification preferences are self-owned and cannot grant any membership rights',async()=>{
 const {createSetNotificationPreferenceHandler}=serverRequire('./notification-preferences');const db=serverDb();
 const handler=createSetNotificationPreferenceHandler({db,timestamp:()=>new Date()});
 const request={organizationId,key:'readinessLost',enabled:true,userId:orgAdminId};
 await handler({auth:{uid:activeMemberId},data:request});
 assert.equal((await db.doc(`notificationPreferences/${activeMemberId}_${organizationId}`).get()).data().preferences.readinessLost,true);
 assert.equal((await db.doc(`notificationPreferences/${orgAdminId}_${organizationId}`).get()).exists,false);
 const client=testEnv.authenticatedContext(activeMemberId).firestore();
 await assertSucceeds(getDoc(doc(client,`notificationPreferences/${activeMemberId}_${organizationId}`)));
 await assertFails(getDoc(doc(testEnv.authenticatedContext(targetMemberId).firestore(),`notificationPreferences/${activeMemberId}_${organizationId}`)));
 await assertFails(setDoc(doc(client,`notificationPreferences/${activeMemberId}_${organizationId}`),{role:'orgAdmin'}));
 await assert.rejects(handler({auth:{uid:activeMemberId},data:{...request,key:'role'}}),e=>e.code==='invalid-argument');
 await assert.rejects(handler({auth:{uid:memberId},data:request}),e=>e.code==='permission-denied');
 await assert.rejects(handler({auth:{uid:activeMemberId},data:{...request,organizationId:otherOrganizationId}}),e=>e.code==='permission-denied');
});

test('pack23 private inbox supports recipient-scoped query/read receipt but blocks other members and client writes',async()=>{
 const db=serverDb(),client=testEnv.authenticatedContext(activeMemberId).firestore();
 await db.doc('userNotifications/n').set({id:'n',organizationId,commandId:organizationId,recipientUserId:activeMemberId,title:'Ready',message:'Changed'});
 await assertSucceeds(getDocs(query(collection(client,'userNotifications'),where('organizationId','==',organizationId),where('recipientUserId','==',activeMemberId))));
 await assertFails(getDoc(doc(testEnv.authenticatedContext(targetMemberId).firestore(),'userNotifications/n')));
 await assertFails(updateDoc(doc(client,'userNotifications/n'),{message:'spoofed'}));
 await assertSucceeds(setDoc(doc(client,`notificationReads/n_${activeMemberId}`),{id:`n_${activeMemberId}`,notificationId:'n',userId:activeMemberId,organizationId,commandId:organizationId,readAt:serverTimestamp()}));
 await db.doc(`memberships/${activeMemberId}_${organizationId}`).update({status:'removed',isActive:false});
 await assertFails(getDoc(doc(client,'userNotifications/n')));
});

test('notification read bulk writes exceed atomic rules budget; independent writes support all inbox sources and retries', async () => {
  const db = serverDb();
  const client = testEnv.authenticatedContext(activeMemberId).firestore();
  const sources = ['notifications', 'certificateReminders', 'userNotifications'];
  const ids = Array.from({length: 60}, (_, i) => `bulk-read-${i}`);
  await Promise.all(ids.map((id, i) => db.doc(`${sources[i % 3]}/${id}`).set({
    id, organizationId, commandId: organizationId, recipientUserId: activeMemberId,
    title: 'Test notification', message: 'Read receipt regression',
  })));
  const receipt = id => ({id: `${id}_${activeMemberId}`, notificationId: id,
    userId: activeMemberId, organizationId, commandId: organizationId,
    readAt: serverTimestamp(), createdAt: serverTimestamp()});
  const ref = id => doc(client, `notificationReads/${id}_${activeMemberId}`);
  const oversized = writeBatch(client);
  ids.forEach(id => oversized.set(ref(id), receipt(id), {merge: true}));
  await assertFails(oversized.commit());
  assert.equal((await db.collection('notificationReads').get()).size, 0);
  for (let start = 0; start < ids.length; start += 4) {
    await Promise.all(ids.slice(start, start + 4).map(id =>
      assertSucceeds(setDoc(ref(id), receipt(id), {merge: true}))));
  }
  assert.equal((await db.collection('notificationReads').get()).size, ids.length);
  await assertSucceeds(setDoc(ref(ids[0]), receipt(ids[0]), {merge: true}));
  await db.doc('userNotifications/other-recipient').set({organizationId,
    commandId: organizationId, recipientUserId: targetMemberId});
  await assertFails(setDoc(ref('other-recipient'), receipt('other-recipient')));
  await assertFails(setDoc(ref(ids[0]), {...receipt(ids[0]),
    organizationId: otherOrganizationId, commandId: otherOrganizationId}));
  await assertFails(setDoc(doc(testEnv.authenticatedContext(targetMemberId).firestore(),
    `notificationReads/${ids[0]}_${activeMemberId}`), receipt(ids[0])));
});

test('pack23 public login help is a single read-only document; no public collection enumeration',async()=>{
 const db=serverDb();await db.doc('publicAppInfo/login').set({guideText:'Guide'});
 const anonymous=testEnv.unauthenticatedContext().firestore();
 await assertSucceeds(getDoc(doc(anonymous,'publicAppInfo/login')));
 await assertFails(getDocs(collection(anonymous,'publicAppInfo')));
 await assertFails(setDoc(doc(anonymous,'publicAppInfo/login'),{guideUrl:'https://untrusted.example'}));
 await assertFails(getDoc(doc(anonymous,'commands/'+organizationId)));
});

test('pack23 readiness engine coalesces duplicate triggers and plan-boundary scheduler uses the same SAR calculation',async()=>{
 const {createReadinessEngine}=serverRequire('./organization-readiness');const {loadReadiness}=serverRequire('./organization-readiness');
 const db=serverDb();let now=Date.parse('2026-09-29T09:00:00Z');
 await db.doc(`organizationReadinessSummaries/${organizationId}`).set({organizationId,minimumCrewRequired:2});
 for(const uid of [orgAdminId,activeMemberId])await db.doc(`availability/${uid}_${organizationId}`).set({organizationId,userId:uid,status:'onDuty'});
 const engine=createReadinessEngine({db,now:()=>now});await engine.recompute(organizationId);
 assert.equal((await db.collection('readinessNotificationEvents').get()).size,0);
 assert.equal((await loadReadiness(db,organizationId,now)).ready,true);
 await db.doc('plannedUnavailability/boundary').set({organizationId,userId:orgAdminId,status:'active',startAt:new Date(now+1000),endAt:new Date(now+5000)});
 now+=1000;
 await Promise.all([engine.recompute(organizationId),engine.recompute(organizationId)]);
 let events=await db.collection('readinessNotificationEvents').get();assert.equal(events.size,1);
 assert.deepEqual(events.docs[0].data().keys,['readinessLost','belowMinimum','missingLevel2','memberOffDuty']);
 assert.equal((await loadReadiness(db,organizationId,now)).ready,false);
 await engine.recompute(organizationId);assert.equal((await db.collection('readinessNotificationEvents').get()).size,1);
 now+=4000;await engine.recompute(organizationId);events=await db.collection('readinessNotificationEvents').get();assert.equal(events.size,2);
 assert.equal((await loadReadiness(db,organizationId,now)).ready,true);
});


test('pack23 Tross member can respond with no II level and below SAR minimum',async()=>{
 const db=serverDb();
 for(const uid of [orgAdminId,activeMemberId,targetMemberId]) await db.doc(`memberships/${uid}_${organizationId}`).update({seaRescueLevel:'none'});
 await db.doc(`organizationReadinessSummaries/${organizationId}`).set({organizationId,minimumCrewRequired:3});
 await db.doc(`availability/${activeMemberId}_${organizationId}`).set({organizationId,userId:activeMemberId,status:'onDuty'});
 const readiness=await serverRequire('./organization-readiness').loadReadiness(db,organizationId,Date.now());
 assert.equal(readiness.ready,false);assert.equal(readiness.secondLevelMet,false);assert.equal(readiness.onDutyCount,1);
 const admin=testEnv.authenticatedContext(orgAdminId).firestore();
 await assertSucceeds(setDoc(doc(admin,'callouts/tross-ready'),calloutData('tross-ready',{calloutType:'tross',responseTargetMinutes:60})));
 const member=testEnv.authenticatedContext(activeMemberId).firestore(),id=`tross-ready_${activeMemberId}`;
 await assertSucceeds(setDoc(doc(member,`calloutResponses/${id}`),{id,calloutId:'tross-ready',userId:activeMemberId,userName:'Liige',organizationId,commandId:organizationId,response:'responding',responseMinutes:null,note:'',createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 assert.equal((await db.doc(`calloutResponses/${id}`).get()).data().response,'responding');
});

test('pack23 readiness invalidation is active-org scoped and platform inbox is platform-only',async()=>{
 const db=serverDb();
 await db.doc(`readinessNotificationState/${organizationId}`).set({operational:{ready:true}});
 const member=testEnv.authenticatedContext(activeMemberId).firestore();
 await assertSucceeds(getDoc(doc(member,`readinessNotificationState/${organizationId}`)));
 await assertFails(getDoc(doc(testEnv.authenticatedContext(otherUserId).firestore(),`readinessNotificationState/${organizationId}`)));
 await assertFails(setDoc(doc(member,`readinessNotificationState/${organizationId}`),{operational:{ready:true}}));
 await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
 await db.doc('userNotifications/platform-note').set({organizationId:'platform',recipientUserId:'platform-only',title:'New application'});
 const platform=testEnv.authenticatedContext('platform-only').firestore();
 await assertSucceeds(getDocs(query(collection(platform,'userNotifications'),where('organizationId','==','platform'),where('recipientUserId','==','platform-only'))));
 await assertFails(getDoc(doc(member,'userNotifications/platform-note')));
 await assertFails(getDoc(doc(platform,`readinessNotificationState/${organizationId}`)));
 await db.doc('users/platform-only').update({systemRole:'user'});
 await assertFails(getDoc(doc(platform,'userNotifications/platform-note')));
});

for (const recurring of [false, true]) {
  test(`own ${recurring ? 'recurring' : 'dated'} plan edits preserve tenant, owner and cancellation`, async () => {
    const db = testEnv.authenticatedContext(activeMemberId).firestore();
    const collectionName = recurring ? 'plannedUnavailabilityRules' : 'plannedUnavailability';
    const id = 'edit-own-plan';
    const ref = doc(db, collectionName, id);
    const times = recurring
      ? {daysOfWeek: [1, 3], startMinute: 480, endMinute: 600, startTime: '08:00', endTime: '10:00'}
      : {startAt: new Date('2026-10-01T08:00:00Z'), endAt: new Date('2026-10-01T10:00:00Z')};
    await assertSucceeds(setDoc(ref, {id, organizationId, commandId: organizationId,
      userId: activeMemberId, createdBy: activeMemberId, status: 'active', note: '',
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...times}));
    const edit = recurring
      ? {daysOfWeek: [2, 4], endMinute: 660, endTime: '11:00'}
      : {endAt: new Date('2026-10-01T11:00:00Z')};
    await assertSucceeds(updateDoc(ref, {...edit, note: 'Muudetud', updatedAt: serverTimestamp()}));
    for (const uid of [targetMemberId, orgAdminId, 'outsider']) {
      const foreign = testEnv.authenticatedContext(uid).firestore();
      await assertFails(updateDoc(doc(foreign, collectionName, id), {...edit, note: 'Võõras', updatedAt: serverTimestamp()}));
    }
    for (const bad of [
      {userId: targetMemberId}, {organizationId: otherOrganizationId, commandId: otherOrganizationId},
      {createdBy: targetMemberId}, {role: 'orgAdmin'}, {status: 'cancelled'},
      {note: 'x'.repeat(2001)},
      recurring ? {startTime: '09:00'} : {startAt: 'not-a-date'},
      recurring ? {endMinute: 1, endTime: '00:01'} : {endAt: new Date('2026-09-01T00:00:00Z')},
    ]) await assertFails(updateDoc(ref, {...bad, updatedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(ref, {status: 'cancelled', cancelledBy: activeMemberId,
      cancelledAt: serverTimestamp(), updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(ref, {...edit, note: 'Reactivate', updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(ref, {status: 'active', updatedAt: serverTimestamp()}));
  });
}

test('device alarm capability is optional, Android-only, and editable only by token owner', async () => {
  const db = testEnv.authenticatedContext(memberId).firestore();
  const ref = doc(db, 'userDeviceTokens', `${memberId}_alarm-test`);
  const token = {userId:memberId, token:'alarm-test', platform:'android', app:'respondcrew',
    enabled:true, createdAt:serverTimestamp(), updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(ref, token));
  await assertSucceeds(updateDoc(ref, {nativeSarAlarm:true, updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref, {nativeSarAlarm:'true', updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref, {platform:'ios', updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref, {platform:'ios', nativeSarAlarm:false, updatedAt:serverTimestamp()}));
  const otherDb = testEnv.authenticatedContext(otherUserId).firestore();
  await assertFails(updateDoc(doc(otherDb, 'userDeviceTokens', `${memberId}_alarm-test`),
    {nativeSarAlarm:false, updatedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db,'userDeviceTokens',`${memberId}_invalid-alarm`),
    {...token, platform:'ios', nativeSarAlarm:true}));
});

// These additions are server-only; existing default-deny rules must continue
// to prevent clients (including org admins) from forging history or work links.
test('equipment history and work links reject direct client reads and writes', async () => {
  for (const uid of [activeMemberId,orgAdminId]) {
    const client=testEnv.authenticatedContext(uid).firestore();
    for(const resource of ['equipment/example/history/change','equipmentWorkLinks/contribution_example']) {
      await assertFails(setDoc(doc(client,resource),{organizationId,equipmentId:'example',activityId:'contribution_example'}));
      await assertFails(getDoc(doc(client,resource)));
    }
  }
});

test('equipment care workflow joins real confirmed contributions without changing condition', async () => {
  const assert=require('node:assert/strict');
  const db=serverDb();
  const {createSetEquipmentCondition,createGetEquipmentCare,createEquipmentHistoryRecorder}=serverRequire('./equipment-care');
  const {createRecordContributionHandler}=serverRequire('./statistics-handlers');
  const ref=db.doc('equipment/care-boat');
  await ref.set({id:'care-boat',organizationId,commandId:organizationId,scope:'organization',name:'Care boat',category:'vessel',status:'ok',note:'',createdBy:orgAdminId,location:'Base'});
  const before=await ref.get();
  const timestamp=()=>new Date('2026-10-07T12:00:00Z');
  const change=createSetEquipmentCondition({db,timestamp});
  const data={organizationId,equipmentId:'care-boat',status:'broken',note:'Engine fault',expectedStatus:'ok',expectedNote:''};
  await assert.rejects(change({auth:{uid:activeMemberId},data}),{code:'permission-denied'});
  await change({auth:{uid:orgAdminId},data});
  const after=await ref.get();
  await createEquipmentHistoryRecorder({db})({id:'real-test-event',params:{equipmentId:'care-boat'},authType:'service_account',data:{before,after}});
  const record=createRecordContributionHandler({db,timestamp,now:()=>Date.parse('2026-10-07T12:00:00Z')});
  await record({auth:{uid:activeMemberId},data:{organizationId,equipmentId:'care-boat',requestId:'care-work',title:'Repair',description:'Changed part',type:'repair',date:'2026-10-06',hours:2.5,memberIds:[activeMemberId]}});
  const get=createGetEquipmentCare({db}),request={auth:{uid:activeMemberId},data:{organizationId,equipmentId:'care-boat'}};
  let result=await get(request);
  assert.equal(result.history.length,1);assert.equal(result.history[0].actorId,orgAdminId);assert.equal(result.works[0].confirmedHours,0);
  const admin=testEnv.authenticatedContext(orgAdminId).firestore();
  await assertSucceeds(updateDoc(doc(admin,`activityParticipants/contribution_care-work_${activeMemberId}`),{attendanceStatus:'confirmed',hours:2.5,confirmedBy:orgAdminId,confirmedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  result=await get(request);
  assert.equal(result.works[0].confirmedHours,2.5);assert.equal(result.status,'broken');
});

test('equipment requests require admin approval, are idempotent and do not cross organizations', async () => {
  const assert=require('node:assert/strict'),db=serverDb();
  const manage=serverRequire('./equipment-lifecycle').createEquipmentLifecycle({db,timestamp:()=>new Date()});
  const item={name:'Kuivülikond',category:'safety',status:'ok',location:'Liikme käes',nextMaintenanceDate:'',note:''};
  const req=(uid,action,id='request-one',extra={})=>({auth:{uid},data:{organizationId,action,id,item,...extra}});
  await assert.rejects(manage({data:{organizationId,action:'list'}}),{code:'unauthenticated'});
  await assert.rejects(manage(req(activeMemberId,'submit','invalid',{item:{...item,nextMaintenanceDate:'2026-02-30'}})),{code:'invalid-argument'});
  await manage(req(activeMemberId,'submit'));await manage(req(activeMemberId,'submit'));
  let pending=(await manage(req(orgAdminId,'list'))).requests;
  assert.equal(pending.length,1);const id=pending[0].id;
  assert.equal((await db.doc(`equipment/${id}`).get()).exists,false);
  await assert.rejects(manage(req(activeMemberId,'approve',id)),{code:'permission-denied'});
  await assert.rejects(manage(req(orgAdminId,'approve',id,{organizationId:otherOrganizationId})),{code:'permission-denied'});
  await assert.rejects(manage(req(otherUserId,'list')),{code:'permission-denied'});
  // Competing reviews cannot both succeed with contradictory outcomes.
  const results=await Promise.allSettled([manage(req(orgAdminId,'approve',id)),manage(req(orgAdminId,'reject',id))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal((await manage(req(activeMemberId,'list'))).requests.length,0);
  const status=(await db.doc(`equipmentRequests/${id}`).get()).data().status;
  assert.equal((await db.doc(`equipment/${id}`).get()).exists,status==='approved');
  if(status==='approved') {
    const e=(await db.doc(`equipment/${id}`).get()).data();assert.equal(e.assignedToUserId,activeMemberId);assert.equal(e.scope,'organization');
    await manage(req(orgAdminId,'approve',id));
    await assert.rejects(manage(req(activeMemberId,'delete',id)),{code:'permission-denied'});
  }
  // Admin self-entry uses the same path and directly issues the item to self.
  await manage(req(activeMemberId,'submit','member-approved'));
  const approvedId=(await manage(req(activeMemberId,'list'))).requests[0].id;
  await manage(req(orgAdminId,'approve',approvedId));
  await manage(req(orgAdminId,'approve',approvedId));
  const owned=(await db.doc(`equipment/${approvedId}`).get()).data();
  assert.equal(owned.assignedToUserId,activeMemberId);assert.equal(owned.scope,'organization');
  await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(activeMemberId).firestore(),'equipment',approvedId)));
  await assertFails(updateDoc(doc(testEnv.authenticatedContext(activeMemberId).firestore(),'equipment',approvedId),{scope:'personal',ownerUserId:activeMemberId}));
  await assertSucceeds(updateDoc(doc(testEnv.authenticatedContext(orgAdminId).firestore(),'equipment',approvedId),{name:'Kinnitatud ülikond',updatedAt:serverTimestamp()}));
  await manage(req(orgAdminId,'submit','admin-own'));
  const issued=(await db.collection('equipment').where('submittedBy','==',orgAdminId).get()).docs;
  assert.equal(issued.length,1);assert.equal(issued[0].data().assignedToUserId,orgAdminId);
  await manage(req(activeMemberId,'submit','cancel-own'));
  pending=(await manage(req(activeMemberId,'list'))).requests;
  await manage(req(activeMemberId,'cancel',pending[0].id));
  assert.equal((await manage(req(activeMemberId,'list'))).requests.length,0);
});

test('equipment deletion preserves audit and repair access; owner and tenant restrictions survive archival', async () => {
  const assert=require('node:assert/strict'),db=serverDb();
  const manage=serverRequire('./equipment-lifecycle').createEquipmentLifecycle({db,timestamp:()=>new Date()});
  const {createGetEquipmentCare,createSetEquipmentCondition}=serverRequire('./equipment-care');
  const get=createGetEquipmentCare({db}),set=createSetEquipmentCondition({db,timestamp:()=>new Date()});
  const req=(uid,id,extra={})=>({auth:{uid},data:{organizationId,action:'delete',id,equipmentId:id,...extra}});
  for(const [id,scope,owner] of [['delete-own','personal',activeMemberId],['delete-other','personal',orgAdminId],['delete-org','organization','']])
    await db.doc(`equipment/${id}`).set({id,organizationId,scope,ownerUserId:owner,name:id,status:'ok',note:''});
  await assert.rejects(manage(req(activeMemberId,'delete-other')),{code:'permission-denied'});
  await assert.rejects(manage(req(activeMemberId,'delete-org')),{code:'permission-denied'});
  await manage(req(activeMemberId,'delete-own'));await manage(req(activeMemberId,'delete-own'));
  assert.equal((await db.doc('equipment/delete-own').get()).exists,false);
  assert.equal((await db.doc('equipmentArchive/delete-own').get()).data().deletedBy,activeMemberId);
  const care=await get(req(activeMemberId,'delete-own'));assert.equal(care.archived,true);assert.equal(care.canEdit,false);assert.equal(care.history.length,1);
  await assert.rejects(get(req(targetMemberId,'delete-own')),{code:'permission-denied'});
  await assert.rejects(set(req(activeMemberId,'delete-own',{status:'ok',note:'',expectedStatus:'ok',expectedNote:''})),{code:'permission-denied'});
  await manage(req(orgAdminId,'delete-org'));
  assert.equal((await get(req(activeMemberId,'delete-org'))).archived,true);
  await db.doc(`memberships/${activeMemberId}_${organizationId}`).update({status:'removed',isActive:false});
  await assert.rejects(get(req(activeMemberId,'delete-own')),{code:'permission-denied'});
});

test('equipment requests and archives cannot be forged or read through direct clients', async () => {
  for(const uid of [activeMemberId,orgAdminId]) {
    const client=testEnv.authenticatedContext(uid).firestore();
    for(const path of ['equipmentRequests/request','equipmentArchive/item']) {
      await assertFails(setDoc(doc(client,path),{organizationId,status:'approved',submittedBy:uid}));
      await assertFails(getDoc(doc(client,path)));
    }
    await assertFails(deleteDoc(doc(client,'equipment','no-direct-delete')));
  }
});
