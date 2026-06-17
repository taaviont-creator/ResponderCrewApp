import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/availability_model.dart';
import '../models/notification_model.dart';

class AvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _availability =>
      _firestore.collection('availability');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _readinessSummaries =>
      _firestore.collection('organizationReadinessSummaries');

  String availabilityId({
    required String userId,
    required String organizationId,
  }) {
    return '${userId}_$organizationId';
  }

  Stream<AvailabilityModel?> streamMyAvailability({
    required String userId,
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    return _availability
        .doc(availabilityId(userId: userId, organizationId: organizationId))
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return AvailabilityModel.fromFirestore(snapshot);
    });
  }

  Stream<List<AvailabilityModel>> streamOrganizationAvailability({
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    return _availability
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after availability migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(AvailabilityModel.fromFirestore)
          .toList(growable: false);
    });
  }

  Future<void> setMyAvailability({
    required String userId,
    required String organizationId,
    required String memberName,
    required String status,
    int? responseMinutes,
    String? note,
  }) async {
    _requireOrganizationId(organizationId);
    if (!AvailabilityStatus.values.contains(status)) {
      throw Exception('Unsupported availability status: $status');
    }

    if (status == AvailabilityStatus.delayed &&
        (responseMinutes == null || responseMinutes <= 0)) {
      throw Exception('Hilinemise aeg on kohustuslik.');
    }

    final id = availabilityId(
      userId: userId,
      organizationId: organizationId,
    );
    final availabilityDoc = _availability.doc(id);
    final notificationDoc = _notifications.doc();
    final readinessNotificationDoc = _notifications.doc();
    final readinessSummaryDoc = _readinessSummaries.doc(organizationId);
    final trimmedMemberName =
        memberName.trim().isEmpty ? 'Liige' : memberName.trim();

    await _firestore.runTransaction((transaction) async {
      final availabilitySnapshot = await transaction.get(availabilityDoc);
      final readinessSnapshot = await transaction.get(readinessSummaryDoc);
      final previousStatus = availabilitySnapshot.exists
          ? (availabilitySnapshot.data()?['status'] ??
                  AvailabilityStatus.offDuty)
              .toString()
          : AvailabilityStatus.offDuty;

      transaction.set(availabilityDoc, {
        'id': id,
        'userId': userId,
        'organizationId': organizationId,
        // TODO: Remove commandId after all availability reads use
        // organizationId.
        'commandId': organizationId,
        'status': status,
        'responseMinutes':
            status == AvailabilityStatus.delayed ? responseMinutes : null,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (previousStatus == status) return;

      transaction.set(notificationDoc, {
        'id': notificationDoc.id,
        'organizationId': organizationId,
        // TODO: Remove commandId after all notification reads use
        // organizationId.
        'commandId': organizationId,
        'title': 'Valvesoleku muudatus',
        'message': _availabilityNotificationMessage(
          memberName: trimmedMemberName,
          status: status,
        ),
        'type': NotificationType.availability,
        'priority': NotificationPriority.normal,
        'relatedType': 'availability',
        'relatedId': id,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final wasOnDuty = previousStatus == AvailabilityStatus.onDuty;
      final isOnDuty = status == AvailabilityStatus.onDuty;
      if (!readinessSnapshot.exists || wasOnDuty == isOnDuty) return;

      final readinessData = readinessSnapshot.data()!;
      final previousOnDutyCount =
          _nonNegativeInt(readinessData['onDutyCount']);
      final minimumCrewRequired =
          _nonNegativeInt(readinessData['minimumCrewRequired']);
      if (minimumCrewRequired == 0) return;

      final onDutyCount = isOnDuty
          ? previousOnDutyCount + 1
          : (previousOnDutyCount > 0 ? previousOnDutyCount - 1 : 0);
      final wasMinimumCrewMet = readinessData['minimumCrewMet'] == true;
      final isMinimumCrewMet = onDutyCount >= minimumCrewRequired;

      transaction.set(readinessSummaryDoc, {
        'onDutyCount': onDutyCount,
        'minimumCrewMet': isMinimumCrewMet,
        'lastUpdatedBy': userId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (wasMinimumCrewMet == isMinimumCrewMet) return;

      transaction.set(readinessNotificationDoc, {
        'id': readinessNotificationDoc.id,
        'organizationId': organizationId,
        // TODO: Remove commandId after all notification reads use
        // organizationId.
        'commandId': organizationId,
        'title': isMinimumCrewMet
            ? 'Meeskond taastatud'
            : 'Meeskond alla miinimumi',
        'message': isMinimumCrewMet
            ? 'Valves olevate liikmete arv on taas miinimumi tasemel või '
                'üle selle. Valves: $onDutyCount / miinimum: '
                '$minimumCrewRequired'
            : 'Valves olevate liikmete arv langes alla määratud miinimumi. '
                'Valves: $onDutyCount / miinimum: $minimumCrewRequired',
        'type': NotificationType.minimumCrew,
        'priority': isMinimumCrewMet
            ? NotificationPriority.normal
            : NotificationPriority.high,
        'relatedType': 'organizationReadiness',
        'relatedId': organizationId,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  int _nonNegativeInt(Object? value) {
    final number = value is num ? value.toInt() : 0;
    return number < 0 ? 0 : number;
  }

  String _availabilityNotificationMessage({
    required String memberName,
    required String status,
  }) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return '$memberName märkis ennast valvesse.';
      case AvailabilityStatus.delayed:
        return '$memberName märkis, et hilineb reageerimisega.';
      default:
        return '$memberName märkis ennast mitte valvesse.';
    }
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }
  }
}
