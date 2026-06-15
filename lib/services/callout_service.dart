import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/callout_model.dart';
import '../models/notification_model.dart';
import '../models/operation_log_model.dart';
import 'membership_service.dart';

class CalloutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MembershipService _membershipService = MembershipService();

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
    required String organizationId,
  }) {
    return _responses
        .where('calloutId', isEqualTo: calloutId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(CalloutResponseModel.fromFirestore)
          .where((response) {
        final responseOrganizationId = response.organizationId.isNotEmpty
            ? response.organizationId
            : response.commandId;
        return responseOrganizationId == organizationId;
      }).toList();
    });
  }

  Stream<CalloutResponseSummary> streamCalloutResponseSummary({
    required String calloutId,
    required String organizationId,
  }) {
    late StreamController<CalloutResponseSummary> controller;
    StreamSubscription<List<CalloutResponseModel>>? responseSubscription;
    StreamSubscription<
            List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
        membershipSubscription;
    List<CalloutResponseModel>? responses;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? memberships;

    void emitSummary() {
      if (responses == null || memberships == null || controller.isClosed) {
        return;
      }

      final memberIds = memberships!
          .map((membership) => (membership.data()['userId'] ?? '').toString())
          .where((userId) => userId.isNotEmpty)
          .toSet();
      final responsesByUserId = <String, CalloutResponseModel>{};
      for (final response in responses!) {
        if (response.userId.isEmpty || !memberIds.contains(response.userId)) {
          continue;
        }
        if (response.response != CalloutResponseValue.responding &&
            response.response != CalloutResponseValue.delayed &&
            response.response != CalloutResponseValue.unavailable) {
          continue;
        }
        responsesByUserId[response.userId] = response;
      }

      var responding = 0;
      var delayed = 0;
      var unavailable = 0;
      for (final response in responsesByUserId.values) {
        switch (response.response) {
          case CalloutResponseValue.responding:
            responding++;
            break;
          case CalloutResponseValue.delayed:
            delayed++;
            break;
          case CalloutResponseValue.unavailable:
            unavailable++;
            break;
        }
      }

      controller.add(
        CalloutResponseSummary(
          responding: responding,
          delayed: delayed,
          unavailable: unavailable,
          noResponse: memberIds.length - responsesByUserId.length,
        ),
      );
    }

    controller = StreamController<CalloutResponseSummary>(
      onListen: () {
        responseSubscription = streamCalloutResponses(
          calloutId: calloutId,
          organizationId: organizationId,
        ).listen(
          (value) {
            responses = value;
            emitSummary();
          },
          onError: controller.addError,
        );
        membershipSubscription = _membershipService
            .streamActiveMembershipsForOrganization(organizationId)
            .listen(
          (value) {
            memberships = value;
            emitSummary();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await responseSubscription?.cancel();
        await membershipSubscription?.cancel();
      },
    );

    return controller.stream;
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
    final operationLogCreatedEvent =
        operationLogDoc.collection('events').doc('created');
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
      'status': OperationLogStatus.created,
      'calloutId': calloutDoc.id,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(operationLogCreatedEvent, {
      'id': operationLogCreatedEvent.id,
      'organizationId': organizationId,
      'commandId': organizationId,
      'operationLogId': operationLogDoc.id,
      'type': OperationLogEventType.statusChange,
      'status': OperationLogStatus.created,
      'title': 'Logi loodud',
      'description': '',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
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
