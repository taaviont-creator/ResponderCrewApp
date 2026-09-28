import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/availability_model.dart';
import 'package:respondcrew_app/models/duty_crew.dart';
import 'package:respondcrew_app/models/planned_unavailability_model.dart';
import 'package:respondcrew_app/services/member_contact_service.dart';
import 'package:respondcrew_app/theme/app_theme.dart';
import 'package:respondcrew_app/widgets/crew_readiness_card.dart';
import 'package:respondcrew_app/widgets/home_header.dart';

const crew = [
  DutyCrewMember(
    userId: 'a',
    name: 'Mari Merepäästja',
    status: 'onDuty',
    level: 'level2',
  ),
  DutyCrewMember(
    userId: 'b',
    name: 'Jaan',
    status: 'delayed',
    level: 'level1',
    arrivalMinutes: 30,
  ),
];
void main() {
  test(
    'crew list and readiness exclude scheduled unavailability and inactive membership',
    () {
      final now = DateTime(2026, 9, 28, 12);
      final list = dutyCrew(
        memberships: [
          for (final uid in ['a', 'b', 'c'])
            {
              'userId': uid,
              'displayName': uid,
              'status': 'active',
              'isActive': true,
              'seaRescueLevel': 'level2',
            },
          {
            'userId': 'removed',
            'displayName': 'removed',
            'status': 'removed',
            'isActive': true,
          },
        ],
        availability: [
          for (final uid in ['a', 'b', 'c', 'removed'])
            AvailabilityModel(
              id: uid,
              userId: uid,
              organizationId: 'o',
              commandId: 'o',
              status: uid == 'b' ? 'delayed' : 'onDuty',
              manualStatus: 'onDuty',
              responseMinutes: 30,
            ),
        ],
        periods: [
          PlannedUnavailabilityModel(
            id: 'p',
            organizationId: 'o',
            commandId: 'o',
            userId: 'a',
            startAt: now.subtract(const Duration(minutes: 1)),
            endAt: now.add(const Duration(minutes: 1)),
            note: '',
            status: 'active',
            createdBy: 'a',
          ),
        ],
        rules: [],
        now: now,
      );
      expect(list.map((m) => m.userId), ['c', 'b']);
      expect(list.last.arrivalMinutes, 30);
    },
  );
  test(
    'contact links open only dialer or empty SMS composer, reject malformed numbers',
    () {
      expect(
        phoneContactUri('+372 555-1234', sms: false)?.toString(),
        'tel:+3725551234',
      );
      expect(
        phoneContactUri('+372 555-1234', sms: true)?.toString(),
        'sms:+3725551234',
      );
      expect(phoneContactUri('555?body=send', sms: true), isNull);
      expect(phoneContactUri(null, sms: false), isNull);
    },
  );
  testWidgets(
    'compact header uses first name and organization-specific role; title switches organization',
    (tester) async {
      var switched = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: Scaffold(
            appBar: AppBar(
              title: HomeOrganizationTitle(
                name: 'Päästeühing',
                onSwitch: () => switched = true,
              ),
            ),
            body: const HomeGreeting(displayName: 'Taavi Onton', role: 'Liige'),
          ),
        ),
      );
      expect(find.text('Tere, Taavi'), findsOneWidget);
      expect(find.text('Liige'), findsOneWidget);
      expect(find.text('Aktiivne ühing'), findsNothing);
      expect(find.text('Platvormi admin'), findsNothing);
      await tester.tap(find.text('Päästeühing'));
      expect(switched, isTrue);
    },
  );
  testWidgets(
    'crew exposes actual states and contact buttons without counting delayed II as ready',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CrewReadinessView(
                members: crew,
                minimumCrew: 2,
                currentUid: 'a',
                onContact: (uid, sms) => calls.add('$uid:$sms'),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Miinimumkoosseis puudu'), findsOneWidget);
      expect(find.textContaining('Hilinemisega (+30 min)'), findsOneWidget);
      await tester.tap(find.byTooltip('Helista: Jaan'));
      await tester.tap(find.byTooltip('SMS: Jaan'));
      expect(calls, ['b:false', 'b:true']);
    },
  );
  testWidgets(
    '320px large text keeps status controls and crew contact targets usable',
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  PersonalStatusChoices(
                    status: 'onDuty',
                    minutes: 30,
                    saving: false,
                    plannedUnavailable: false,
                    onSelect: (_) {},
                  ),
                  CrewReadinessView(
                    members: crew,
                    minimumCrew: 1,
                    currentUid: 'a',
                    onContact: (_, _) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byTooltip('SMS: Jaan'));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    },
  );
  testWidgets(
    'planned absence disables ready selection and pending save disables all statuses',
    (tester) async {
      var selected = '';
      Future<void> show(bool saving) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonalStatusChoices(
              status: 'onDuty',
              minutes: 15,
              saving: saving,
              plannedUnavailable: true,
              onSelect: (s) => selected = s,
            ),
          ),
        ),
      );
      await show(false);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Valves'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Mitte valves'));
      expect(selected, 'offDuty');
      await show(true);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Mitte valves'),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
