import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/member_request_notification.dart';
import 'package:respondcrew_app/services/callout_alarm_notification_service.dart';

void main() {
  test(
    'member request preserves organization through local notification tap',
    () {
      final event = MemberRequestNotification.fromData({
        'type': 'member_request',
        'organizationId': 'org-b',
        'membershipId': 'user_org-b',
      });
      expect(event, isNotNull);
      expect(
        MemberRequestNotification.fromPayload(
          event!.toPayload(),
        )?.organizationId,
        'org-b',
      );
      expect(
        CalloutNotificationOpenEvent.fromPayload(event.toPayload()),
        isNull,
      );
    },
  );
  test('reject malformed and unrelated notifications', () {
    for (final data in <Map<String, dynamic>>[
      {'type': 'callout', 'organizationId': 'a'},
      {'type': 'member_request'},
      {'type': 'member_request', 'organizationId': ' '},
      {'type': 'member_request', 'organizationId': 'a/b'},
    ]) {
      expect(MemberRequestNotification.fromData(data), isNull);
    }
    expect(MemberRequestNotification.fromPayload('bad json'), isNull);
    expect(MemberRequestNotification.fromPayload('[]'), isNull);
  });
}
