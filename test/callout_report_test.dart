import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/callout_report_screen.dart';

Map<String, dynamic> report(bool edit) => {
  'canEdit': edit,
  'organizationName': 'Päästeühing',
  'operationLogId': 'log',
  'summary': 'Alus pukseeriti sadamasse.',
  'outcome': 'Abi osutatud',
  'report': {'revision': 1, 'status': 'draft', 'authorUserId': 'u'},
  'callout': {
    'title': 'Mootoririke',
    'status': 'closed',
    'calloutType': 'sar',
    'createdAt': '2026-09-01T10:00:00Z',
  },
  'members': [
    {'userId': 'u', 'name': 'Meeskonna liige', 'active': true},
  ],
  'crew': [],
  'equipment': [],
  'timeline': [],
};

void main() {
  testWidgets(
    'member sees existing summary but no editors or private persons on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CalloutReportScreen(
            organizationId: 'o',
            calloutId: 'c',
            loadReport: () async => report(false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ekspordi aruanne PDF-ina'), findsNothing);
      expect(find.textContaining('Sündmuse ID:'), findsNothing);
      expect(find.text('Varustuse juhtumid'), findsNothing);
      expect(find.text('Ettepanekud ja tähelepanekud'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Alus pukseeriti'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Lisa seotud isik'), findsNothing);
      expect(find.text('Salvesta mustand'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed report save retains edited summary and original source for conflict check',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: CalloutReportScreen(
            organizationId: 'o',
            calloutId: 'c',
            loadReport: () async => report(true),
            saveReport: (data) async {
              sent = data;
              throw Exception('offline');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final summary = find.widgetWithText(TextField, 'Kokkuvõte');
      expect(find.byTooltip('Ekspordi aruanne PDF-ina'), findsOneWidget);
      await tester.scrollUntilVisible(
        summary,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(summary, 'Täiendatud kokkuvõte');
      await tester.scrollUntilVisible(
        find.text('Salvesta mustand'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Salvesta mustand'));
      await tester.pumpAndSettle();
      expect(sent?['summary'], 'Täiendatud kokkuvõte');
      expect(sent?['expectedSummary'], 'Alus pukseeriti sadamasse.');
      await tester.scrollUntilVisible(
        summary,
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Täiendatud kokkuvõte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
