import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/callout_model.dart';
import 'package:respondcrew_app/widgets/create_callout_dialog.dart';
import 'package:respondcrew_app/widgets/primary_action_button.dart';
import 'package:respondcrew_app/screens/main_navigation_shell.dart';
import 'package:respondcrew_app/theme/app_theme.dart';

void main() {
  test('TROSS target is separate from SAR and personal ETA', () {
    for (final n in [1, 15, 30, 45, 60]) {
      expect(CalloutType.validTarget('tross', n), isTrue);
    }
    for (final n in [null, 0, 61]) {
      expect(CalloutType.validTarget('tross', n), isFalse);
    }
    expect(CalloutType.validTarget('sar', null), isTrue);
    expect(CalloutType.validTarget('sar', 15), isFalse);
    expect(CalloutType.validTarget('unknown', null), isFalse);
  });
  for (final type in CalloutType.values) {
    testWidgets(
      '$type alarms with only a type selection; no text or location required',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<void>();
        CalloutDraft? saved;
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: CreateCalloutDialog(
                onSave: (draft) {
                  saved = draft;
                  calls++;
                  return pending.future;
                },
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Alarmeeri meeskond'),
              )
              .onPressed,
          isNull,
        );
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text(CalloutType.label(type)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alarmeeri meeskond'));
        await tester.pump();
        expect(saved!.type, type);
        expect(saved!.title, CalloutType.label(type));
        expect(saved!.description, '');
        expect(saved!.location, '');
        expect(
          saved!.responseTargetMinutes,
          type == CalloutType.tross ? 60 : null,
        );
        expect(saved!.phoneCenterId, isNull);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(calls, 1);
        pending.completeError(StateError('offline'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Sisestatud info säilib'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'optional details and chips survive type changes and a failed send',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CalloutDraft? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateCalloutDialog(
              onSave: (d) async {
                saved = d;
                throw StateError('offline');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('SAR sündmus'));
      await tester.pump();
      await tester.tap(find.text('Lisa teadaolev info (valikuline)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Pealkiri (valikuline)'),
        'Minu sündmus',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Kirjeldus ja lisainfo'),
        'Oma info',
      );
      await tester.tap(find.text('Inimene vees.'));
      await tester.pump();
      await tester.tap(find.text('TROSSI mereabi'));
      await tester.pump();
      await tester.tap(find.text('Mootoririke.'));
      await tester.pump();
      await tester.tap(find.text('Alarmeeri meeskond'));
      await tester.pumpAndSettle();
      expect(saved!.description, 'Oma info\nInimene vees.\nMootoririke.');
      expect(saved!.title, 'Minu sündmus');
      expect(saved!.type, 'tross');
      expect(find.text('Minu sündmus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow screen with enlarged text keeps primary action and navigation readable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: MainNavigationShell(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            child: const SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: PrimaryActionButton(
                    label: 'Ava väljakutse operatiivlogi',
                    onPressed: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(
        find.text('Ava väljakutse operatiivlogi'),
      );
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    },
  );
}
