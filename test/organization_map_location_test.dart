import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/organization_map_location_service.dart';
import 'package:respondcrew_app/widgets/organization_map_location_control.dart';
import 'package:respondcrew_app/widgets/rescue_base_dialog.dart';

class FakeLocation implements OrganizationMapLocationService {
  final loads = <String>[];
  final writes = <Map<String, dynamic>>[];
  bool failLoad = false, failSave = false;
  Completer<void>? saving;
  @override
  Future<Map<String, dynamic>> load(String organizationId) async {
    loads.add(organizationId);
    if (failLoad) throw Exception('offline');
    return {
      'latitude': 59.45,
      'longitude': 26.5,
      'address': 'Sadam',
      'positionVerified': true,
      'revision': 4,
    };
  }

  @override
  Future<void> save(
    String organizationId,
    int revision,
    Map<String, dynamic> location,
  ) async {
    writes.add({
      ...location,
      'organizationId': organizationId,
      'revision': revision,
    });
    if (failSave) {
      throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Ühendus puudub',
      );
    }
    await saving?.future;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    FakeLocation service, {
    String org = 'org-a',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationMapLocationControl(
            key: ValueKey(org),
            organizationId: org,
            service: service,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ühingu asukoht kaardil'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'organization settings edit location without separate base name, unit or activation',
    (tester) async {
      final service = FakeLocation();
      await open(tester, service);
      expect(find.text('Päästebaasi nimi'), findsNothing);
      expect(find.text('Baas on kasutusel'), findsNothing);
      expect(find.text('59.45'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Laiuskraad'),
        '59,6',
      );
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(service.writes.single, {
        'address': 'Sadam',
        'latitude': 59.6,
        'longitude': 26.5,
        'positionVerified': true,
        'organizationId': 'org-a',
        'revision': 4,
      });
      expect(find.byType(RescueBaseDialog), findsNothing);
      expect(find.text('Ühingu asukoht salvestatud.'), findsOneWidget);
    },
  );

  testWidgets('failed save keeps coordinates in the same form for retry', (
    tester,
  ) async {
    final service = FakeLocation()..failSave = true;
    await open(tester, service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Laiuskraad'),
      '59.7',
    );
    await tester.tap(find.text('Salvesta'));
    await tester.pumpAndSettle();
    expect(find.text('Ühendus puudub'), findsOneWidget);
    expect(find.text('59.7'), findsOneWidget);
    service.failSave = false;
    await tester.tap(find.text('Salvesta'));
    await tester.pumpAndSettle();
    expect(service.writes.length, 2);
    expect(service.writes[0], service.writes[1]);
    expect(find.byType(RescueBaseDialog), findsNothing);
  });

  testWidgets(
    'loading failure cannot offer a blank overwrite; retry uses selected organization',
    (tester) async {
      final service = FakeLocation()..failLoad = true;
      await open(tester, service);
      expect(find.byType(RescueBaseDialog), findsNothing);
      expect(service.writes, isEmpty);
      service.failLoad = false;
      await open(tester, service, org: 'org-b');
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(service.loads, ['org-a', 'org-b']);
      expect(service.writes.single['organizationId'], 'org-b');
    },
  );

  testWidgets(
    'narrow phone can edit and save without submitting twice during pending save',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeLocation()..saving = Completer<void>();
      await open(tester, service);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Salvesta'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvestan…'),
            )
            .onPressed,
        isNull,
      );
      service.saving!.complete();
      await tester.pumpAndSettle();
      expect(service.writes.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
