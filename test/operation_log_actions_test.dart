import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/operation_log_model.dart';
import 'package:respondcrew_app/widgets/operation_log_actions.dart';

void main() {
  Future<void> showControls(
    WidgetTester tester, {
    String status = OperationLogStatus.onScene,
    required Future<void> Function(String) onAction,
    Future<void> Function()? onComment,
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: OperationLogActions(
              status: status,
              onAction: onAction,
              onComment: onComment ?? () async {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'actions save in one tap; duplicate taps are blocked and failures allow retry',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await showControls(
        tester,
        onAction: (action) async {
          expect(action, 'Otsing algas');
          calls++;
          if (calls == 1) await pending.future;
        },
      );
      await tester.tap(find.text('Otsing algas'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('Otsing algas'));
      expect(calls, 1);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Salvestamine ebaõnnestus'), findsOneWidget);
      await tester.tap(find.text('Otsing algas'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Salvestatud: Otsing algas'), findsOneWidget);
    },
  );

  testWidgets(
    'scene completion is immediate, returning remains available, only log closure is confirmed',
    (tester) async {
      final calls = <String>[];
      await showControls(tester, onAction: (action) async => calls.add(action));
      await tester.ensureVisible(find.text('Sündmuskohal tegevused tehtud'));
      await tester.tap(find.text('Sündmuskohal tegevused tehtud'));
      await tester.pumpAndSettle();
      expect(calls, ['Sündmuskohal tegevused tehtud']);
      expect(find.byType(AlertDialog), findsNothing);
      await showControls(
        tester,
        status: OperationLogStatus.completed,
        onAction: (action) async => calls.add(action),
      );
      await tester.ensureVisible(find.text('Tagasisõit'));
      await tester.tap(find.text('Tagasisõit'));
      await tester.pumpAndSettle();
      expect(calls.last, 'Tagasisõit');
      await tester.tap(find.text('Tagasi baasis'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Jätka logi'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      await tester.tap(find.text('Tagasi baasis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lõpeta operatiivlogi'));
      await tester.pumpAndSettle();
      expect(calls.last, 'Tagasi baasis');
    },
  );

  testWidgets('completed log retains comment control without live actions', (
    tester,
  ) async {
    var comments = 0;
    await showControls(
      tester,
      status: OperationLogStatus.returnedToBase,
      onAction: (_) async => fail('Closed log must not record live milestones'),
      onComment: () async {
        comments++;
      },
    );
    expect(find.text('Kiirtegevused'), findsNothing);
    await tester.tap(find.text('Lisa operatiivlogisse kommentaar'));
    await tester.pumpAndSettle();
    expect(comments, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('large buttons fit narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showControls(tester, scale: 1.6, onAction: (_) async {});
    for (final button in tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    )) {
      final size = tester.getSize(find.byWidget(button));
      expect(size.height, greaterThanOrEqualTo(56));
      expect(size.width, lessThanOrEqualTo(320));
    }
    await tester.ensureVisible(find.text('Lisa operatiivlogisse kommentaar'));
    expect(tester.takeException(), isNull);
  });
}
