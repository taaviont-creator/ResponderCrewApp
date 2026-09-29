import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/callout_model.dart';
import 'package:respondcrew_app/screens/main_navigation_shell.dart';
import 'package:respondcrew_app/widgets/callout_link_opener.dart';

CalloutModel event(String org, String id) => CalloutModel(
  id: id,
  organizationId: org,
  commandId: org,
  title: 'Sündmus $id',
  description: '',
  location: '',
  status: 'active',
  priority: 'normal',
  createdBy: 'a',
  createdByName: 'Admin',
);

void main() {
  testWidgets(
    'cold notification opens exact detail and acknowledgement/rebuild does not return to list',
    (tester) async {
      String? pending = 'alarm-42';
      var opens = 0;
      late StateSetter rebuild;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MainNavigationShell(
                navigatorKey: navigator,
                currentIndex: 1,
                onDestinationSelected: (_) {},
                child: CalloutLinkOpener(
                  organizationId: 'org',
                  calloutId: pending,
                  load: (org, id) async {
                    opens++;
                    return event(org, id);
                  },
                  onOpened: () => setState(() => pending = null),
                  detailBuilder: (c) => Scaffold(
                    appBar: AppBar(title: Text('Sündmus ${c.id}')),
                    body: const Text(
                      'Minu reageerimine: Tulen / Hilinen / Ei tule',
                    ),
                  ),
                  child: const Scaffold(body: Text('Kõik väljakutsed')),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sündmus alarm-42'), findsOneWidget);
      expect(
        find.textContaining('Minu reageerimine').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Menüü').hitTestable(), findsOneWidget);
      rebuild(() {});
      await tester.pumpAndSettle();
      expect(find.text('Sündmus alarm-42'), findsOneWidget);
      expect(opens, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Kõik väljakutsed'), findsOneWidget);
      // Tapping the same notification again must work after it was acknowledged.
      rebuild(() => pending = 'alarm-42');
      await tester.pumpAndSettle();
      expect(find.text('Sündmus alarm-42'), findsOneWidget);
      expect(opens, 2);
    },
  );

  testWidgets(
    'late previous-organization fetch cannot replace the newest notification target',
    (tester) async {
      var org = 'first';
      String? id = 'old';
      final old = Completer<CalloutModel?>();
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return CalloutLinkOpener(
                organizationId: org,
                calloutId: id,
                load: (o, c) =>
                    o == 'first' ? old.future : Future.value(event(o, c)),
                onOpened: () => setState(() => id = null),
                detailBuilder: (c) =>
                    Scaffold(body: Text('${c.organizationId}/${c.id}')),
                child: const Scaffold(body: Text('Nimekiri')),
              );
            },
          ),
        ),
      );
      await tester.pump();
      rebuild(() {
        org = 'second';
        id = 'new';
      });
      await tester.pumpAndSettle();
      expect(find.text('second/new'), findsOneWidget);
      old.complete(event('first', 'old'));
      await tester.pumpAndSettle();
      expect(find.text('second/new'), findsOneWidget);
      expect(find.text('first/old'), findsNothing);
    },
  );

  testWidgets(
    'failed or wrong-organization lookup stays explicit and offers retry',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CalloutLinkOpener(
            organizationId: 'org',
            calloutId: 'alarm',
            load: (o, id) async {
              attempts++;
              return event(attempts == 1 ? 'wrong' : o, id);
            },
            detailBuilder: (c) => Scaffold(body: Text('Detail ${c.id}')),
            child: const Scaffold(body: Text('Nimekiri')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ei saanud avada'), findsOneWidget);
      expect(find.text('Detail alarm'), findsNothing);
      await tester.tap(find.text('Proovi uuesti'));
      await tester.pumpAndSettle();
      expect(find.text('Detail alarm'), findsOneWidget);
      expect(attempts, 2);
    },
  );
}
