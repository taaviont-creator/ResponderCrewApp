import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/availability_model.dart';
import '../models/notification_model.dart';

class AvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _availability =>
      _firestore.collection('availability');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

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
    if (!AvailabilityStatus.values.contains(status)) {
      throw Exception('Unsupported availability status: $status');
    }

    final id = availabilityId(
      userId: userId,
      organizationId: organizationId,
    );
    final availabilityDoc = _availability.doc(id);
    final notificationDoc = _notifications.doc();
    final trimmedMemberName =
        memberName.trim().isEmpty ? 'Liige' : memberName.trim();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(availabilityDoc);
      final previousStatus = snapshot.exists
          ? (snapshot.data()?['status'] ?? AvailabilityStatus.offDuty)
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
    });
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
}
