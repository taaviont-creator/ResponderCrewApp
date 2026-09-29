import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/availability_model.dart';
import 'package:respondcrew_app/widgets/crew_readiness_card.dart';

void main() {
  testWidgets(
    'member sees crew; pause survives schedule error; recovery restores readiness',
    (tester) async {
      final organization = StreamController<Map<String, dynamic>>();
      final unavailable = StreamController<Set<String>>();
      final streams = CrewReadinessStreams(
        organization: organization.stream,
        members: Stream.value([
          {
            'userId': 'rescuer',
            'displayName': 'Mari',
            'status': 'active',
            'isActive': true,
            'seaRescueLevel': 'level2',
          },
        ]),
        availability: Stream.value([
          const AvailabilityModel(
            id: 'rescuer_org',
            userId: 'rescuer',
            organizationId: 'org',
            commandId: 'org',
            status: 'onDuty',
            manualStatus: 'onDuty',
          ),
        ]),
        unavailable: unavailable.stream,
        minimum: Stream.value(1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrewReadinessCard(
              organizationId: 'org',
              currentUid: 'ordinary-member',
              streamsForOrganization: (_) => streams,
            ),
          ),
        ),
      );
      organization.add({'dutyPaused': false});
      unavailable.add({});
      await tester.pump();
      await tester.pump();
      expect(find.text('SAR: reageerimisvalmis'), findsOneWidget);
      expect(find.text('Mari'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      unavailable.add({'rescuer'});
      await tester.pump();
      await tester.pump();
      expect(find.text('Mari'), findsNothing);
      expect(find.text('SAR: reageerimisvalmis'), findsNothing);
      unavailable.addError(StateError('network'));
      organization.add({
        'dutyPaused': true,
        'dutyPauseReason': 'Hooaeg on läbi',
      });
      await tester.pump();
      await tester.pump();
      expect(find.text('Ühing on valvest maas'), findsOneWidget);
      expect(find.text('Hooaeg on läbi'), findsOneWidget);
      organization.add({'dutyPaused': false});
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('ei õnnestunud laadida'), findsOneWidget);
      unavailable.add({});
      await tester.pump();
      await tester.pump();
      expect(find.text('SAR: reageerimisvalmis'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      unawaited(organization.close());
      unawaited(unavailable.close());
      await tester.pump();
    },
  );

  testWidgets('switching organization clears previous pause and crew', (
    tester,
  ) async {
    CrewReadinessStreams streams(String org) => CrewReadinessStreams(
      organization: Stream.value({
        'dutyPaused': org == 'old',
        'dutyPauseReason': 'Vana ühing',
      }),
      members: Stream.value([]),
      availability: Stream.value([]),
      unavailable: Stream.value({}),
      minimum: Stream.value(1),
    );
    Future<void> show(String org) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrewReadinessCard(
              organizationId: org,
              currentUid: 'member',
              streamsForOrganization: streams,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await show('old');
    expect(find.text('Vana ühing'), findsOneWidget);
    await show('new');
    expect(find.text('Vana ühing'), findsNothing);
    expect(find.text('Ühingu reageerimisvalmidus'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
