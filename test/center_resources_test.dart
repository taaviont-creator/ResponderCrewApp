import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/center_resources_screen.dart';
import 'package:respondcrew_app/widgets/crew_readiness_card.dart';

class FakeResources extends CenterResourcesService {
  final calls = <Map<String, dynamic>>[];
  String allocation = 'free';
  bool verified = false;
  int failedSaves = 0;
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add({'method': name, ...data});
    if (name == 'saveCenterVesselIdentity') {
      if (failedSaves > 0) {
        failedSaves--;
        throw Exception('offline');
      }
      verified = true;
    }
    if (name == 'setOrganizationCenterResource') {
      allocation = data['action'] == 'claim' ? 'own' : 'free';
    }
    return {
      'entries': [
        {
          'kind': 'vessel',
          'resourceId': 'boat',
          'name': 'Meie alus',
          'identityVerified': verified,
          'country': 'EE',
          'registration': verified ? 'ABC123' : '',
          'identityRevision': verified ? 1 : 0,
          'allocationRevision': 0,
          'allocation': allocation,
        },
        {
          'kind': 'member',
          'resourceId': 'member',
          'name': 'Mari',
          'identityVerified': true,
          'identityRevision': 0,
          'allocationRevision': 2,
          'allocation': 'other',
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'admin registers a vessel on a narrow screen and assigns then releases it',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeResources();
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CenterResourcesScreen(
            organizationId: 'own',
            service: service,
            onSaved: () => refreshed++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Määra meie ühingule'), findsNothing);
      expect(find.text('Mari'), findsNothing);
      expect(
        find.text('Mitme ühingu liikmete arvestus (vajadusel)'),
        findsNothing,
      );
      await tester.tap(find.text('Registriandmed'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'ABC123');
      await tester.tap(find.text('Kinnitan registriandmed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        service.calls.any(
          (c) =>
              c['method'] == 'saveCenterVesselIdentity' &&
              c['organizationId'] == 'own' &&
              c['registration'] == 'ABC123',
        ),
        isTrue,
      );
      await tester.ensureVisible(find.text('Määra meie ühingule'));
      await tester.tap(find.text('Määra meie ühingule'));
      await tester.pumpAndSettle();
      expect(find.text('Vabasta jaotus'), findsOneWidget);
      expect(refreshed, 2);
      await tester.tap(find.text('Vabasta jaotus'));
      await tester.pumpAndSettle();
      expect(find.text('Määra meie ühingule'), findsOneWidget);
      expect(refreshed, 3);
      expect(
        service.calls
            .where((c) => c['method'] == 'setOrganizationCenterResource')
            .every((c) => c['resourceId'] == 'boat'),
        isTrue,
      );
    },
  );

  testWidgets(
    'failed vessel save preserves input and refreshes readiness only after a successful retry',
    (tester) async {
      final service = FakeResources()..failedSaves = 1;
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CenterResourcesScreen(
            organizationId: 'own',
            service: service,
            onSaved: () => refreshed++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registriandmed'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'ABC123');
      await tester.tap(find.text('Kinnitan registriandmed'));
      await tester.pumpAndSettle();
      expect(
        find.text('Salvestamine ebaõnnestus. Proovi uuesti.'),
        findsOneWidget,
      );
      expect(find.text('ABC123'), findsOneWidget);
      expect(refreshed, 0);
      expect(service.verified, isFalse);
      await tester.tap(find.text('Kinnitan registriandmed'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Registriandmed kinnitatud · EE ABC123'),
        findsOneWidget,
      );
      expect(refreshed, 1);
      expect(
        service.calls
            .where((c) => c['method'] == 'saveCenterVesselIdentity')
            .map((c) => c['registration']),
        ['ABC123', 'ABC123'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in {
    'unknown': 'VALMIDUS TEADMATA',
    'delayed': 'REAGEERIB VIIVITUSEGA',
  }.entries) {
    testWidgets(
      'home uses shared ${entry.key} status rather than a local green or red calculation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CrewReadinessView(
                members: const [],
                minimumCrew: 1,
                currentUid: 'member',
                onContact: (_, _) {},
                authoritative: {
                  'ready': false,
                  'operationalStatus': entry.key,
                  'missing': ['Serveri selgitus'],
                  'onDutyCount': 0,
                  'secondLevelOnDutyCount': 0,
                },
              ),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Serveri selgitus'), findsOneWidget);
        expect(find.text('REAGEERIMISVALMIS'), findsNothing);
      },
    );
  }
}
