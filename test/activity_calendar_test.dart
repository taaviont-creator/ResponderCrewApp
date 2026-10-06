import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/activity_model.dart';
import 'package:respondcrew_app/models/activity_schedule.dart';
import 'package:respondcrew_app/services/activity_service.dart';
import 'package:respondcrew_app/screens/activities_screen.dart';
import 'package:respondcrew_app/widgets/activity_attendance_row.dart';
import 'package:respondcrew_app/widgets/activity_calendar.dart';
import 'package:respondcrew_app/widgets/activity_editor.dart';
import 'package:respondcrew_app/widgets/upcoming_activities.dart';

ActivityModel activity(
  String start, {
  String end = '',
  String org = 'org',
  String title = 'Merepäästekoolitus',
}) => ActivityModel(
  id: 'training',
  organizationId: org,
  commandId: org,
  title: title,
  description: 'Praktiline õpe',
  type: ActivityType.training,
  startTime: start,
  endTime: end,
  location: 'Sadam',
  createdBy: 'admin',
);

class FakeActivities extends ActivityService {
  List<ActivityModel> activities = [];
  bool admin = true, fail = false;
  final writes = <Map<String, dynamic>>[];
  @override
  Stream<List<ActivityModel>> streamOrganizationActivities({
    required String organizationId,
  }) => Stream.value(
    activities.where((a) => a.organizationId == organizationId).toList(),
  );
  @override
  Stream<bool> streamCanConfirmParticipation({
    required String organizationId,
    required String userId,
  }) => Stream.value(admin);
  @override
  Stream<List<ActivityMember>> streamActiveMembers(String organizationId) =>
      Stream.value(const [ActivityMember('member', 'Mari Mere')]);
  @override
  Stream<List<ActivityParticipantModel>> streamUserParticipations({
    required String organizationId,
    required String userId,
  }) => Stream.value([]);
  @override
  Stream<List<ActivityParticipantModel>> streamActivityParticipants({
    required String activityId,
    required String organizationId,
  }) => Stream.value([]);
  @override
  Future<void> confirmParticipation({
    required String activityId,
    required String userId,
    required String organizationId,
    required String attendanceStatus,
    required String confirmedBy,
    double? hours,
  }) async {
    writes.add({
      'user': userId,
      'status': attendanceStatus,
      'hours': hours,
      'org': organizationId,
    });
  }

  @override
  Future<void> addActivity({
    required String organizationId,
    required String title,
    required String description,
    required String type,
    required String startTime,
    String endTime = '',
    required String location,
    required String createdBy,
  }) async {
    writes.add({'start': startTime, 'end': endTime, 'title': title});
    if (fail) throw Exception('offline');
  }
}

