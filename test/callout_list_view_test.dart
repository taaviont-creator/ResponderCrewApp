import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/callout_model.dart';
import 'package:respondcrew_app/widgets/callout_list_view.dart';
import 'package:respondcrew_app/widgets/active_callouts_card.dart';

CalloutModel event(String id, String status, {bool drill = false}) =>
    CalloutModel(
      id: id,
      organizationId: 'org',
      commandId: 'org',
      title: id,
      description: '',
      location: '',
      status: status,
      priority: 'high',
      createdBy: 'admin',
      createdByName: 'Admin',
      isTest: drill,
    );

void main() {
  final active = event('Päästetöö', CalloutStatus.active);
  final drill = event('Harjutus', CalloutStatus.active, drill: true);
  final closed = event('Vana sündmus', CalloutStatus.closed);
  final cancelled = event('Tühistatud sündmus', CalloutStatus.cancelled);

  testWidgets(
    'starts active, drills stay visible, completed and cancelled open only on their tab',
    (tester) async {
      final built = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalloutListView(
              callouts: [active, drill, closed, cancelled],
              itemBuilder: (c) {
                built.add(c.id);
                return Text(c.title);
              },
            ),
          ),
        ),
      );
      expect(find.text('Päästetöö'), findsOneWidget);
      expect(find.text('Harjutus'), findsOneWidget);
      expect(built, isNot(contains('Vana sündmus')));
      expect(find.text('Näita test-/proovisündmusi'), findsNothing);
      await tester.tap(find.text('Lõpetatud (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Vana sündmus'), findsOneWidget);
      expect(find.text('Tühistatud sündmus'), findsOneWidget);
      expect(find.text('Päästetöö'), findsNothing);
      await tester.tap(find.text('Aktiivsed (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Päästetöö'), findsOneWidget);
      expect(find.text('Vana sündmus'), findsNothing);
    },
  );

  testWidgets(
    'live closure leaves active tab empty and history remains separate; org switch resets tab',
    (tester) async {
      Widget app(List<CalloutModel> data, {String org = 'org'}) => MaterialApp(
        home: Scaffold(
          body: CalloutListView(
            key: ValueKey(org),
            callouts: data,
            itemBuilder: (c) => Text(c.title),
          ),
        ),
      );
      await tester.pumpWidget(app([active]));
      await tester.pumpWidget(app([event(active.id, CalloutStatus.closed)]));
      expect(find.text('Aktiivseid väljakutseid ei ole.'), findsOneWidget);
      expect(find.text('Päästetöö'), findsNothing);
      await tester.tap(find.text('Lõpetatud (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Päästetöö'), findsOneWidget);
      await tester.pumpWidget(app([], org: 'other'));
      expect(find.text('Aktiivseid väljakutseid ei ole.'), findsOneWidget);
      expect(find.text('Päästetöö'), findsNothing);
    },
  );

  testWidgets('two tabs fit a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: CalloutListView(
            callouts: [],
            itemBuilder: (_) => const SizedBox(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lõpetatud (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Lõpetatud väljakutseid ei ole.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard shows an active drill with explicit label and exact navigation',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveCalloutsCard(
              organizationId: 'org',
              userId: 'member',
              userName: 'Liige',
              calloutsStream: Stream.value([drill]),
              responseBuilder: (_) => const Text('Vasta'),
              onOpen: (id) => opened = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PROOVIHÄIRE · SAR sündmus'), findsOneWidget);
      await tester.tap(find.text('Ava väljakutse'));
      expect(opened, drill.id);
    },
  );
}
