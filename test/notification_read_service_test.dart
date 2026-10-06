import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/notification_model.dart';
import 'package:respondcrew_app/services/notification_service.dart';

NotificationModel notification(
  String id, {
  String org = 'org',
  String? legacyOrg,
}) => NotificationModel(
  id: id,
  organizationId: org,
  commandId: legacyOrg ?? org,
  title: 'Teavitus',
  message: 'Sisu',
  type: NotificationType.system,
  priority: NotificationPriority.normal,
  createdBy: 'admin',
);

class RecordingNotificationService extends NotificationService {
  final completed = <String>{};
  final attempted = <String>[];
  String? failId;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<void> markAsRead({
    required String notificationId,
    required String userId,
    required String organizationId,
  }) async {
    expect(userId, 'member');
    expect(organizationId, 'org');
    attempted.add(notificationId);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(Duration.zero);
    inFlight--;
    if (notificationId == failId) throw StateError('permission-denied');
    completed.add(notificationId);
  }
}

void main() {
  test('marks a large inbox with bounded independent writes', () async {
    final service = RecordingNotificationService();
    await service.markAllAsRead(
      notifications: List.generate(601, (i) => notification('$i')),
      readNotificationIds: {},
      userId: 'member',
      organizationId: 'org',
    );
    expect(service.completed.length, 601);
    expect(service.attempted.toSet().length, 601);
    expect(service.maxInFlight, 4);
    expect(service.inFlight, 0);
  });

  test(
    'skips read, duplicate and foreign notifications; supports legacy org',
    () async {
      final service = RecordingNotificationService();
      await service.markAllAsRead(
        notifications: [
          notification('read'),
          notification('new'),
          notification('new'),
          notification('foreign', org: 'other'),
          notification('legacy', org: '', legacyOrg: 'org'),
        ],
        readNotificationIds: {'read'},
        userId: 'member',
        organizationId: 'org',
      );
      expect(service.attempted, ['new', 'legacy']);
    },
  );

  test(
    'failure settles in-flight writes and retry preserves completed receipts',
    () async {
      final service = RecordingNotificationService()..failId = '1';
      final notifications = List.generate(11, (i) => notification('$i'));
      await expectLater(
        service.markAllAsRead(
          notifications: notifications,
          readNotificationIds: {},
          userId: 'member',
          organizationId: 'org',
        ),
        throwsStateError,
      );
      expect(service.inFlight, 0);
      expect(service.completed, {'0', '2', '3'});
      expect(service.attempted, ['0', '1', '2', '3']);
      service.failId = null;
      service.attempted.clear();
      await service.markAllAsRead(
        notifications: notifications,
        readNotificationIds: Set.of(service.completed),
        userId: 'member',
        organizationId: 'org',
      );
      expect(service.completed.length, 11);
      expect(service.attempted, ['1', '4', '5', '6', '7', '8', '9', '10']);
    },
  );

  test('empty inbox is a no-op and missing organization is rejected', () async {
    final service = RecordingNotificationService();
    await service.markAllAsRead(
      notifications: [],
      readNotificationIds: {},
      userId: 'member',
      organizationId: 'org',
    );
    await expectLater(
      service.markAllAsRead(
        notifications: [notification('1')],
        readNotificationIds: {},
        userId: 'member',
        organizationId: '',
      ),
      throwsException,
    );
    expect(service.attempted, isEmpty);
  });
}
