import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/center_resources_screen.dart';
import 'package:respondcrew_app/screens/organization_center_settings_screen.dart';

class EmptyRegistry extends CenterResourcesService {
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async => {'entries': <Map<String, dynamic>>[]};
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('registry disclosure and scroll position coexist at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              key: const PageStorageKey('center-setup'),
              controller: controller,
              children: [
                const SizedBox(height: 1800, child: Text('Teenused')),
                CenterVesselRegistrySection(
                  organizationId: 'org',
                  service: EmptyRegistry(),
                ),
                const Text('Nähtavus keskustele'),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );
      // Store an offset before the lazily built disclosure first appears.
      controller.jumpTo(500);
      await tester.pumpAndSettle();
      controller.jumpTo(1500);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Nähtavus keskustele').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Aluste registriandmed'));
      await tester.pumpAndSettle();
      expect(find.text('Ühingu varustuses pole veel aluseid.'), findsOneWidget);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      controller.jumpTo(1500);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ühingu varustuses pole veel aluseid.'), findsOneWidget);
      await tester.tap(find.text('Aluste registriandmed'));
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      controller.jumpTo(1500);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ühingu varustuses pole veel aluseid.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
