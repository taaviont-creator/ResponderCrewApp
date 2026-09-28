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
  testWidgets(
    'type switch and chips preserve manual text; failed save retains form',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CalloutDraft? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: Scaffold(
            body: CreateCalloutDialog(
              onSave: (draft) async {
                saved = draft;
                throw Exception('offline');
              },
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'SAR sündmus'),
        'Minu sündmus',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kirjeldus ja lisainfo'),
        'Oma info',
      );
      await tester.tap(find.text('Inimene vees.'));
      await tester.pump();
      await tester.tap(find.text('TROSSI mereabi'));
      await tester.pump();
      await tester.tap(find.text('Mootoririke.'));
      await tester.pump();
      await tester.tap(find.text('SAR sündmus'));
      await tester.pump();
      await tester.tap(find.text('TROSSI mereabi'));
      await tester.pump();
      await tester.ensureVisible(find.text('Aktiveeri väljakutse'));
      await tester.tap(find.text('Aktiveeri väljakutse'));
      await tester.pumpAndSettle();
      expect(saved!.type, 'tross');
      expect(saved!.title, 'Minu sündmus');
      expect(saved!.description, 'Oma info\nInimene vees.\nMootoririke.');
      expect(saved!.responseTargetMinutes, 60);
      expect(find.textContaining('Sisestatud tekst säilib'), findsOneWidget);
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
                    label: 'Ava väljakutse operatsioonilogi',
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
        find.text('Ava väljakutse operatsioonilogi'),
      );
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    },
  );
}
