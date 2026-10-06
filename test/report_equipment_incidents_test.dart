import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/callout_report_screen.dart';
import 'package:respondcrew_app/widgets/report_equipment_incidents.dart';
import 'callout_report_test.dart' as fixture;

void main() {
  testWidgets(
    'report offers technique only and persists a lost radio with the report',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var data = fixture.report(true);
      data['equipment'] = [
        {'id': 'boat', 'name': 'Päästepaat', 'category': 'vessel'},
        {'id': 'suit', 'name': 'Kuivülikond', 'category': 'safety'},
        {'id': 'radio', 'name': 'Raadiojaam', 'category': 'radio'},
      ];
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: CalloutReportScreen(
            organizationId: 'o',
            calloutId: 'c',
            loadReport: () async => data,
            saveReport: (payload) async {
              saved = payload;
              data = {
                ...data,
                'report': {...payload, 'revision': 2},
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Valitud 0 alust'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.textContaining('Valitud 0 alust')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Valitud 0 alust'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(CheckboxListTile, 'Päästepaat'),
        findsOneWidget,
      );
      expect(find.text('Kuivülikond'), findsNothing);
      expect(find.text('Raadiojaam'), findsNothing);
      await tester.ensureVisible(find.text('Päästepaat'));
      await tester.tap(find.text('Päästepaat'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Lisa kahjustus või kaotus'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Lisa kahjustus või kaotus')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lisa kahjustus või kaotus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lisa aruandesse'));
      await tester.pumpAndSettle();
      expect(find.text('Sisesta varustuse nimetus.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Varustuse nimetus'),
        'Raadiojaam',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mis juhtus?'),
        'Kukkus üle parda ja jäi kadunuks.',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaotatud').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lisa aruandesse'));
      await tester.pumpAndSettle();
      expect(find.text('Raadiojaam · Kaotatud'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Salvesta mustand'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Salvesta mustand'));
      await tester.pumpAndSettle();
      expect(saved?['equipmentIds'], ['boat']);
      expect((saved?['equipmentIncidents'] as List).single, {
        'name': 'Raadiojaam',
        'status': 'lost',
        'description': 'Kukkus üle parda ja jäi kadunuks.',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ordinary member can read incidents but cannot change them', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportEquipmentIncidents(
            items: [
              {
                'name': 'Raadiojaam',
                'status': 'lost',
                'description': 'Üle parda.',
              },
            ],
          ),
        ),
      ),
    );
    expect(find.text('Raadiojaam · Kaotatud'), findsOneWidget);
    expect(find.text('Lisa kahjustus või kaotus'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
