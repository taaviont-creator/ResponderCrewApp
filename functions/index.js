const logger = require("firebase-functions/logger");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const APP_ID = "respondcrew";
const CALLOUT_ALARM_CHANNEL_ID = "callout_alarm";
const MAX_MULTICAST_TOKENS = 500;
const USER_QUERY_CHUNK_SIZE = 10;

exports.sendCalloutAlarmNotification = onDocumentCreated(
  "callouts/{calloutId}",
  async (event) => {
    const snapshot = event.data;
    const calloutId = event.params.calloutId;

    if (!snapshot) {
      logger.warn("Callout create event missing snapshot", { calloutId });
      return;
    }

    const createdCallout = snapshot.data();
    if (createdCallout.status !== "active") {
      logger.info("Skipping non-active callout create", {
        calloutId,
        status: createdCallout.status,
      });
      return;
    }

    const organizationId = organizationIdFromData(createdCallout);
    if (!organizationId) {
      logger.warn("Skipping callout without organization id", { calloutId });
      return;
    }

    const latestSnapshot = await snapshot.ref.get();
    if (!latestSnapshot.exists) {
      logger.info("Skipping deleted callout before push send", { calloutId });
      return;
    }

    const latestCallout = latestSnapshot.data();
    if (
      latestCallout.status !== "active" ||
      organizationIdFromData(latestCallout) !== organizationId
    ) {
      logger.info("Skipping callout that changed before push send", {
        calloutId,
        status: latestCallout.status,
      });
      return;
    }

    const userIds = await loadActiveMemberUserIds(organizationId);
    if (userIds.length === 0) {
      logger.info("No active members for callout alarm", {
        calloutId,
        organizationId,
      });
      return;
    }

    const tokenRecords = await loadEnabledDeviceTokens(userIds);
    if (tokenRecords.length === 0) {
      logger.info("No enabled device tokens for callout alarm", {
        calloutId,
        organizationId,
        memberCount: userIds.length,
      });
      return;
    }

    // TODO: Add idempotent delivery tracking, for example
    // calloutPushDeliveries/{calloutId}, before broad production rollout.
    await sendCalloutAlarm({
      calloutId,
      organizationId,
      tokenRecords,
    });
  },
);

async function loadActiveMemberUserIds(organizationId) {
  const [organizationSnapshot, legacySnapshot] = await Promise.all([
    db
      .collection("memberships")
      .where("organizationId", "==", organizationId)
      .get(),
    db.collection("memberships").where("commandId", "==", organizationId).get(),
  ]);

  const membershipsById = new Map();
  for (const doc of organizationSnapshot.docs) {
    membershipsById.set(doc.id, doc);
  }
  for (const doc of legacySnapshot.docs) {
    membershipsById.set(doc.id, doc);
  }

  const userIds = new Set();
  for (const doc of membershipsById.values()) {
    const membership = doc.data();
    const membershipOrganizationId = organizationIdFromData(membership);
    const userId = stringValue(membership.userId);

    if (
      membershipOrganizationId === organizationId &&
      userId &&
      isActiveMembership(membership)
    ) {
      userIds.add(userId);
    }
  }

  return [...userIds];
}

async function loadEnabledDeviceTokens(userIds) {
  const userIdSet = new Set(userIds);
  const tokenRecordsByToken = new Map();

  for (const userIdChunk of chunkArray(userIds, USER_QUERY_CHUNK_SIZE)) {
    const snapshot = await db
      .collection("userDeviceTokens")
      .where("userId", "in", userIdChunk)
      .where("enabled", "==", true)
      .where("app", "==", APP_ID)
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const userId = stringValue(data.userId);
      const token = stringValue(data.token);

      if (!userIdSet.has(userId) || !token) continue;

      tokenRecordsByToken.set(token, {
        token,
        userId,
        platform: stringValue(data.platform),
      });
    }
  }

  return [...tokenRecordsByToken.values()];
}

async function sendCalloutAlarm({
  calloutId,
  organizationId,
  tokenRecords,
}) {
  let successCount = 0;
  let failureCount = 0;

  for (const tokenRecordChunk of chunkArray(
    tokenRecords,
    MAX_MULTICAST_TOKENS,
  )) {
    const message = {
      tokens: tokenRecordChunk.map((record) => record.token),
      notification: {
        title: "V\u00e4ljakutse",
        body: "Uus v\u00e4ljakutse vajab reageerimist",
      },
      data: {
        type: "callout_alarm",
        relatedType: "callout",
        calloutId,
        relatedId: calloutId,
        organizationId,
        channelId: CALLOUT_ALARM_CHANNEL_ID,
      },
      android: {
        priority: "high",
        notification: {
          channelId: CALLOUT_ALARM_CHANNEL_ID,
          title: "V\u00e4ljakutse",
          body: "Uus v\u00e4ljakutse vajab reageerimist",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((sendResponse, index) => {
      if (sendResponse.success) return;

      const errorCode = sendResponse.error && sendResponse.error.code;
      const tokenRecord = tokenRecordChunk[index];

      logger.warn("Failed to send callout alarm push", {
        calloutId,
        organizationId,
        errorCode,
        userId: tokenRecord.userId,
        platform: tokenRecord.platform,
        staleToken: isInvalidTokenError(errorCode),
      });
    });
  }

  logger.info("Callout alarm push send finished", {
    calloutId,
    organizationId,
    tokenCount: tokenRecords.length,
    successCount,
    failureCount,
  });
}

function organizationIdFromData(data) {
  return stringValue(data.organizationId) || stringValue(data.commandId);
}

function isActiveMembership(data) {
  const hasStatus = Object.prototype.hasOwnProperty.call(data, "status");
  const hasIsActive = Object.prototype.hasOwnProperty.call(data, "isActive");
  const hasActiveMarker = data.status === "active" || data.isActive === true;
  const statusIsActive = !hasStatus || data.status === "active";
  const flagIsActive = !hasIsActive || data.isActive === true;

  return hasActiveMarker && statusIsActive && flagIsActive;
}

function stringValue(value) {
  return typeof value === "string" && value.trim() ? value.trim() : "";
}

function chunkArray(values, size) {
  const chunks = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

function isInvalidTokenError(errorCode) {
  return (
    errorCode === "messaging/registration-token-not-registered" ||
    errorCode === "messaging/invalid-registration-token"
  );
}
