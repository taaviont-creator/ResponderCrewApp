import 'dart:async';

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

  Stream<Set<String>> streamMyReadNotificationIds({
    required String userId,
    required String organizationId,
  }) {
    return _notificationReads
        .where('userId', isEqualTo: userId)
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(NotificationReadModel.fromFirestore)
          .map((read) => read.notificationId)
          .where((notificationId) => notificationId.isNotEmpty)
          .toSet();
    });
  }

  Stream<int> streamUnreadNotificationCount({
    required String userId,
    required String organizationId,
  }) {
    late StreamController<int> controller;
    StreamSubscription<List<NotificationModel>>? notificationsSubscription;
    StreamSubscription<Set<String>>? readsSubscription;
    List<NotificationModel>? notifications;
    Set<String>? readNotificationIds;

    void emitCount() {
      if (notifications == null ||
          readNotificationIds == null ||
          controller.isClosed) {
        return;
      }

      controller.add(
        notifications!
            .where(
              (notification) =>
                  !readNotificationIds!.contains(notification.id),
            )
            .length,
      );
    }

    controller = StreamController<int>(
      onListen: () {
        notificationsSubscription = streamOrganizationNotifications(
          organizationId: organizationId,
        ).listen(
          (value) {
            notifications = value;
            emitCount();
          },
          onError: controller.addError,
        );

        readsSubscription = streamMyReadNotificationIds(
          userId: userId,
          organizationId: organizationId,
        ).listen(
          (value) {
            readNotificationIds = value;
            emitCount();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await notificationsSubscription?.cancel();
        await readsSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> addNotification({
    required String organizationId,
    required String title,
    required String message,
    required String type,
    required String priority,
    required String createdBy,
    String? relatedType,
    String? relatedId,
    String? notificationId,
    bool createOnlyIfMissing = false,
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

    final requestedNotificationId = notificationId?.trim();
    if (createOnlyIfMissing &&
        (requestedNotificationId == null ||
            requestedNotificationId.isEmpty)) {
      throw Exception(
        'Notification ID is required when duplicate prevention is enabled',
      );
    }
    final doc = requestedNotificationId == null ||
            requestedNotificationId.isEmpty
        ? _notifications.doc()
        : _notifications.doc(requestedNotificationId);
    final data = {
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all notification reads use organizationId.
      'commandId': organizationId,
      'title': title.trim(),
      'message': message.trim(),
      'type': type,
      'priority': priority,
      if (relatedType != null && relatedType.trim().isNotEmpty)
        'relatedType': relatedType.trim(),
      if (relatedId != null && relatedId.trim().isNotEmpty)
        'relatedId': relatedId.trim(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!createOnlyIfMissing) {
      await doc.set(data);
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(doc);
      if (existing.exists) return;
      transaction.set(doc, data);
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

  Future<void> markAllAsRead({
    required List<NotificationModel> notifications,
    required Set<String> readNotificationIds,
    required String userId,
    required String organizationId,
  }) async {
    final unreadNotifications = notifications.where((notification) {
      final notificationOrganizationId = notification.organizationId.isNotEmpty
          ? notification.organizationId
          : notification.commandId;
      return notificationOrganizationId == organizationId &&
          !readNotificationIds.contains(notification.id);
    }).toList(growable: false);

    const batchSize = 450;
    for (var start = 0;
        start < unreadNotifications.length;
        start += batchSize) {
      final end = (start + batchSize < unreadNotifications.length)
          ? start + batchSize
          : unreadNotifications.length;
      final batch = _firestore.batch();

      for (final notification in unreadNotifications.sublist(start, end)) {
        final readId = '${notification.id}_$userId';
        batch.set(
          _notificationReads.doc(readId),
          {
            'id': readId,
            'notificationId': notification.id,
            'userId': userId,
            'organizationId': organizationId,
            // TODO: Remove commandId after all notification reads use
            // organizationId.
            'commandId': organizationId,
            'readAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }
}
