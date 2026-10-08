const logger = require("firebase-functions/logger");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

const { onCall } = require('firebase-functions/v2/https');
const { createMemberContactHandler } = require('./member-contact');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const {createCenterAccessHandlers} = require('./center-access');
const centerAccessHandlers = createCenterAccessHandlers({db,
  timestamp: () => admin.firestore.FieldValue.serverTimestamp(),
  fromMillis: value => admin.firestore.Timestamp.fromMillis(value)});
for (const [name, handler] of Object.entries(centerAccessHandlers)) {
  exports[name] = onCall({region: 'europe-north1', maxInstances: 3, timeoutSeconds: 15}, handler);
}

const {createResponseUnitHandlers} = require('./response-units');
const responseUnitHandlers = createResponseUnitHandlers({db,
  timestamp: () => admin.firestore.FieldValue.serverTimestamp(),
  fromMillis: value => admin.firestore.Timestamp.fromMillis(value),
  geoPoint: (latitude,longitude) => new admin.firestore.GeoPoint(latitude,longitude)});
for (const [name, handler] of Object.entries(responseUnitHandlers)) {
  exports[name] = onCall({region:'europe-north1',maxInstances:3,timeoutSeconds:30}, handler);
}

const {defineSecret} = require('firebase-functions/params');
const {createOrganizationCenterReadinessHandlers}=require('./organization-center-readiness');
for (const [name,handler] of Object.entries(createOrganizationCenterReadinessHandlers({db,
  timestamp:()=>admin.firestore.FieldValue.serverTimestamp(),
  fromMillis:value=>admin.firestore.Timestamp.fromMillis(value)}))) {
  exports[name]=onCall({region:'europe-north1',maxInstances:3,timeoutSeconds:60},handler);
}
const {createCenterBoardHandlers}=require('./center-board');
for (const [name,handler] of Object.entries(createCenterBoardHandlers({db,timestamp:()=>admin.firestore.FieldValue.serverTimestamp()}))) {
  exports[name]=onCall({region:'europe-north1',maxInstances:3,timeoutSeconds:60},handler);
}
const {createOrganizationResponseSettingsHandlers}=require('./organization-response-settings');
for (const [name,handler] of Object.entries(require('./center-resources').createCenterResourceHandlers({db,
  timestamp:()=>admin.firestore.FieldValue.serverTimestamp()}))) {
  exports[name]=onCall({region:'europe-north1',maxInstances:3,timeoutSeconds:60},handler);
}
for (const [name,handler] of Object.entries(createOrganizationResponseSettingsHandlers({db,
  timestamp:()=>admin.firestore.FieldValue.serverTimestamp()}))) {
  exports[name]=onCall({region:'europe-north1',maxInstances:3,timeoutSeconds:30},handler);
}

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
const MAX_MULTICAST_TOKENS = 500;
const USER_QUERY_CHUNK_SIZE = 10;

