import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/widgets/minimum_crew_dialog.dart';
import 'package:respondcrew_app/widgets/member_permission_settings.dart';

void main() {
  testWidgets(
    'crew dialog validates and survives focused dismissal and reopening',
    (tester) async {
      int? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showDialog<int>(
                    context: context,
                    builder: (_) => const MinimumCrewDialog(initialValue: 2),
                  );
                },
                child: const Text('Ava'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ava'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '-1');
      await tester.tap(find.text('Salvesta'));
      await tester.pump();
      expect(find.text('Sisesta korrektne arv.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(find.text('Salvesta'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(saved, 4);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ava'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Katkesta'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'permission switches receive live settings without leaving route and patch one field',
    (tester) async {
      final stream = StreamController<Map<String, dynamic>>();
      final done = Completer<void>();
      String? field;
      bool? value;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberPermissionSettings(
              settings: stream.stream,
              save: (f, v) {
                field = f;
                value = v;
                return done.future;
              },
            ),
          ),
        ),
      );
      stream.add({});
      await tester.pump();
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pump();
      expect(field, 'allowMembersToCreateActivities');
      expect(value, isTrue);
      expect(
        tester
            .widget<SwitchListTile>(find.byType(SwitchListTile).first)
            .onChanged,
        isNull,
      );
      stream.add({
        'allowMembersToCreateActivities': true,
        'allowMembersToViewStatistics': true,
      });
      done.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).at(1)).value,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      unawaited(stream.close());
    },
  );
  testWidgets('failed permission save unlocks switches and reports failure', (
    tester,
  ) async {
    final stream = StreamController<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberPermissionSettings(
            settings: stream.stream,
            save: (_, _) async => throw StateError('offline'),
          ),
        ),
      ),
    );
    stream.add({});
    await tester.pump();
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text('Seadete muutmine ebaõnnestus. Proovi uuesti.'),
      findsOneWidget,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byType(SwitchListTile).first)
          .onChanged,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    unawaited(stream.close());
  });
}
