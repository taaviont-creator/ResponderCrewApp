import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/callout_alarm_notification_service.dart';

void main() {
  group('CalloutNotificationOpenEvent', () {
    test('parses callout event from FCM data', () {
      final event = CalloutNotificationOpenEvent.fromData({
        'organizationId': 'org-1',
        'calloutId': 'callout-1',
      });

      expect(event, isNotNull);
      expect(event!.organizationId, 'org-1');
      expect(event.calloutId, 'callout-1');
    });

    test('supports relatedId and commandId compatibility fields', () {
      final event = CalloutNotificationOpenEvent.fromData({
        'commandId': 'org-legacy',
        'relatedId': 'callout-legacy',
      });

      expect(event, isNotNull);
      expect(event!.organizationId, 'org-legacy');
      expect(event.calloutId, 'callout-legacy');
    });

    test('round-trips local notification payload', () {
      const source = CalloutNotificationOpenEvent(
        organizationId: 'org-2',
        calloutId: 'callout-2',
      );

      final parsed =
          CalloutNotificationOpenEvent.fromPayload(source.toPayload());

      expect(parsed, isNotNull);
      expect(parsed!.organizationId, source.organizationId);
      expect(parsed.calloutId, source.calloutId);
    });

    test('rejects invalid or unrelated payloads', () {
      expect(
        CalloutNotificationOpenEvent.fromData({
          'organizationId': 'org-1',
        }),
        isNull,
      );
      expect(
        CalloutNotificationOpenEvent.fromPayload(
          'local_callout_alarm_test',
        ),
        isNull,
      );
    });
  });
}
