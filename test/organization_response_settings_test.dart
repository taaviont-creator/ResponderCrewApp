import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/organization_response_settings_service.dart';
import 'package:respondcrew_app/screens/organization_response_settings_screen.dart';

class FakeResponseSettings implements OrganizationResponseSettingsService {
  bool failLoad = false, failSave = false, conflict = false;
  int loads = 0;
  final writes = <Map<String, dynamic>>[];
  Map<String, dynamic> initial = {
    'revision': 0,
    'sarMinimumCrew': 3,
    'contactName': '',
    'contactPhone': '',
    'services': {
      'sar': {
        'enabled': false,
        'departureMinutes': null,
        'vesselIds': <String>[],
      },
      'tross': {
        'enabled': false,
        'departureMinutes': null,
        'vesselIds': <String>[],
        'minimumResponders': 1,
      },
    },
    'vessels': [
      {'id': 'boat', 'name': 'Paat', 'status': 'unknown'},
    ],
  };
  @override
  Future<Map<String, dynamic>> load(String organizationId) async {
    loads++;
    if (failLoad) throw Exception('offline');
    return initial;
  }

  @override
  Future<int> save(
    String organizationId,
    int revision,
    Map<String, dynamic> value,
  ) async {
    writes.add({
      ...value,
      'organizationId': organizationId,
      'revision': revision,
    });
    if (failSave || conflict) {
      throw FirebaseFunctionsException(
        code: conflict ? 'aborted' : 'unavailable',
        message: 'Salvestamine ebaõnnestus',
      );
    }
    return revision + 1;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    FakeResponseSettings service, {
    bool narrow = false,
  }) async {
    tester.view.physicalSize = narrow
        ? const Size(320, 700)
        : const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationResponseSettingsScreen(
          organizationId: 'org-a',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enable(WidgetTester tester, String title) async {
    await tester.tap(find.widgetWithText(SwitchListTile, title));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Salvesta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvesta'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Tross works as a separate service with one responder and an existing vessel',
    (tester) async {
      final service = FakeResponseSettings();
      await open(tester, service);
      expect(find.text('Päästebaasi nimi'), findsNothing);
      await enable(tester, 'Trossi mereabi');
      expect(find.text('1'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('Seisund teadmata'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tross-boat')));
      await save(tester);
      final settings = service.writes.single['services'] as Map;
      expect(settings['tross']['minimumResponders'], 1);
      expect(settings['tross']['vesselIds'], ['boat']);
      expect(settings['sar']['enabled'], false);
      expect(service.writes.single['organizationId'], 'org-a');
    },
  );

  testWidgets(
    'SAR inherits minimum without another editable minimum and validates departure/vessel',
    (tester) async {
      final service = FakeResponseSettings();
      await open(tester, service);
      await enable(tester, 'SAR');
      expect(find.textContaining('Miinimumkoosseis: 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('tross-minimum')), findsNothing);
      await save(tester);
      expect(service.writes, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('sar-departure')), '15');
      await save(tester);
      expect(find.text('Vali SAR-i jaoks vähemalt üks alus.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sar-boat')));
      await save(tester);
      final sar = (service.writes.single['services'] as Map)['sar'] as Map;
      expect(sar.containsKey('minimumResponders'), false);
      expect(sar['departureMinutes'], 15);
    },
  );

  testWidgets(
    'save failure keeps input; revisions advance only after success',
    (tester) async {
      final service = FakeResponseSettings()..failSave = true;
      await open(tester, service);
      await enable(tester, 'Trossi mereabi');
      await tester.enterText(find.byKey(const ValueKey('tross-minimum')), '2');
      await tester.tap(find.byKey(const ValueKey('tross-boat')));
      await save(tester);
      expect(find.text('2'), findsOneWidget);
      service.failSave = false;
      await save(tester);
      expect(service.writes[0], service.writes[1]);
      await save(tester);
      expect(service.writes.last['revision'], 1);
    },
  );

  testWidgets(
    'load failure offers no blank overwrite; stale revision requires explicit reload',
    (tester) async {
      final service = FakeResponseSettings()..failLoad = true;
      await open(tester, service);
      expect(find.text('Salvesta'), findsNothing);
      service.failLoad = false;
      await tester.tap(find.text('Proovi uuesti'));
      await tester.pumpAndSettle();
      service.conflict = true;
      await save(tester);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvesta'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Laadi salvestatud andmed uuesti'));
      await tester.pumpAndSettle();
      expect(service.loads, 3);
    },
  );

  testWidgets(
    'missing prior vessel can be removed even while service is disabled',
    (tester) async {
      final service = FakeResponseSettings();
      (service.initial['services'] as Map)['sar']['vesselIds'] = ['gone'];
      await open(tester, service);
      await tester.tap(find.text('Varem valitud alus ei ole enam saadaval'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(
        (service.writes.single['services'] as Map)['sar']['vesselIds'],
        isEmpty,
      );
    },
  );

  testWidgets(
    'service settings fit a narrow phone without base/unit management',
    (tester) async {
      await open(tester, FakeResponseSettings(), narrow: true);
      await enable(tester, 'Trossi mereabi');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Valvetelefon'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Valvetelefon'), findsOneWidget);
    },
  );
}
