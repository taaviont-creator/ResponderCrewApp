import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/device_alarm_settings.dart';
import 'package:respondcrew_app/widgets/app_build_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceAlarmSettings.channel, null),
  );

  testWidgets(
    'menu shows the installed Android package version, not a hardcoded source version',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceAlarmSettings.channel, (call) async {
            expect(call.method, 'getBuildInfo');
            return {'version': '1.0.1', 'build': '20261008'};
          });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppBuildLabel())),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('RespondCrew 1.0.1 (20261008) · Android'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'missing platform info does not crash the menu or invent a version',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppBuildLabel())),
      );
      await tester.pumpAndSettle();
      expect(find.text('RespondCrew · Android'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
