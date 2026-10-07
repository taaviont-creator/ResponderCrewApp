import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/config/release_features.dart';
import 'package:respondcrew_app/screens/app_context_screen.dart';
import 'package:respondcrew_app/screens/platform_management_screen.dart';
import 'package:respondcrew_app/widgets/dashboard_quick_actions.dart';
import 'package:respondcrew_app/widgets/primary_action_button.dart';

void main() {
  test('standard build keeps center pilot disabled', () {
    expect(ReleaseFeatures.centers, false);
  });
  for (final path in ['/', '/keskus/sar', '/keskus/tross']) {
    testWidgets(
      'organization release opens home without center lookup at $path',
      (tester) async {
        // Firebase is intentionally not initialized: no center request is allowed.
        await tester.pumpWidget(
          MaterialApp(
            home: AppContextScreen(
              userId: 'member',
              path: path,
              navigate: (_) {},
              organizationHome: const Text('Minu ühing'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Minu ühing'), findsOneWidget);
        expect(find.text('Laadin sinu töökeskkondi…'), findsNothing);
        expect(find.text('Kontrolli uuesti'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('platform release hides center settings and sharing requests', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformManagementScreen(
          pendingUpdates: const Stream.empty(),
          notices: const SizedBox(),
          call: (name, data) async {
            calls.add(name);
            return {'organizations': <Map<String, dynamic>>[]};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kaardikeskused'), findsNothing);
    await tester.tap(find.text('Taotlused'));
    await tester.pumpAndSettle();
    expect(find.text('Kaardile lisamise taotlused'), findsNothing);
    expect(calls.any((name) => name.toLowerCase().contains('center')), false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('organization alarm remains the dashboard primary action', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardQuickActions(
            onCreateCallout: () => opened++,
            onCreateActivity: () {},
          ),
        ),
      ),
    );
    expect(
      find.widgetWithText(PrimaryActionButton, 'Loo väljakutse'),
      findsOneWidget,
    );
    await tester.tap(find.text('Loo väljakutse'));
    expect(opened, 1);
  });
}
