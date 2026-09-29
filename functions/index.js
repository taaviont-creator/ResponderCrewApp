const logger = require("firebase-functions/logger");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { createMemberRequestHandler } = require('./member-request-notification');
const admin = require("firebase-admin");

const { onCall } = require('firebase-functions/v2/https');
const { createMemberContactHandler } = require('./member-contact');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const {defineSecret} = require('firebase-functions/params');
const {createEmailHandlers, smtpTransport} = require('./transactional-email');
const smtpPassword = defineSecret('RESPONDCREW_SMTP_PASSWORD');
const emailHandlers = createEmailHandlers({
  db, auth: admin.auth(), logger,
  sendMail: async message => {
    const transport = smtpTransport(require('nodemailer'), smtpPassword.value());
    try { return await transport.sendMail(message); }
    finally { transport.close(); }
  },
});
const emailOptions = {region: 'europe-north1', maxInstances: 2, concurrency: 1,
  timeoutSeconds: 120, memory: '256MiB', retry: true, secrets: [smtpPassword]};
exports.sendOrganizationInviteEmail = onDocumentCreated(
  {...emailOptions, document: 'organizationInvites/{inviteId}'},
  emailHandlers.sendOrganizationInviteEmail,
);
exports.sendOrganizationApplicationEmail = onDocumentCreated(
  {...emailOptions, document: 'commands/{organizationId}'},
  emailHandlers.sendOrganizationApplicationEmail,
);

exports.getOrganizationMemberContact = onCall(
  {region: 'europe-north1', maxInstances: 5, timeoutSeconds: 15},
  createMemberContactHandler({db}),
);

const APP_ID = "respondcrew";
const CALLOUT_ALARM_CHANNEL_ID = "callout_alarm";
const MAX_MULTICAST_TOKENS = 500;
const USER_QUERY_CHUNK_SIZE = 10;

exports.sendMemberRequestNotification = onDocumentWritten(
  {document: 'memberships/{membershipId}', region: 'europe-north1', retry: false},
  createMemberRequestHandler({db, messaging, logger, loadTokens: loadEnabledDeviceTokens}),
);

const {createCalloutAlarmHandler} = require('./callout-alarm-delivery');
exports.sendCalloutAlarmNotification = onDocumentCreated(
  {document: 'callouts/{calloutId}', region: 'europe-north1', retry: false, maxInstances: 5},
  createCalloutAlarmHandler({db, loadMembers: loadActiveMemberUserIds,
    loadTokens: loadEnabledDeviceTokens, sendAlarm: sendCalloutAlarm, logger}),
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
      (!membership.commandId || membership.commandId === organizationId) &&
      doc.id === `${userId}_${organizationId}` &&
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
        documentId: doc.id,
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
  const staleTokenDocumentIds = new Map();

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
          tag: calloutId,
          title: "V\u00e4ljakutse",
          body: "Uus v\u00e4ljakutse vajab reageerimist",
        },
      },
      apns: {
        headers: {'apns-collapse-id': require('node:crypto').createHash('sha256').update(calloutId).digest('hex')},
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

      const staleToken = isInvalidTokenError(errorCode);
      if (staleToken && tokenRecord.documentId) {
        staleTokenDocumentIds.set(tokenRecord.documentId, tokenRecord.token);
      }

      logger.warn("Failed to send callout alarm push", {
        calloutId,
        organizationId,
        errorCode,
        userId: tokenRecord.userId,
        platform: tokenRecord.platform,
        staleToken,
      });
    });
  }

  if (staleTokenDocumentIds.size > 0) {
    await Promise.all(
      [...staleTokenDocumentIds].map(async ([documentId, failedToken]) => {
        try {
          await db.runTransaction(async tx => {
            const ref = db.collection("userDeviceTokens").doc(documentId);
            const current = await tx.get(ref);
            if (current.data()?.token === failedToken) tx.delete(ref);
          });
        } catch (error) {
          logger.warn("Failed to delete stale callout device token", {
            documentId,
            error: error && error.message,
          });
        }
      }),
    );
  }

  logger.info("Callout alarm push send finished", {
    calloutId,
    organizationId,
    tokenCount: tokenRecords.length,
    successCount,
    failureCount,
    staleTokenCount: staleTokenDocumentIds.size,
  });
  return {successCount, failureCount};
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
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {createCertificateReminderJob} = require('./certificate-reminders');
exports.sendCertificateExpiryReminders = onSchedule({
  schedule: '0 9 * * *', timeZone: 'Europe/Tallinn', region: 'europe-west1',
  maxInstances: 1, concurrency: 1, timeoutSeconds: 540, memory: '256MiB', retryCount: 0,
}, createCertificateReminderJob({db, messaging, logger, loadTokens: loadEnabledDeviceTokens}));

