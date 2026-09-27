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
  serverTimestamp,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-respondcrew';
const organizationId = 'approved-org';
const memberId = 'member-user';
const otherUserId = 'other-user';
const orgAdminId = 'org-admin';
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
  const { setDoc } = require('firebase/firestore');
  await setDoc(doc(firestore, documentPath), data);
}
