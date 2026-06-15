import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/callout_model.dart';
import '../models/notification_model.dart';
import '../models/operation_log_model.dart';

class CalloutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _callouts =>
      _firestore.collection('callouts');

  CollectionReference<Map<String, dynamic>> get _responses =>
      _firestore.collection('calloutResponses');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _operationLogs =>
      _firestore.collection('operationLogs');

  Stream<List<CalloutModel>> streamActiveCallouts({
    required String organizationId,
  }) {
    return _callouts
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after callout migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      final callouts = snapshot.docs
          .map(CalloutModel.fromFirestore)
          .where((callout) => callout.status == CalloutStatus.active)
          .toList();

      callouts.sort((a, b) {
        final aTime =
            a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return callouts;
    });
  }

  Stream<List<CalloutResponseModel>> streamCalloutResponses({
    required String calloutId,
  }) {
    return _responses
        .where('calloutId', isEqualTo: calloutId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(CalloutResponseModel.fromFirestore).toList();
    });
  }

  Stream<CalloutResponseModel?> streamMyResponse({
    required String calloutId,
    required String userId,
  }) {
    return _responses
        .where('calloutId', isEqualTo: calloutId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CalloutResponseModel.fromFirestore(snapshot.docs.first);
    });
  }

  Future<void> addCallout({
    required String organizationId,
    required String title,
    required String description,
    required String location,
    required String priority,
    required String createdBy,
    required String createdByName,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('Callout title is required');
    }

    if (!CalloutPriority.values.contains(priority)) {
      throw Exception('Unsupported callout priority: $priority');
    }

    final calloutDoc = _callouts.doc();
    final notificationDoc = _notifications.doc();
    final operationLogDoc =
        _operationLogs.doc('callout_${calloutDoc.id}_created');
    final batch = _firestore.batch();
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    final trimmedLocation = location.trim();
    final trimmedCreatedByName = createdByName.trim();
    final notificationMessage = trimmedLocation.isEmpty
        ? (trimmedDescription.isEmpty ? trimmedTitle : trimmedDescription)
        : (trimmedDescription.isEmpty
            ? trimmedLocation
            : '$trimmedLocation - $trimmedDescription');

    batch.set(calloutDoc, {
      'id': calloutDoc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all callout reads use organizationId.
      'commandId': organizationId,
      'title': trimmedTitle,
      'description': trimmedDescription,
      'location': trimmedLocation,
      'status': CalloutStatus.active,
      'priority': priority,
      'createdBy': createdBy,
      'createdByName': trimmedCreatedByName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': null,
    });

    batch.set(notificationDoc, {
      'id': notificationDoc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all notification reads use organizationId.
      'commandId': organizationId,
      'title': 'Valjakutse: $trimmedTitle',
      'message': notificationMessage,
      'type': NotificationType.callout,
      'priority': NotificationPriority.high,
      'relatedType': 'callout',
      'relatedId': calloutDoc.id,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(operationLogDoc, {
      'id': operationLogDoc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all operation log reads use organizationId.
      'commandId': organizationId,
      'createdBy': createdBy,
      'createdByName': trimmedCreatedByName,
      'type': OperationLogType.note,
      'title': 'Väljakutse loodud: $trimmedTitle',
      'description': notificationMessage,
      'calloutId': calloutDoc.id,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> updateCalloutStatus({
    required String calloutId,
    required String status,
  }) async {
    if (status != CalloutStatus.closed && status != CalloutStatus.cancelled) {
      throw Exception('Unsupported callout status update: $status');
    }

    await _callouts.doc(calloutId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setMyResponse({
    required String calloutId,
    required String userId,
    required String userName,
    required String organizationId,
    required String response,
    int? responseMinutes,
    String note = '',
  }) async {
    if (!CalloutResponseValue.values.contains(response) ||
        response == CalloutResponseValue.noResponse) {
      throw Exception('Unsupported callout response: $response');
    }

    if (response == CalloutResponseValue.delayed &&
        (responseMinutes == null || responseMinutes <= 0)) {
      throw Exception('Delayed response requires response minutes');
    }

    final responseId = '${calloutId}_$userId';
    await _responses.doc(responseId).set({
      'id': responseId,
      'calloutId': calloutId,
      'userId': userId,
      'userName': userName.trim(),
      'organizationId': organizationId,
      // TODO: Remove commandId after all callout reads use organizationId.
      'commandId': organizationId,
      'response': response,
      'responseMinutes':
          response == CalloutResponseValue.delayed ? responseMinutes : null,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
