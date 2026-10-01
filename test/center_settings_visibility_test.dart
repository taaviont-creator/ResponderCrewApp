import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/center_sharing_screen.dart';

void main() {
  testWidgets(
    'inline visibility explains absent map point and pending approval without another page',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CenterSharingScreen(
                organizationId: 'org',
                embedded: true,
                call: (name, data) async => {
                  'positionReady': false,
                  'entries': [
                    {
                      'centerId': 'merevalvekeskus',
                      'name': 'Merevalvekeskus',
                      'requested': true,
                      'approved': false,
                      'revision': 1,
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.textContaining('Kaardipunkt puudub'), findsOneWidget);
      expect(find.text('Platvormihalduri kinnituse ootel'), findsOneWidget);
      expect(find.text('Kinnita jagamine'), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
