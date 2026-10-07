import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/sar_notification_policy.dart';
import 'package:respondcrew_app/services/device_alarm_settings.dart';
import 'package:respondcrew_app/widgets/device_alarm_settings_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceAlarmSettings.channel, null);
  });

  testWidgets(
    'explicit DND action checks actual result and opens channel when Android refuses',
    (tester) async {
      var enabled = false;
      var allowChange = false;
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceAlarmSettings.channel, (call) async {
            calls.add(call.method);
            if (call.method == 'getSettings') {
              return <String, dynamic>{
                'notificationPolicyAccess': true,
                'bypassDnd': enabled,
                'alarmAudio': true,
                'soundVolume': 0,
                'soundVolumeMax': 15,
                'interruptionFilter': 3,
              };
            }
            if (call.method == 'enableSarDnd') return enabled = allowChange;
            return 'sarChannel';
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeviceAlarmSettingsCard(
                testAlarm: () async => true,
                cancelTest: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('enableSarDnd')));
      expect(
        find.textContaining('Alarmi helitugevus on nullis'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Telefonis on täielik vaikus'),
        findsOneWidget,
      );
      final action = find.text('Luba SAR-häire „Mitte segada“ ajal');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(calls, contains('openSarChannel'));
      expect(find.text('SAR-kanali erand lubatud'), findsNothing);
      allowChange = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('SAR-kanali erand lubatud'), findsOneWidget);
      expect(action, findsNothing);
    },
  );

  test('native SAR delivery excludes malformed and Tross messages', () {
    final sar = <String, dynamic>{
      'delivery': 'native_sar_v1',
      'calloutType': 'sar',
      'organizationId': 'org',
      'calloutId': 'one',
    };
    expect(isNativeSarDelivery(sar), isTrue);
    expect(isNativeSarDelivery({...sar, 'calloutType': 'tross'}), isFalse);
    expect(isNativeSarDelivery({...sar, 'organizationId': ''}), isFalse);
    expect(isNativeSarDelivery({...sar, 'delivery': null}), isFalse);
  });

  test(
    'callout IDs keep pending intents separate across events and organizations',
    () {
      expect(
        calloutNotificationId('a', 'one'),
        calloutNotificationId('a', 'one'),
      );
      expect(
        calloutNotificationId('a', 'one'),
        isNot(calloutNotificationId('a', 'two')),
      );
      expect(
        calloutNotificationId('a', 'one'),
        isNot(calloutNotificationId('b', 'one')),
      );
      expect(calloutNotificationId('a', 'one'), greaterThan(903100));
    },
  );

  testWidgets(
    'device settings refresh on resume and open specific system settings',
    (tester) async {
      var allowed = false;
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceAlarmSettings.channel, (call) async {
            calls.add(call.method);
            if (call.method == 'getSettings') {
              return <String, dynamic>{
                'notificationsEnabled': true,
                'channelExists': true,
                'channelEnabled': true,
                'channelSound': false,
                'bypassDnd': allowed,
                'notificationPolicyAccess': allowed,
                'fullScreenAllowed': allowed,
                'soundVolume': 0,
                'soundVolumeMax': 15,
              };
            }
            return null;
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeviceAlarmSettingsCard(
                testAlarm: () async => true,
                cancelTest: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Heli on välja lülitatud'), findsOneWidget);
      expect(find.text('Süsteemi luba puudub'), findsOneWidget);
      await tester.ensureVisible(find.text('„Mitte segada“ ligipääs'));
      await tester.tap(find.text('„Mitte segada“ ligipääs'));
      expect(calls, contains('openDndSettings'));
      allowed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Süsteemi luba olemas'), findsOneWidget);
      expect(find.textContaining('SAR-kanali erand lubatud'), findsOneWidget);
    },
  );

  testWidgets(
    'DND access and SAR exception stay separate and open different screens',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceAlarmSettings.channel, (call) async {
            calls.add(call.method);
            if (call.method == 'getSettings') {
              return <String, dynamic>{
                'notificationPolicyAccess': true,
                'bypassDnd': false,
              };
            }
            return call.method == 'openDndSettings' ? 'dndList' : 'sarChannel';
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeviceAlarmSettingsCard(
                testAlarm: () async => true,
                cancelTest: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RespondCrew eriligipääs lubatud'), findsOneWidget);
      expect(find.text('SAR-kanali erand puudub'), findsOneWidget);
      expect(find.text('SAR-kanali erand lubatud'), findsNothing);
      await tester.ensureVisible(find.text('„Mitte segada“ ligipääs'));
      await tester.tap(find.text('„Mitte segada“ ligipääs'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('ligipääsu loendist RespondCrew'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('SAR-häire „Mitte segada“ erand'));
      await tester.tap(find.text('SAR-häire „Mitte segada“ erand'));
      await tester.pumpAndSettle();
      expect(calls, containsAllInOrder(['openDndSettings', 'openSarChannel']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallback app settings and unavailable system screen give guidance without granting access',
    (tester) async {
      var unavailable = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceAlarmSettings.channel, (call) async {
            if (call.method == 'getSettings') {
              return <String, dynamic>{'notificationPolicyAccess': false};
            }
            if (unavailable) throw PlatformException(code: 'unavailable');
            return 'appDetails';
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeviceAlarmSettingsCard(
                testAlarm: () async => true,
                cancelTest: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('„Mitte segada“ ligipääs'));
      await tester.tap(find.text('„Mitte segada“ ligipääs'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Telefon ei avanud otseteed'), findsOneWidget);
      expect(find.text('RespondCrew eriligipääs lubatud'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      unavailable = true;
      await tester.tap(find.text('„Mitte segada“ ligipääs'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seadet ei saanud avada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow large-text view schedules and cancels only the device test',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var scheduled = 0, cancelled = 0, immediate = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            DeviceAlarmSettings.channel,
            (_) async => <String, dynamic>{},
          );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DeviceAlarmSettingsCard(
                  testNow: () async {
                    immediate++;
                    return true;
                  },
                  testAlarm: () async {
                    scheduled++;
                    return true;
                  },
                  cancelTest: () async {
                    cancelled++;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kuula SAR-proovihäiret'));
      await tester.tap(find.text('Kuula SAR-proovihäiret'));
      await tester.pumpAndSettle();
      expect(immediate, 1);
      expect(scheduled, 0);
      await tester.ensureVisible(find.text('Proovihäire 10 s pärast'));
      await tester.tap(find.text('Proovihäire 10 s pärast'));
      await tester.pumpAndSettle();
      expect(scheduled, 1);
      await tester.ensureVisible(find.text('Tühista proovihäire'));
      await tester.tap(find.text('Tühista proovihäire'));
      await tester.pumpAndSettle();
      expect(cancelled, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unavailable device bridge never claims permission is granted', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeviceAlarmSettings.channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeviceAlarmSettingsCard(
              testAlarm: () async => false,
              cancelTest: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Lubade olekut ei saanud lugeda'),
      findsOneWidget,
    );
    expect(find.text('Süsteemi luba olemas'), findsNothing);
    expect(find.text('Pole teada'), findsWidgets);
  });

  testWidgets(
    'missing exact alarm permission opens settings and never schedules',
    (tester) async {
      final calls = <String>[];
      var scheduled = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceAlarmSettings.channel, (call) async {
            calls.add(call.method);
            if (call.method == 'getSettings') {
              return {'exactAlarmAllowed': false};
            }
            return 'exactAlarm';
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeviceAlarmSettingsCard(
                testAlarm: () async {
                  scheduled++;
                  return true;
                },
                cancelTest: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Proovihäire 10 s pärast'));
      await tester.tap(find.text('Proovihäire 10 s pärast'));
      await tester.pumpAndSettle();
      expect(scheduled, 0);
      expect(calls, contains('openExactAlarmSettings'));
      expect(
        find.textContaining('Luba RespondCrew täpsed alarmid.'),
        findsOneWidget,
      );
    },
  );
}