Widget host(Widget child) => MaterialApp(
  locale: const Locale('et'),
  supportedLocales: const [Locale('et')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);

void main() {
  test('legacy Estonian and ISO dates represent the same Tallinn instant', () {
    expect(
      ActivitySchedule.parse('06.10.2026 kell 14:30')!.toUtc(),
      DateTime.utc(2026, 10, 6, 11, 30),
    );
    expect(
      ActivitySchedule.parse('2026-10-06T11:30:00Z'),
      ActivitySchedule.parse('2026-10-06 14:30'),
    );
    expect(
      ActivitySchedule.format(ActivitySchedule.parse('2026-01-06T12:30:00Z')),
      '06.01.2026 kell 14:30',
    );
    for (final raw in [
      '31.02.2026',
      '2026-02-31',
      '2026-10-06 25:00',
      'homme õhtul',
      '',
    ]) {
      expect(ActivitySchedule.parse(raw), isNull, reason: raw);
    }
  });
  test(
    'DST gap is rejected and selected times keep Estonian summer/winter offset',
    () {
      expect(
        ActivitySchedule.fromSelection(DateTime(2026, 3, 29), 3, 30),
        isNull,
      );
      expect(
        ActivitySchedule.fromSelection(DateTime(2026, 1, 6), 14, 30)!.toUtc(),
        DateTime.utc(2026, 1, 6, 12, 30),
      );
      expect(
        ActivitySchedule.fromSelection(DateTime(2026, 7, 6), 14, 30)!.toUtc(),
        DateTime.utc(2026, 7, 6, 11, 30),
      );
    },
  );
  test(
    'upcoming and ongoing events include legacy whole-day entries and stop at end',
    () {
      final now = DateTime.utc(2026, 10, 6, 12);
      expect(activity('06.10.2026').isUpcomingOrOngoing(now), isTrue);
      expect(activity('05.10.2026').isUpcomingOrOngoing(now), isFalse);
      final event = activity('06.10.2026 14:00', end: '06.10.2026 16:00');
      expect(event.isUpcomingOrOngoing(now), isTrue);
      expect(event.isUpcomingOrOngoing(DateTime.utc(2026, 10, 6, 13)), isFalse);
      expect(event.durationHours, 2);
    },
  );
  test(
    'multi-day calendar includes occupied days but excludes midnight end day',
    () {
      final event = activity('06.10.2026 14:00', end: '08.10.2026 00:00');
      expect(event.occursOn(DateTime(2026, 10, 6)), isTrue);
      expect(event.occursOn(DateTime(2026, 10, 7)), isTrue);
      expect(event.occursOn(DateTime(2026, 10, 8)), isFalse);
    },
  );
  testWidgets(
    'calendar selects a dated activity and changes month on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DateTime? selected;
      await tester.pumpWidget(
        host(
          ActivityCalendar(
            activities: [activity('06.10.2026 14:00')],
            selectedDay: DateTime(2026, 10, 1),
            onSelected: (v) => selected = v,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('calendar-2026-10-06')));
      expect(selected, DateTime(2026, 10, 6));
      await tester.tap(find.byTooltip('Järgmine kuu'));
      await tester.pump();
      expect(find.text('November 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'checkbox saves immediately, blocks duplicates and rolls back failures',
    (tester) async {
      final pending = Completer<void>();
      final writes = <bool>[];
      await tester.pumpWidget(
        host(
          ActivityAttendanceRow(
            name: 'Mari',
            confirmed: false,
            hours: 2,
            onSave: (checked, hours) async {
              writes.add(checked);
              expect(hours, 2);
              await pending.future;
            },
          ),
        ),
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      pending.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(find.textContaining('Salvestamine ebaõnnestus'), findsOneWidget);
      expect(writes, [true]);
    },
  );
  testWidgets('unchecking removes credited hours without opening a dialog', (
    tester,
  ) async {
    bool? value;
    double? savedHours = 99;
    await tester.pumpWidget(
      host(
        ActivityAttendanceRow(
          name: 'Mari',
          confirmed: true,
          hours: 3,
          onSave: (v, h) async {
            value = v;
            savedHours = h;
          },
        ),
      ),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(value, false);
    expect(savedHours, isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
  });
  testWidgets(
    'admin can check a member without RSVP; member cannot confirm attendance',
    (tester) async {
      final now = ActivitySchedule.inEstonia(DateTime.now());
      final service = FakeActivities()
        ..activities = [activity(ActivitySchedule.date(now))];
      Future<void> open(bool admin) async {
        service.admin = admin;
        await tester.pumpWidget(
          host(
            ActivitiesScreen(
              key: ValueKey(admin),
              organizationId: 'org',
              currentUid: 'admin',
              canManageActivities: admin,
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Merepäästekoolitus'));
        await tester.tap(find.text('Merepäästekoolitus'));
        await tester.pumpAndSettle();
      }

      await open(true);
      await tester.drag(find.byType(ListView).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(service.writes.single['user'], 'member');
      expect(
        service.writes.single['status'],
        ActivityAttendanceStatus.confirmed,
      );
      await open(false);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Muuda tegevust'), findsNothing);
    },
  );
  testWidgets(
    'dashboard shows Estonian legacy dates and drops previous organization data',
    (tester) async {
      final service = FakeActivities()
        ..activities = [
          activity('01.01.2099 12:00'),
          activity(
            '01.01.2099 12:00',
            org: 'other',
            title: 'Teise ühingu koolitus',
          ),
        ];
      await tester.pumpWidget(
        host(
          UpcomingActivities(
            organizationId: 'org',
            userId: 'member',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Merepäästekoolitus'), findsOneWidget);
      await tester.pumpWidget(
        host(
          UpcomingActivities(
            organizationId: 'other',
            userId: 'member',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Merepäästekoolitus'), findsNothing);
      expect(find.text('Teise ühingu koolitus'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'editor uses calendar and clock, saves UTC and retains input on error',
    (tester) async {
      final service = FakeActivities()..fail = true;
      await tester.pumpWidget(
        host(
          ActivityEditor(
            service: service,
            organizationId: 'org',
            userId: 'admin',
            initialDay: DateTime(2026, 10, 6),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pealkiri'),
        'Raadiokoolitus',
      );
      await tester.tap(find.text('Vali kuupäev ja kellaaeg').first);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Edasi'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Vali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(service.writes.single['start'], endsWith('Z'));
      expect(find.text('Raadiokoolitus'), findsOneWidget);
      expect(find.textContaining('Sisestatud andmed on alles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
