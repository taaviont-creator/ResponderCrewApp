import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _notificationReads =>
      _firestore.collection('notificationReads');

  Stream<List<NotificationModel>> streamOrganizationNotifications({
    required String organizationId,
  }) {
    return _notifications
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after notification migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      final notifications =
          snapshot.docs.map(NotificationModel.fromFirestore).toList();

      notifications.sort((a, b) {
        final aTime =
            a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return notifications;
    });
  }

  Future<void> addNotification({
    required String organizationId,
    required String title,
    required String message,
    required String type,
    required String priority,
    required String createdBy,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('Notification title is required');
    }

    if (message.trim().isEmpty) {
      throw Exception('Notification message is required');
    }

    if (!NotificationType.values.contains(type)) {
      throw Exception('Unsupported notification type: $type');
    }

    if (!NotificationPriority.values.contains(priority)) {
      throw Exception('Unsupported notification priority: $priority');
    }

    final doc = _notifications.doc();

    await doc.set({
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all notification reads use organizationId.
      'commandId': organizationId,
      'title': title.trim(),
      'message': message.trim(),
      'type': type,
      'priority': priority,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead({
    required String notificationId,
    required String userId,
    required String organizationId,
  }) async {
    final readId = '${notificationId}_$userId';

    await _notificationReads.doc(readId).set(
      {
        'id': readId,
        'notificationId': notificationId,
        'userId': userId,
        'organizationId': organizationId,
        // TODO: Remove commandId after all notification reads use organizationId.
        'commandId': organizationId,
        'readAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
