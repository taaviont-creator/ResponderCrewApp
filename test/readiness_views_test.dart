import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/duty_crew.dart';
import 'package:respondcrew_app/widgets/crew_readiness_card.dart';
import 'package:respondcrew_app/screens/main_navigation_shell.dart';

const crew = [
  DutyCrewMember(userId: 'a', name: 'Mari', status: 'onDuty', level: 'level1'),
  DutyCrewMember(
    userId: 'b',
    name: 'Jaan',
    status: 'delayed',
    level: 'level2',
    arrivalMinutes: 15,
  ),
];
void main() {
  testWidgets(
    'team detail exposes both SAR conditions and member profile action',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CrewReadinessView(
                members: crew,
                minimumCrew: 3,
                currentUid: 'a',
                onContact: (_, _) {},
                onOpenMember: (id) => opened = id,
              ),
            ),
          ),
        ),
      );
      expect(find.text('EI OLE REAGEERIMISVALMIS'), findsOneWidget);
      expect(find.text('Valves 1/3 · II aste: 0 — puudub'), findsOneWidget);
      expect(
        find.textContaining('II astme merepäästja puudub'),
        findsOneWidget,
      );
      expect(find.textContaining('Hilinemisega (+15 min)'), findsOneWidget);
      await tester.tap(find.text('Mari · Mina'));
      expect(opened, 'a');
    },
  );
  testWidgets('dashboard retains roster and contact controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CrewReadinessView(
            members: crew,
            minimumCrew: 3,
            currentUid: 'a',
            onContact: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('EI OLE REAGEERIMISVALMIS'), findsOneWidget);
    expect(find.text('Valves 1/3 · II aste: 0 — puudub'), findsOneWidget);
    expect(find.textContaining('Mari'), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsNWidgets(2));
  });
  testWidgets(
    'dashboard detail link stays usable when organization is paused',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrewReadinessCard(
              organizationId: 'o',
              currentUid: 'a',
              compact: true,
              onOpenDetails: () => opened = true,
              streamsForOrganization: (_) => CrewReadinessStreams(
                organization: Stream.value({
                  'dutyPaused': true,
                  'dutyPauseReason': 'Paati pole',
                }),
                members: Stream.value([]),
                availability: Stream.value([]),
                unavailable: Stream.value({}),
                minimum: Stream.value(3),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Paati pole'), findsOneWidget);
      await tester.tap(find.text('Vaata täpsemalt →'));
      expect(opened, true);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'full organization name fits narrow navigation and opens team tab',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: MainNavigationShell(
            currentIndex: 0,
            onDestinationSelected: (i) => index = i,
            child: const Scaffold(body: Text('Töölaud sisu')),
          ),
        ),
      );
      expect(find.text('Planeerimine'), findsNothing);
      expect(find.text('Ühingu valmidus'), findsNothing);
      await tester.tap(find.text('Ühingu reageerimisvalmidus'));
      expect(index, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
