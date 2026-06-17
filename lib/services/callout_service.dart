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

  Stream<List<CalloutModel>> streamOrganizationCallouts({
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
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
          .where((callout) {
            final calloutOrganizationId = callout.organizationId.isNotEmpty
                ? callout.organizationId
                : callout.commandId;
            return calloutOrganizationId == organizationId;
          })
          .toList();

      callouts.sort((a, b) {
        final aTime = a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return callouts;
    });
  }

  Stream<List<CalloutModel>> streamActiveCallouts({
    required String organizationId,
  }) {
    return streamOrganizationCallouts(
      organizationId: organizationId,
    ).map(
      (callouts) => callouts
          .where((callout) => callout.status == CalloutStatus.active)
          .toList(growable: false),
    );
  }

  Stream<CalloutModel?> streamCallout({
    required String calloutId,
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    return _callouts.doc(calloutId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final callout = CalloutModel.fromFirestore(snapshot);
      final calloutOrganizationId = callout.organizationId.isNotEmpty
          ? callout.organizationId
          : callout.commandId;
      return calloutOrganizationId == organizationId ? callout : null;
    });
  }

  Stream<List<CalloutResponseModel>> streamCalloutResponses({
    required String calloutId,
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
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
    return streamCalloutResponseDetails(
      calloutId: calloutId,
      organizationId: organizationId,
    ).map((details) => details.summary);
  }

  Stream<CalloutResponseDetails> streamCalloutResponseDetails({
    required String calloutId,
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    late StreamController<CalloutResponseDetails> controller;
    StreamSubscription<List<CalloutResponseModel>>? responseSubscription;
    StreamSubscription<
            List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
        membershipSubscription;
    List<CalloutResponseModel>? responses;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? memberships;
    final displayNameCache = <String, String>{};
    var emissionVersion = 0;

    Future<void> emitDetails() async {
      if (responses == null || memberships == null || controller.isClosed) {
        return;
      }

      final currentVersion = ++emissionVersion;
      final memberIds = memberships!
          .map((membership) => (membership.data()['userId'] ?? '').toString())
          .where((userId) => userId.isNotEmpty)
          .toSet();
      final responsesByUserId = <String, CalloutResponseModel>{};
      final displayNames = Map<String, String>.from(displayNameCache);
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
        if (response.userName.trim().isNotEmpty) {
          displayNames[response.userId] = response.userName.trim();
        }
      }

      await Future.wait(
        memberIds.where((userId) => !displayNames.containsKey(userId)).map(
          (userId) async {
            try {
              final userSnapshot =
                  await _firestore.collection('users').doc(userId).get();
              final userData = userSnapshot.data() ?? <String, dynamic>{};
              final name = (userData['name'] ?? '').toString().trim();
              final email = (userData['email'] ?? '').toString().trim();
              displayNames[userId] =
                  name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Liige');
            } catch (_) {
              displayNames[userId] = 'Liige';
            }
            displayNameCache[userId] = displayNames[userId]!;
          },
        ),
      );

      if (currentVersion != emissionVersion || controller.isClosed) return;

      final responding = <CalloutResponseMember>[];
      final delayed = <CalloutResponseMember>[];
      final unavailable = <CalloutResponseMember>[];
      final noResponse = <CalloutResponseMember>[];

      for (final userId in memberIds) {
        final response = responsesByUserId[userId];
        final member = CalloutResponseMember(
          userId: userId,
          displayName: displayNames[userId] ?? 'Liige',
          response: response?.response ?? CalloutResponseValue.noResponse,
          responseMinutes: response?.responseMinutes,
          respondedAt: response?.updatedAt ?? response?.createdAt,
        );

        switch (member.response) {
          case CalloutResponseValue.responding:
            responding.add(member);
            break;
          case CalloutResponseValue.delayed:
            delayed.add(member);
            break;
          case CalloutResponseValue.unavailable:
            unavailable.add(member);
            break;
          default:
            noResponse.add(member);
        }
      }

      int compareMembers(
        CalloutResponseMember a,
        CalloutResponseMember b,
      ) =>
          a.displayName.compareTo(b.displayName);
      responding.sort(compareMembers);
      delayed.sort(compareMembers);
      unavailable.sort(compareMembers);
      noResponse.sort(compareMembers);

      controller.add(
        CalloutResponseDetails(
          responding: responding,
          delayed: delayed,
          unavailable: unavailable,
          noResponse: noResponse,
        ),
      );
    }

    void scheduleDetails() {
      emitDetails().catchError((Object error, StackTrace stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      });
    }

    controller = StreamController<CalloutResponseDetails>(
      onListen: () {
        responseSubscription = streamCalloutResponses(
          calloutId: calloutId,
          organizationId: organizationId,
        ).listen(
          (value) {
            responses = value;
            scheduleDetails();
          },
          onError: controller.addError,
        );
        membershipSubscription = _membershipService
            .streamActiveMembershipsForOrganization(organizationId)
            .listen(
          (value) {
            memberships = value;
            scheduleDetails();
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
    required String organizationId,
  }) {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedCalloutId = calloutId.trim();
    final trimmedUserId = userId.trim();

    _requireOrganizationId(trimmedOrganizationId);
    _requireCalloutId(trimmedCalloutId);
    _requireUserId(trimmedUserId);

    return _responses
        .where(
          FieldPath.documentId,
          isEqualTo: _responseId(trimmedCalloutId, trimmedUserId),
        )
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final response =
          CalloutResponseModel.fromFirestore(snapshot.docs.first);
      final responseOrganizationId = response.organizationId.isNotEmpty
          ? response.organizationId
          : response.commandId;
      return responseOrganizationId == trimmedOrganizationId ? response : null;
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
    final trimmedOrganizationId = organizationId.trim();
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    final trimmedLocation = location.trim();
    final trimmedPriority = priority.trim();
    final trimmedCreatedBy = createdBy.trim();
    final trimmedCreatedByName = createdByName.trim();

    _requireOrganizationId(trimmedOrganizationId);
    if (trimmedTitle.isEmpty) {
      throw Exception('Väljakutse pealkiri on kohustuslik');
    }

    if (trimmedCreatedBy.isEmpty) {
      throw Exception('Väljakutse looja puudub');
    }

    if (!CalloutPriority.values.contains(trimmedPriority)) {
      throw Exception('Väljakutse prioriteet ei ole toetatud');
    }

    final calloutDoc = _callouts.doc();
    final notificationDoc = _notifications.doc();
    final operationLogDoc =
        _operationLogs.doc('callout_${calloutDoc.id}_created');
    final operationLogCreatedEvent =
        operationLogDoc.collection('events').doc('created');
    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();
    final notificationMessage = trimmedLocation.isEmpty
        ? (trimmedDescription.isEmpty ? trimmedTitle : trimmedDescription)
        : (trimmedDescription.isEmpty
            ? trimmedLocation
            : '$trimmedLocation - $trimmedDescription');

    batch.set(calloutDoc, {
      'id': calloutDoc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all callout reads use organizationId.
      'commandId': trimmedOrganizationId,
      'title': trimmedTitle,
      'description': trimmedDescription,
      'location': trimmedLocation,
      'status': CalloutStatus.active,
      'priority': trimmedPriority,
      'createdBy': trimmedCreatedBy,
      'createdByName': trimmedCreatedByName,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'closedAt': null,
    });

    batch.set(notificationDoc, {
      'id': notificationDoc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all notification reads use organizationId.
      'commandId': trimmedOrganizationId,
      'title': 'Väljakutse: $trimmedTitle',
      'message': notificationMessage,
      'type': NotificationType.callout,
      'priority': NotificationPriority.high,
      'relatedType': 'callout',
      'relatedId': calloutDoc.id,
      'createdBy': trimmedCreatedBy,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });

    batch.set(operationLogDoc, {
      'id': operationLogDoc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all operation log reads use organizationId.
      'commandId': trimmedOrganizationId,
      'createdBy': trimmedCreatedBy,
      'createdByName': trimmedCreatedByName,
      'type': OperationLogType.note,
      'title': 'Väljakutse loodud: $trimmedTitle',
      'description': notificationMessage,
      'status': OperationLogStatus.open,
      'calloutId': calloutDoc.id,
      'timestamp': timestamp,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });

    batch.set(operationLogCreatedEvent, {
      'id': operationLogCreatedEvent.id,
      'organizationId': trimmedOrganizationId,
      'commandId': trimmedOrganizationId,
      'operationLogId': operationLogDoc.id,
      'type': OperationLogEventType.statusChange,
      'status': OperationLogStatus.open,
      'title': 'Avatud',
      'description': '',
      'createdBy': trimmedCreatedBy,
      'createdAt': timestamp,
    });

    await batch.commit();
  }

  Future<void> updateCalloutStatus({
    required String calloutId,
    required String organizationId,
    required String status,
  }) async {
    _requireOrganizationId(organizationId);
    if (status != CalloutStatus.closed && status != CalloutStatus.cancelled) {
      throw Exception('Unsupported callout status update: $status');
    }

    final doc = _callouts.doc(calloutId);
    final snapshot = await doc.get();
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Callout not found');
    }
    final calloutOrganizationId =
        (data['organizationId'] ?? data['commandId'] ?? '').toString();
    if (calloutOrganizationId != organizationId) {
      throw Exception('Callout belongs to another organization');
    }
    final currentStatus =
        (data['status'] ?? CalloutStatus.active).toString();
    if (currentStatus != CalloutStatus.active) {
      throw Exception('Väljakutse on juba lõpetatud');
    }

    await doc.set({
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
    final trimmedOrganizationId = organizationId.trim();
    final trimmedCalloutId = calloutId.trim();
    final trimmedUserId = userId.trim();
    final trimmedUserName = userName.trim();
    final trimmedResponse = response.trim();
    final trimmedNote = note.trim();

    _requireOrganizationId(trimmedOrganizationId);
    _requireCalloutId(trimmedCalloutId);
    _requireUserId(trimmedUserId);

    if (!CalloutResponseValue.values.contains(trimmedResponse) ||
        trimmedResponse == CalloutResponseValue.noResponse) {
      throw Exception('Väljakutse vastus ei ole toetatud');
    }

    if (trimmedResponse == CalloutResponseValue.delayed &&
        (responseMinutes == null || responseMinutes <= 0)) {
      throw Exception('Hilinemise puhul vali eeldatav viivitus');
    }

    final calloutSnapshot = await _callouts.doc(trimmedCalloutId).get();
    final calloutData = calloutSnapshot.data();
    if (calloutData == null) {
      throw Exception('Väljakutset ei leitud');
    }
    final calloutOrganizationId =
        (calloutData['organizationId'] ?? calloutData['commandId'] ?? '')
            .toString()
            .trim();
    if (calloutOrganizationId != trimmedOrganizationId) {
      throw Exception('Väljakutse kuulub teise organisatsiooni');
    }
    final calloutStatus =
        (calloutData['status'] ?? CalloutStatus.active).toString();
    if (calloutStatus != CalloutStatus.active) {
      throw Exception('Väljakutse on lõpetatud. Vastust ei saa enam muuta.');
    }

    final responseId = _responseId(trimmedCalloutId, trimmedUserId);
    await _responses.doc(responseId).set({
      'id': responseId,
      'calloutId': trimmedCalloutId,
      'userId': trimmedUserId,
      'userName': trimmedUserName,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all callout reads use organizationId.
      'commandId': trimmedOrganizationId,
      'response': trimmedResponse,
      'responseMinutes': trimmedResponse == CalloutResponseValue.delayed
          ? responseMinutes
          : null,
      'note': trimmedNote,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }
  }

  void _requireCalloutId(String calloutId) {
    if (calloutId.trim().isEmpty) {
      throw Exception('Väljakutse puudub');
    }
  }

  void _requireUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw Exception('Kasutaja puudub');
    }
  }

  String _responseId(String calloutId, String userId) => '${calloutId}_$userId';
}
