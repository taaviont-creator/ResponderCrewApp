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
  runTransaction,
  writeBatch,
  serverTimestamp,
  setDoc,
  updateDoc,
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

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '..', 'firestore.rules'),
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

test('TROSS creates callout, notification and open log atomically; recorded departure remains separate', async () => {
  const db = testEnv.authenticatedContext(orgAdminId).firestore();
  const id='batch-tross', logId=`callout_${id}_created`;
  const batch=writeBatch(db);
  batch.set(doc(db,`callouts/${id}`),calloutData(id,{calloutType:'tross',responseTargetMinutes:60}));
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
  await assertFails(setDoc(doc(db,'callouts/fake-time'),calloutData('fake-time',{
    calloutType:'tross',responseTargetMinutes:60,createdAt:new Date('2020-01-01')})));
});

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