const {createCalloutAlarmHandler} = require('./callout-alarm-delivery');
exports.sendCalloutAlarmNotification = onDocumentCreated(
  {document: 'callouts/{calloutId}', region: 'europe-north1', retry: false, maxInstances: 5},
  createCalloutAlarmHandler({db, loadMembers: loadActiveMemberUserIds,
    loadTokens: loadEnabledDeviceTokens, sendAlarm: sendCalloutAlarm, logger,
    filterRecipients: async (org,uids) => {
      const pairs = await Promise.all(uids.map(async uid => [uid,(await require('./notification-preferences').loadPreferences(db,org,uid,'member')).newCallout]));
      return pairs.filter(([,enabled])=>enabled).map(([uid])=>uid);
    }}),
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
        nativeSarAlarm: data.nativeSarAlarm === true,
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
  calloutType = 'sar',
  isTest = false,
}) {
  let successCount = 0;
  let failureCount = 0;
  const staleTokenDocumentIds = new Map();

  const {calloutDeliveryGroups} = require('./callout-notification-payload');
  for (const group of calloutDeliveryGroups(tokenRecords, calloutType)) {
    for (const tokenRecordChunk of chunkArray(group.records, MAX_MULTICAST_TOKENS)) {
      const message = require('./callout-notification-payload').calloutNotificationPayload({calloutId,organizationId,calloutType,isTest,
        nativeSarAlarm: group.nativeSarAlarm, tokens:tokenRecordChunk.map(record=>record.token)});

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

exports.getOrganizationReadinessPlanning = onCall(
  {region: 'europe-north1', maxInstances: 5, timeoutSeconds: 30},
  require('./readiness-planning').createReadinessPlanningHandler({db}),
);

exports.setCalloutTestStatus = onCall({region:'europe-north1', maxInstances:5, timeoutSeconds:30},
  require('./callout-test-status').createSetCalloutTestStatusHandler({db,timestamp:()=>admin.firestore.FieldValue.serverTimestamp()}));

exports.setNotificationPreference = onCall({region:'europe-north1', maxInstances:5, timeoutSeconds:30},
  require('./notification-preferences').createSetNotificationPreferenceHandler({db,timestamp:()=>admin.firestore.FieldValue.serverTimestamp()}));

const {createPersonalDelivery} = require('./personal-notifications');
const personalDelivery = createPersonalDelivery({db,messaging,loadTokens:loadEnabledDeviceTokens,logger});
const {createReadinessEngine,createReadinessDelivery} = require('./organization-readiness');
const readinessEngine = createReadinessEngine({db});
const geofence = require('./geofence').createGeofence({db});
exports.geofenceReadiness = onCall({region:'europe-north1',maxInstances:5,timeoutSeconds:60},geofence.handle);
exports.expireGeofenceReadiness = onSchedule({schedule:'every 1 minutes',region:'europe-west1',
  maxInstances:1,concurrency:1,timeoutSeconds:120,retryCount:0},geofence.expire);
exports.notifyGeofenceReturn = onDocumentWritten({document:'geofenceStates/{stateId}',region:'europe-north1',
  maxInstances:3,timeoutSeconds:60,retry:true}, async event=>{
  const before=event.data?.before.data(), after=event.data?.after.data();
  const returning=after?.enabled && after.confirmationRequired && !before?.confirmationRequired;
  const expired=before?.enabled && !after?.enabled && after?.reason==='stale';
  if(!returning && !expired) return;
  const current=(await db.doc(`geofenceStates/${event.params.stateId}`).get()).data();
  if(current?.sessionId!==after.sessionId || (returning && (!current.enabled || !current.confirmationRequired)) ||
    (expired && (current.enabled || current.reason!=='stale'))) return;
  await personalDelivery({sourceId:`geofence:${event.id}`,org:after.organizationId,uid:after.userId,
    title:expired?'Asukohapõhine valmisolek aegus':'Oled baasi lähedal. Kas oled valves?',
    body:expired?'24 tunni jooksul ei tulnud uut asukohakinnitust. Oled automaatika järgi mitte valves. Ava valmisolek ja kontrolli oma staatust.':
      'Ava valmisolek ja kinnita, kui saad reageerida. Automaatika ei märgi sind ise valvesse.',
    type:'availability',relatedType:'personalAvailability'});
});
for (const collection of ['availability','memberships','plannedUnavailability','plannedUnavailabilityRules','organizationReadinessSummaries']) {
  exports[`updateReadiness_${collection}`] = onDocumentWritten({document:`${collection}/{documentId}`,region:'europe-north1',
    maxInstances:3,timeoutSeconds:60,retry:true},readinessEngine.changed);
}
exports.updateReadiness_organization = onDocumentWritten({document:'commands/{organizationId}',region:'europe-north1',
  maxInstances:3,timeoutSeconds:120,retry:false},readinessEngine.sharedChanged);
for (const collection of ['equipment','organizationResponseSettings','organizationReadinessConfirmations','vesselIdentities','resourceAllocations']) {
  exports[`updateCenterReadiness_${collection}`] = onDocumentWritten({document:`${collection}/{documentId}`,region:'europe-north1',
    maxInstances:3,timeoutSeconds:120,retry:false},readinessEngine.sharedChanged);
}
exports.refreshScheduledReadiness = onSchedule({schedule:'every 1 minutes',timeZone:'Europe/Tallinn',region:'europe-west1',
  maxInstances:1,concurrency:1,timeoutSeconds:120,retryCount:0},readinessEngine.scheduled);
exports.sendReadinessChangeNotification = onDocumentCreated({document:'readinessNotificationEvents/{eventId}',region:'europe-north1',
  maxInstances:3,timeoutSeconds:120,retry:true},createReadinessDelivery({db,deliver:personalDelivery,preferencesFor:async(org,uid)=>{
    const member = (await db.doc(`memberships/${uid}_${org}`).get()).data();
    return require('./notification-preferences').loadPreferences(db,org,uid,member?.role);
  }}));

const applicationNotifications = require('./application-notifications');
exports.sendMemberRequestNotification = onDocumentWritten({document:'memberships/{membershipId}',region:'europe-north1',
  maxInstances:3,timeoutSeconds:120,retry:true},require('./member-request-notification').createMemberRequestHandler({db,messaging,loadTokens:loadEnabledDeviceTokens,logger}));
exports.sendMemberApplicationEmail = onDocumentWritten({...emailOptions,document:'memberships/{membershipId}'},
  applicationNotifications.createMemberApplicationEmail({db,auth:admin.auth(),logger,sendMail:async message => {
    const transport = smtpTransport(require('nodemailer'),smtpPassword.value());
    try { return await transport.sendMail(message); } finally { transport.close(); }
  }}));
exports.sendOrganizationApplicationNotification = onDocumentCreated({document:'commands/{organizationId}',region:'europe-north1',
  maxInstances:3,timeoutSeconds:120,retry:true},applicationNotifications.createOrganizationApplicationNotification({db,deliver:personalDelivery}));

const dispatch = require('./center-dispatch').createCenterDispatch({db,timestamp:()=>admin.firestore.FieldValue.serverTimestamp()});
exports.centerDispatch = onCall({region:'europe-north1',maxInstances:5,timeoutSeconds:60},dispatch.handle);
for (const [name,document] of Object.entries({syncDispatchCallout:'callouts/{calloutId}',syncDispatchLog:'operationLogs/{logId}',
  syncDispatchLogEvent:'operationLogs/{logId}/events/{eventId}',syncDispatchResponse:'calloutResponses/{responseId}',syncDispatchDelivery:'calloutPushDeliveries/{calloutId}'})) {
  exports[name] = onDocumentWritten({document,region:'europe-north1',maxInstances:3,timeoutSeconds:60,retry:true},dispatch.syncProgress);
}
exports.notifyDispatchUpdate = onDocumentCreated({document:'dispatchUpdateEvents/{eventId}',region:'europe-north1',maxInstances:3,timeoutSeconds:120,retry:true},async event=>{
  const d=event.data?.data(); if (!d) return;
  const callout=(await db.doc(`callouts/${d.calloutId}`).get()).data();
  if (callout?.dispatch?.incidentId!==d.incidentId || callout.organizationId!==d.organizationId || callout.dispatch.revision!==d.revision) return;
  const urgent=d.critical || (callout.dispatch.criticalRevision || 0)>(callout.dispatch.acknowledgedRevision || 0);
  const uids=await loadActiveMemberUserIds(d.organizationId);
  await Promise.all(uids.map(uid=>personalDelivery({sourceId:`dispatch:${event.params.eventId}`,org:d.organizationId,uid,
    title:urgent?'Keskuse oluline muudatus':'Keskus täiendas väljakutset',body:'Ava väljakutse ja vaata värsket infot.',
    type:'callout',relatedType:'callout',pushType:'callout_update',urgent,relatedId:d.calloutId,preferenceKeys:['newCallout']})));
});

const equipmentCare = require('./equipment-care');
exports.manageEquipment = onCall(statisticsCallableOptions, require('./equipment-lifecycle').createEquipmentLifecycle(workflowDependencies));
exports.setEquipmentCondition = onCall(statisticsCallableOptions, equipmentCare.createSetEquipmentCondition(workflowDependencies));
exports.getEquipmentCare = onCall(statisticsCallableOptions, equipmentCare.createGetEquipmentCare({db}));
exports.recordEquipmentHistory = onDocumentWrittenWithAuthContext({document:'equipment/{equipmentId}',region:'europe-north1',retry:true,maxInstances:5},equipmentCare.createEquipmentHistoryRecorder({db}));
