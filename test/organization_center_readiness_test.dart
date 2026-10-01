import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/organization_center_readiness_screen.dart';

void main() {
  Map<String, dynamic> data(bool admin) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'serverNowMs': now,
      'canManage': admin,
      'settingsRevision': 3,
      'entries': [
        {
          'service': 'sar',
          'enabled': true,
          'automatic': true,
          'status': 'unknown',
          'freshUntilMs': now + 90000,
          'reasons': ['Ressursside kontroll on lõpetamata.'],
          'minimum': 3,
          'onDutyCount': 2,
          'confirmation': {
            'revision': 2,
            'confirmedAtMs': null,
            'validUntilMs': null,
            'settingsRevision': null,
          },
        },
      ],
    };
  }

  testWidgets('member sees shared result without confirmation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationCenterReadinessScreen(
          organizationId: 'org',
          call: (method, args) async => data(false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Valmidus teadmata'), findsOneWidget);
    expect(find.text('Muuda teenuse staatust'), findsNothing);
    expect(find.text('Valves 2 / 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'admin saves scoped revision and explicit confirmation; 320px dialog fits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizationCenterReadinessScreen(
            organizationId: 'org',
            call: (method, args) async {
              if (method == 'setOrganizationReadinessConfirmation') {
                saved = args;
                return {'saved': true};
              }
              return data(true);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Muuda teenuse staatust'));
      await tester.tap(find.text('Muuda teenuse staatust'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sinu isiklik valvesolek ei muutu'),
        findsOneWidget,
      );
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(saved, {
        'organizationId': 'org',
        'service': 'sar',
        'settingsRevision': 3,
        'expectedRevision': 2,
        'action': 'withdraw',
        'validityMode': 'untilChanged',
        'validForMinutes': null,
        'delayMinutes': 0,
        'reason': '',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'admin can mark service unavailable or restore automatic without changing personal duty',
    (tester) async {
      Map<String, dynamic>? saved;
      final response = data(true);
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizationCenterReadinessScreen(
            organizationId: 'org',
            call: (name, args) async {
              if (name == 'setOrganizationReadinessConfirmation') {
                saved = args;
                return {'saved': true};
              }
              return response;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muuda teenuse staatust'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automaatne, ühingu andmete järgi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teenus pole kättesaadav').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alus hoolduses');
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(saved?['action'], 'unavailable');
      expect(saved?['reason'], 'Alus hoolduses');
      expect(saved?['validityMode'], 'untilChanged');
      expect(saved?['delayMinutes'], 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'normal automatic state needs no extra confirmation or standalone page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationCenterReadinessScreen(
              organizationId: 'org',
              embedded: true,
              call: (method, args) async => data(true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(
        find.text('Automaatne · eraldi kinnitust pole vaja'),
        findsOneWidget,
      );
      expect(find.text('Valmidus keskuse kaardil'), findsNothing);
      await tester.tap(find.text('Muuda teenuse staatust'));
      await tester.pumpAndSettle();
      expect(find.text('Automaatne, ühingu andmete järgi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed confirmation does not report success or alter read state',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizationCenterReadinessScreen(
            organizationId: 'org',
            call: (method, args) async {
              if (method == 'setOrganizationReadinessConfirmation') {
                throw Exception('offline');
              }
              loads++;
              return data(true);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muuda teenuse staatust'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(find.text('Kinnituse salvestamine ebaõnnestus.'), findsOneWidget);
      expect(
        find.text('Automaatne · eraldi kinnitust pole vaja'),
        findsOneWidget,
      );
      expect(loads, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
