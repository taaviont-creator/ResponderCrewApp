import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/operation_log_model.dart';
import 'package:respondcrew_app/models/operation_log_report.dart';
import 'package:respondcrew_app/screens/operation_log_report_screen.dart';
import 'package:respondcrew_app/widgets/operation_note_dialog.dart';

const log = OperationLogModel(
  id: 'log',
  organizationId: 'org',
  commandId: 'org',
  createdBy: 'a',
  createdByName: 'A',
  type: 'other',
  title: 'Väljakutse',
  description: '',
  status: 'returnedToBase',
  summary: 'Valmis',
  outcome: '',
  completedBy: 'a',
  calloutId: 'c',
);
OperationLogEventModel event(String id, DateTime saved, {DateTime? actual}) =>
    OperationLogEventModel(
      id: id,
      organizationId: 'org',
      commandId: 'org',
      operationLogId: 'log',
      type: 'manualNote',
      status: 'returnedToBase',
      title: id,
      text: id,
      description: '',
      createdBy: 'a',
      createdByName: 'Juht',
      createdAt: saved,
      occurredAt: actual,
    );
void main() {
  test(
    'crew and change audit use the exact callout; absent members are not listed as participants',
    () {
      final people = [
        {
          'organizationId': 'org',
          'calloutId': 'c',
          'userName': 'Osaleja',
          'status': 'confirmed',
          'hours': 2,
        },
        {
          'organizationId': 'org',
          'calloutId': 'c',
          'userName': 'Puuduja',
          'status': 'absent',
        },
        {
          'organizationId': 'elsewhere',
          'calloutId': 'c',
          'userName': 'SECRET',
          'status': 'confirmed',
        },
      ];
      final changes = [
        {
          'organizationId': 'org',
          'calloutId': 'c',
          'userName': 'Osaleja',
          'before': null,
          'after': {'status': 'confirmed', 'hours': 2},
          'createdByName': 'Juht',
          'createdAt': DateTime(2026, 9, 28, 12),
        },
      ];
      final report = buildOperationLogReport(
        log,
        [],
        participants: people,
        attendanceHistory: changes,
      );
      expect(report, contains('Osaleja — 2 t'));
      expect(report, contains('Muutja: Juht'));
      expect(report, contains('Märkimata → Osales (2 t)'));
      expect(report, isNot(contains('SECRET')));
      expect(report, isNot(contains('Puuduja')));
    },
  );
  test(
    'retrospective note is ordered by occurrence while recording insertion date and author',
    () {
      final report = buildOperationLogReport(log, [
        event('Hilisem sündmus', DateTime(2026, 9, 27, 15)),
        event(
          'Varasem sündmus',
          DateTime(2026, 9, 28, 10),
          actual: DateTime(2026, 9, 27, 14),
        ),
      ]);
      expect(
        report.indexOf('Varasem sündmus'),
        lessThan(report.indexOf('Hilisem sündmus')),
      );
      expect(report, contains('Lisatud: 28.09.2026 10:00:00'));
      expect(report, contains('27.09.2026 14:00:00'));
      expect(report, contains('Autor: Juht'));
    },
  );
  testWidgets('failed crew history blocks copying an incomplete report', (
    tester,
  ) async {
    final history = StreamController<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      MaterialApp(
        home: OperationLogReportScreen(
          log: log,
          organizationId: 'org',
          eventStream: Stream.value([]),
          participantStream: Stream.value([]),
          attendanceHistoryStream: history.stream,
        ),
      ),
    );
    history.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('laadimine ebaõnnestus'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Kopeeri väljavõte',
            ),
          )
          .onPressed,
      isNull,
    );
    await history.close();
  });
  testWidgets(
    'retrospective note retains input on failed save and submits actual time',
    (tester) async {
      var attempts = 0;
      DateTime? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => OperationNoteDialog(
                    onSave: (text, at) async {
                      attempts++;
                      expect(text, 'Täiendus');
                      submitted = at;
                      if (attempts == 1) throw StateError('offline');
                    },
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
      await tester.enterText(find.byType(TextField), 'Täiendus');
      await tester.tap(find.text('Lisa tagantjärele'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvesta kommentaar'));
      await tester.pumpAndSettle();
      expect(find.text('Täiendus'), findsOneWidget);
      expect(find.textContaining('Salvestamine ebaõnnestus'), findsOneWidget);
      await tester.tap(find.text('Salvesta kommentaar'));
      await tester.pumpAndSettle();
      expect(submitted, isNotNull);
      expect(find.byType(OperationNoteDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'summary amendment stays open after failure and retains both fields',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => OperationSummaryDialog(
                    summary: 'Vana',
                    outcome: 'Valmis',
                    onSave: (summary, outcome) async {
                      attempts++;
                      expect(summary, 'Uus');
                      expect(outcome, 'Valmis');
                      if (attempts == 1) throw StateError('offline');
                    },
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
      await tester.enterText(find.byType(TextField).first, 'Uus');
      await tester.tap(find.text('Salvesta kokkuvõte'));
      await tester.pumpAndSettle();
      expect(find.text('Uus'), findsOneWidget);
      expect(find.textContaining('Muudatused on alles'), findsOneWidget);
      await tester.tap(find.text('Salvesta kokkuvõte'));
      await tester.pumpAndSettle();
      expect(find.byType(OperationSummaryDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
