import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/operation_log_model.dart';
import 'package:respondcrew_app/models/operation_log_report.dart';
import 'package:respondcrew_app/screens/operation_log_report_screen.dart';

const log = OperationLogModel(
  id: 'log',
  organizationId: 'a',
  commandId: 'a',
  createdBy: 'admin',
  createdByName: 'Päästja',
  type: 'other',
  title: 'Testoperatsioon',
  description: 'Harjutus',
  status: 'returnedToBase',
  summary: 'Valmis',
  outcome: 'Kõik baasis',
  completedBy: 'admin',
);

OperationLogEventModel event(
  String id,
  String title,
  DateTime? at, {
  String org = 'a',
  String parent = 'log',
  double? lat,
  double? lon,
}) => OperationLogEventModel(
  id: id,
  organizationId: org,
  commandId: org,
  operationLogId: parent,
  type: 'manualNote',
  status: 'onScene',
  title: title,
  text: title,
  description: '',
  createdBy: 'admin',
  latitude: lat,
  longitude: lon,
  accuracyMeters: 8,
  createdAt: at,
);

void main() {
  test(
    'extract preserves chronology, full dates, GPS and summary without duplicate notes',
    () {
      final report = buildOperationLogReport(log, [
        event('2', 'Kohal', DateTime(2026, 9, 27, 15, 35, 6)),
        event(
          '1',
          'Teel',
          DateTime(2026, 9, 27, 15, 30, 1),
          lat: 59.45,
          lon: 24.75,
        ),
        event('other-org', 'SECRET ORG', DateTime(2026), org: 'b'),
        event('other-log', 'SECRET LOG', DateTime(2026), parent: 'another'),
      ]);
      expect(report.indexOf('Teel'), lessThan(report.indexOf('Kohal')));
      expect(report, contains('27.09.2026 15:30:01'));
      expect(report, contains('GPS: 59.45000, 24.75000 (täpsus ~8 m)'));
      expect(report, contains('Asukohta ei salvestatud'));
      expect(report, contains('Lõppkokkuvõte\nValmis'));
      expect(report, contains('Tulemus\nKõik baasis'));
      expect(report, isNot(contains('SECRET')));
      expect('Teel'.allMatches(report).length, 1);
    },
  );
  test(
    'unknown time and invalid GPS are explicit, never replaced by fabricated values',
    () {
      final report = buildOperationLogReport(log, [
        event('1', 'Märge', null, lat: 99, lon: 1),
      ]);
      expect(report, contains('Kellaaeg pole salvestatud'));
      expect(report, contains('Asukohta ei salvestatud'));
      expect(report, isNot(contains('1970')));
      expect(report, isNot(contains('GPS:')));
    },
  );
  testWidgets(
    'reopening a completed log displays its persisted timeline and copy action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OperationLogReportScreen(
            log: log,
            organizationId: 'a',
            eventStream: Stream.value([
              event(
                'saved',
                'Salvestatud sündmus',
                DateTime(2026, 9, 27, 15, 30),
                lat: 59,
                lon: 24,
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logi väljavõte'), findsOneWidget);
      expect(find.textContaining('Salvestatud sündmus'), findsOneWidget);
      expect(find.textContaining('GPS: 59.00000, 24.00000'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'Kopeeri väljavõte'))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'failed history is not presented as an empty successful extract',
    (tester) async {
      final stream = StreamController<List<OperationLogEventModel>>();
      await tester.pumpWidget(
        MaterialApp(
          home: OperationLogReportScreen(
            log: log,
            organizationId: 'a',
            eventStream: stream.stream,
          ),
        ),
      );
      stream.addError(StateError('permission denied'));
      await tester.pumpAndSettle();
      expect(find.textContaining('laadimine ebaõnnestus'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'Kopeeri väljavõte'))
            .onPressed,
        isNull,
      );
      await stream.close();
    },
  );
}
