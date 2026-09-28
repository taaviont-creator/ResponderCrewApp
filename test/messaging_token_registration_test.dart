import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/messaging_token_registration.dart';

void main() {
  test('iOS waits for APNs before requesting an FCM token', () async {
    final calls = <String>[];
    var attempts = 0;
    final token = await messagingTokenWhenReady(
      requiresApns: true,
      getApnsToken: () async {
        calls.add('apns');
        return ++attempts == 3 ? 'apple-token' : null;
      },
      getFcmToken: () async {
        calls.add('fcm');
        return 'push-token';
      },
      wait: (_) async {
        calls.add('wait');
      },
    );
    expect(token, 'push-token');
    expect(calls, ['apns', 'wait', 'apns', 'wait', 'apns', 'fcm']);
  });

  test('missing APNs stops after the limit without requesting FCM', () async {
    var fcmCalls = 0;
    var waits = 0;
    final token = await messagingTokenWhenReady(
      requiresApns: true,
      attempts: 3,
      getApnsToken: () async => null,
      getFcmToken: () async {
        fcmCalls++;
        return 'push-token';
      },
      wait: (_) async {
        waits++;
      },
    );
    expect(token, isNull);
    expect(fcmCalls, 0);
    expect(waits, 2);
  });

  test('Android requests FCM without checking APNs', () async {
    final token = await messagingTokenWhenReady(
      requiresApns: false,
      getApnsToken: () async => throw StateError('APNs unavailable'),
      getFcmToken: () async => 'android-token',
    );
    expect(token, 'android-token');
  });

  test('a later registration can succeed after APNs was unavailable', () async {
    var apnsReady = false;
    Future<String?> register() => messagingTokenWhenReady(
      requiresApns: true,
      attempts: 1,
      getApnsToken: () async => apnsReady ? 'apple-token' : null,
      getFcmToken: () async => 'push-token',
    );
    expect(await register(), isNull);
    apnsReady = true;
    expect(await register(), 'push-token');
  });
}
