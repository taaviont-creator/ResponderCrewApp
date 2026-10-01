import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/response_units_screen.dart';
import 'package:respondcrew_app/services/response_unit_service.dart';
import 'package:respondcrew_app/widgets/rescue_base_dialog.dart';
import 'package:respondcrew_app/widgets/response_unit_dialog.dart';
import 'package:respondcrew_app/widgets/unit_allocation_dialog.dart';

class FakeUnits implements ResponseUnitService {
  final writes = <Map<String, dynamic>>[];
  bool fail = true;
  int generated = 0;
  @override
  String newId() => 'base-${++generated}';
  @override
  Future<Map<String, dynamic>> load(String organizationId) async => {
    'serverNowMs': DateTime.now().millisecondsSinceEpoch,
    'bases': <dynamic>[],
    'units': <dynamic>[],
    'members': <dynamic>[],
    'vessels': <dynamic>[],
  };
  @override
  Future<void> save(String method, Map<String, dynamic> data) async {
    writes.add(Map<String, dynamic>.from(data));
    if (fail) throw Exception('offline');
  }
}

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget dialog,
    ValueChanged<Map<String, dynamic>?> result,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result(
                await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => dialog,
                ),
              ),
              child: const Text('Ava'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ava'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'base saves no coordinates rather than inventing a map location',
    (tester) async {
      Map<String, dynamic>? result;
      await show(tester, const RescueBaseDialog(), (v) => result = v);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Päästebaasi nimi'),
        'Purtse baas',
      );
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(result?['latitude'], isNull);
      expect(result?['longitude'], isNull);
      expect(result?['positionVerified'], false);
      expect(result?['name'], 'Purtse baas');
    },
  );
  testWidgets(
    'base rejects one coordinate and accepts decimal commas after explicit verification',
    (tester) async {
      Map<String, dynamic>? result;
      await show(tester, const RescueBaseDialog(), (v) => result = v);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Päästebaasi nimi'),
        'Baas',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Laiuskraad'),
        '59,45',
      );
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(find.text('Sisesta korrektne pikkuskraad'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pikkuskraad'),
        '26,5',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(result?['latitude'], 59.45);
      expect(result?['longitude'], 26.5);
      expect(result?['positionVerified'], true);
    },
  );
  testWidgets(
    'unit requires a service and candidates do not automatically allocate resources',
    (tester) async {
      Map<String, dynamic>? result;
      await show(
        tester,
        const ResponseUnitDialog(
          bases: [
            {'id': 'b', 'name': 'Baas'},
          ],
          members: [],
          vessels: [],
          initial: {
            'name': 'Üksus',
            'baseId': 'b',
            'memberIds': <String>[],
            'vesselIds': <String>[],
          },
        ),
        (v) => result = v,
      );
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.ensureVisible(find.text('Trossi mereabi'));
      await tester.tap(find.text('Trossi mereabi'));
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(result?['enabledServices'], ['tross']);
      expect(result!.containsKey('allocations'), false);
      expect(result!.containsKey('ready'), false);
    },
  );
  testWidgets(
    'allocation is explicit and does not modify personal availability',
    (tester) async {
      Map<String, dynamic>? result;
      await show(
        tester,
        const UnitAllocationDialog(
          members: [
            {'id': 'm', 'name': 'Mari'},
          ],
          vessels: [],
        ),
        (v) => result = v,
      );
      await tester.tap(find.text('Määra üksusele'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Mari'));
      await tester.tap(find.text('Määra üksusele'));
      await tester.pumpAndSettle();
      expect(result?['memberIds'], ['m']);
      expect(result?['durationHours'], 4);
      expect(result!.containsKey('status'), false);
    },
  );
  testWidgets('failed saves retain their data and id for a safe retry', (
    tester,
  ) async {
    final service = FakeUnits();
    await tester.pumpWidget(
      MaterialApp(
        home: ResponseUnitsScreen(organizationId: 'org', service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lisa baas'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Päästebaasi nimi'),
      'Salvestatav baas',
    );
    await tester.tap(find.text('Salvesta'));
    await tester.pumpAndSettle();
    expect(find.text('Proovi salvestamist uuesti'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Proovi salvestamist uuesti'));
    await tester.pumpAndSettle();
    expect(service.writes.length, 2);
    expect(service.writes[0], service.writes[1]);
    expect(service.generated, 1);
  });
  testWidgets('unit list controls fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ResponseUnitsScreen(organizationId: 'org', service: FakeUnits()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lisa baas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