const {createHistoryHandler} = require('./statistics-history');
const {createStatisticsHandler, createRecordContributionHandler, createCalloutAttendanceHandler} = require('./statistics-handlers');
const statisticsCallableOptions = {region:'europe-north1', maxInstances:5, timeoutSeconds:60, memory:'512MiB'};
const {createGetReportHandler,createSaveReportHandler,createAmendCalloutHandler} = require('./callout-report');
const {createMembershipManagementHandler,createDutyHandler,createPlatformOverviewHandler,createPlatformStatusHandler,createPlatformAccountsHandler,createRevokeSessionsHandler} = require('./organization-management');
const workflowDependencies = {db,timestamp:admin.firestore.FieldValue.serverTimestamp};
const {createSaveOrganizationProfileHandler} = require('./organization-profile');
exports.saveOrganizationProfile = onCall(statisticsCallableOptions, createSaveOrganizationProfileHandler(workflowDependencies));
exports.getCalloutReport = onCall(statisticsCallableOptions, createGetReportHandler({db}));
exports.saveCalloutReport = onCall(statisticsCallableOptions, createSaveReportHandler(workflowDependencies));
exports.amendCallout = onCall(statisticsCallableOptions, createAmendCalloutHandler(workflowDependencies));
exports.manageOrganizationMembership = onCall(statisticsCallableOptions, createMembershipManagementHandler(workflowDependencies));
exports.setOrganizationDuty = onCall(statisticsCallableOptions, createDutyHandler(workflowDependencies));
exports.getPlatformOverview = onCall(statisticsCallableOptions, createPlatformOverviewHandler({db}));
exports.setPlatformOrganizationStatus = onCall(statisticsCallableOptions, createPlatformStatusHandler(workflowDependencies));
exports.getPlatformAccounts = onCall(statisticsCallableOptions, createPlatformAccountsHandler({db,auth:admin.auth()}));
exports.revokeAccountSessions = onCall(statisticsCallableOptions, createRevokeSessionsHandler({...workflowDependencies,auth:admin.auth()}));
const {onDocumentWrittenWithAuthContext} = require('firebase-functions/v2/firestore');
const {createAdministrativeAudit} = require('./administrative-audit');
for (const [name,source] of Object.entries({auditOrganizations:'commands',auditMemberships:'memberships',auditCallouts:'callouts',auditOperationLogs:'operationLogs'})) {
  exports[name] = onDocumentWrittenWithAuthContext({document:`${source}/{documentId}`,region:'europe-north1',retry:true,maxInstances:5},createAdministrativeAudit({db,source}));
}
exports.getContributionStatistics = onCall(statisticsCallableOptions, createStatisticsHandler({db}));
exports.recordMemberContribution = onCall(statisticsCallableOptions, createRecordContributionHandler({db, timestamp:admin.firestore.FieldValue.serverTimestamp}));
exports.saveCalloutAttendance = onCall(statisticsCallableOptions, createCalloutAttendanceHandler({db, timestamp:admin.firestore.FieldValue.serverTimestamp}));
for (const [name, source] of Object.entries({
  recordAvailabilityHistory:'availability', recordMembershipHistory:'memberships',
  recordAbsenceHistory:'plannedUnavailability', recordAbsenceRuleHistory:'plannedUnavailabilityRules',
})) {
  exports[name] = onDocumentWritten({document:`${source}/{documentId}`, region:'europe-north1', retry:true, maxInstances:5}, createHistoryHandler({db, source}));
}

const {createAttachmentHandlers} = require('./callout-attachments');
const attachmentHandlers = createAttachmentHandlers({db, bucket:admin.storage().bucket('respondcrew.firebasestorage.app'), timestamp:()=>admin.firestore.FieldValue.serverTimestamp()});
const attachmentOptions = {region:'europe-north1', maxInstances:3, concurrency:2, timeoutSeconds:120, memory:'512MiB'};
exports.uploadCalloutAttachment = onCall(attachmentOptions, attachmentHandlers.upload);
exports.downloadCalloutAttachment = onCall(attachmentOptions, attachmentHandlers.download);

const {createReadinessAvailabilityHandler} = require('./readiness-availability');
exports.getOrganizationReadinessAvailability = onCall(
  {region: 'europe-north1', maxInstances: 5, timeoutSeconds: 30},
  createReadinessAvailabilityHandler({db}),
);
