import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sar_alarm_android/sar_alarm_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeSarAlarm.channel, (call) async {
          calls.add(call);
          return call.method == 'cancelTest' ? null : true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeSarAlarm.channel, null),
  );
  test(
    'native alarm preserves exact callout payload and distinct notification id',
    () async {
      const payload =
          '{"organizationId":"org","calloutId":"callout","sarAlarm":true}';
      expect(await NativeSarAlarm.show(id: 123, payload: payload), isTrue);
      expect(calls.single.arguments, {'id': 123, 'payload': payload});
    },
  );
  test('device test schedule and cancellation go to native engine', () async {
    expect(await NativeSarAlarm.scheduleTest(), isTrue);
    await NativeSarAlarm.cancelTest();
    expect(calls.map((c) => c.method), ['scheduleTest', 'cancelTest']);
  });
  test(
    'denied exact alarm permission is not reported as a scheduled test',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeSarAlarm.channel, (_) async {
            throw PlatformException(code: 'exact_alarm_required');
          });
      await expectLater(
        NativeSarAlarm.scheduleTest(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
