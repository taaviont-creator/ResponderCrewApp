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

test('member can reactivate only their own removed membership', async () => {
  const firestore = testEnv.authenticatedContext(memberId).firestore();

  await assertSucceeds(
    updateDoc(
      doc(firestore, 'memberships', membershipId),
      reactivatedMembership(),
    ),
  );
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
