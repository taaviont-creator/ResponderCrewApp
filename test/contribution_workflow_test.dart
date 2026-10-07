import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/activity_model.dart';
import 'package:respondcrew_app/models/statistics_model.dart';
import 'package:respondcrew_app/screens/activities_screen.dart';
import 'package:respondcrew_app/screens/contribution_form_screen.dart';
import 'package:respondcrew_app/services/activity_service.dart';
import 'package:respondcrew_app/widgets/activity_attendance_row.dart';

ActivityModel entry(String id, {String kind = 'scheduled'}) => ActivityModel(
  id: id,
  organizationId: 'org',
  commandId: 'org',
  title: id,
  description: 'Tehtud töö',
  type: 'maintenance',
  startTime: '2099-01-01',
  endTime: '',
  location: '',
  createdBy: 'u',
  entryKind: kind,
);
ActivityParticipantModel participation(String id, String uid) =>
    ActivityParticipantModel(
      id: '${id}_$uid',
      activityId: id,
      userId: uid,
      organizationId: 'org',
      commandId: 'org',
      status: 'attendedSelfReported',
      hours: 2.5,
    );

class ContributionActivities extends ActivityService {
  bool admin = false;
  final items = [
    entry('planeeritud'),
    entry('contribution_old'),
    entry('uus', kind: 'contribution'),
    entry('teise panus', kind: 'contribution'),
  ];
  final rows = [
    participation('contribution_old', 'u'),
    participation('uus', 'u'),
    participation('teise panus', 'other'),
  ];
  final writes = <Map<String, dynamic>>[];
  @override
  Stream<List<ActivityModel>> streamOrganizationActivities({
    required String organizationId,
  }) => Stream.value(items);
  @override
  Stream<bool> streamCanConfirmParticipation({
    required String organizationId,
    required String userId,
  }) => Stream.value(admin);
  @override
  Stream<List<ActivityMember>> streamActiveMembers(String organizationId) =>
      Stream.value(const [
        ActivityMember('u', 'Mari'),
        ActivityMember('other', 'Jüri'),
      ]);
  @override
  Stream<List<ActivityParticipantModel>> streamUserParticipations({
    required String organizationId,
    required String userId,
  }) => Stream.value(rows.where((p) => p.userId == userId).toList());
  @override
  Stream<List<ActivityParticipantModel>> streamOrganizationParticipations(
    String organizationId,
  ) => Stream.value(rows);
  @override
  Stream<List<ActivityParticipantModel>> streamActivityParticipants({
    required String activityId,
    required String organizationId,
  }) => Stream.value(rows.where((p) => p.activityId == activityId).toList());
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
      'id': activityId,
      'user': userId,
      'status': attendanceStatus,
      'hours': hours,
    });
  }
}

Widget host(Widget child) => MaterialApp(
  locale: const Locale('et'),
  supportedLocales: const [Locale('et')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);
// Inspect the InputDecorator through the TextField to target form labels.
Finder input(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  test('legacy and new contributions are never upcoming scheduled events', () {
    for (final a in [
      entry('contribution_old'),
      entry('new', kind: 'contribution'),
    ]) {
      expect(a.isContribution, isTrue);
      expect(a.isUpcomingOrOngoing(DateTime(2026)), isFalse);
    }
    expect(entry('planned').isContribution, isFalse);
    expect(entry('planned').isUpcomingOrOngoing(DateTime(2026)), isTrue);
  });
  for (final width in [320.0, 900.0]) {
    testWidgets(
      'contribution form $width retains failed submission and reuses request ID',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          host(
            ContributionFormScreen(
              organizationId: 'org',
              currentUid: 'u',
              canManage: false,
              requestId: 'stable',
              initialMemberId: 'other',
              saveContribution: (data) async {
                writes.add(data);
                throw Exception('offline');
              },
            ),
          ),
        );
        await tester.enterText(input('Mida tegid?'), 'Pesin paati');
        await tester.ensureVisible(input('Kulunud tunnid'));
        await tester.enterText(input('Kulunud tunnid'), '2,5');
        await tester.ensureVisible(input('Kirjeldus (valikuline)'));
        await tester.enterText(
          input('Kirjeldus (valikuline)'),
          'Puhastasin teki',
        );
        await tester.scrollUntilVisible(
          find.text('Salvesta panus'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Salvesta panus'));
        await tester.pumpAndSettle();
        expect(writes.single['hours'], 2.5);
        expect(writes.single['memberIds'], ['u']);
        expect(writes.single['description'], 'Puhastasin teki');
        expect(find.byType(CheckboxListTile), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Salvesta panus'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Salvesta panus'));
        await tester.pumpAndSettle();
        expect(writes.length, 2);
        expect(writes.last['requestId'], 'stable');
        expect(writes.last['title'], 'Pesin paati');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('admin selects a group; no selection defaults to self', (
    tester,
  ) async {
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      host(
        ContributionFormScreen(
          organizationId: 'org',
          currentUid: 'u',
          canManage: true,
          requestId: 'stable',
          members: [
            MemberContribution({'userId': 'u', 'name': 'Mari', 'active': true}),
            MemberContribution({
              'userId': 'other',
              'name': 'Jüri',
              'active': true,
            }),
          ],
          saveContribution: (data) async {
            writes.add(data);
            throw Exception('offline');
          },
        ),
      ),
    );
    await tester.enterText(input('Mida tegid?'), 'Niitmine');
    await tester.ensureVisible(input('Kulunud tunnid'));
    await tester.enterText(input('Kulunud tunnid'), '1');
    await tester.scrollUntilVisible(
      find.text('Salvesta panus'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvesta panus'));
    await tester.pumpAndSettle();
    expect(writes.single['memberIds'], ['u']);
    await tester.ensureVisible(find.text('Mari'));
    await tester.tap(find.text('Mari'));
    await tester.pump();
    await tester.ensureVisible(find.text('Jüri'));
    await tester.tap(find.text('Jüri'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Salvesta panus'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvesta panus'));
    await tester.pumpAndSettle();
    expect(writes.last['memberIds'], containsAll(['u', 'other']));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'scheduled list excludes contributions; member sees own contribution status without RSVP',
    (tester) async {
      final service = ContributionActivities();
      await tester.pumpWidget(
        host(
          ActivitiesScreen(
            organizationId: 'org',
            currentUid: 'u',
            canManageActivities: false,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nimekiri'));
      await tester.pumpAndSettle();
      expect(find.text('planeeritud'), findsOneWidget);
      expect(find.text('contribution_old'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          ActivitiesScreen(
            organizationId: 'org',
            currentUid: 'u',
            canManageActivities: false,
            contributionsOnly: true,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('planeeritud'), findsNothing);
      expect(find.text('teise panus'), findsNothing);
      expect(find.text('contribution_old'), findsOneWidget);
      await tester.tap(find.text('contribution_old'));
      await tester.pumpAndSettle();
      expect(find.text('Osalen'), findsNothing);
      expect(find.byType(ActivityAttendanceRow), findsNothing);
    },
  );
  testWidgets(
    'admin confirms recorded participant and preserves entered hours',
    (tester) async {
      final service = ContributionActivities()..admin = true;
      await tester.pumpWidget(
        host(
          ActivitiesScreen(
            organizationId: 'org',
            currentUid: 'u',
            canManageActivities: true,
            contributionsOnly: true,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('contribution_old'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityAttendanceRow), findsOneWidget);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(service.writes.single, {
        'id': 'contribution_old',
        'user': 'u',
        'status': 'confirmed',
        'hours': 2.5,
      });
      expect(find.text('Osalen'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
