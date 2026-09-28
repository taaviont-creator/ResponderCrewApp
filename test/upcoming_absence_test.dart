import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/upcoming_absence.dart';
import 'package:respondcrew_app/models/planned_unavailability_model.dart';
import 'package:respondcrew_app/models/planned_unavailability_rule_model.dart';
import 'package:respondcrew_app/widgets/home_absence_preview.dart';

PlannedUnavailabilityModel period(
  DateTime start, {
  String user = 'me',
  bool cancelled = false,
}) => PlannedUnavailabilityModel(
  id: start.toIso8601String(),
  organizationId: 'org',
  commandId: 'org',
  userId: user,
  startAt: start,
  endAt: start.add(const Duration(hours: 1)),
  note: '',
  status: cancelled ? 'cancelled' : 'active',
  createdBy: user,
);
PlannedUnavailabilityRuleModel rule() => const PlannedUnavailabilityRuleModel(
  id: 'weekly',
  organizationId: 'org',
  commandId: 'org',
  userId: 'me',
  daysOfWeek: [DateTime.monday],
  startTime: '10:00',
  endTime: '11:00',
  startMinute: 600,
  endMinute: 660,
  note: '',
  status: 'active',
  createdBy: 'me',
);
void main() {
  test(
    'preview sorts next two and excludes past, ongoing, cancelled and other users',
    () {
      final now = DateTime(2026, 9, 28, 9);
      final values = upcomingAbsences(
        userId: 'me',
        now: now,
        rules: [],
        periods: [
          period(now.add(const Duration(hours: 4))),
          period(now.add(const Duration(hours: 2))),
          period(now.add(const Duration(hours: 3))),
          period(now.subtract(const Duration(minutes: 30))),
          period(now.add(const Duration(minutes: 5)), cancelled: true),
          period(now.add(const Duration(minutes: 6)), user: 'other'),
        ],
      );
      expect(values.map((v) => v.start.hour), [11, 12]);
    },
  );
  test(
    'weekly occurrences combine with one-off periods and duplicate ranges collapse',
    () {
      final values = upcomingAbsences(
        userId: 'me',
        now: DateTime(2026, 9, 28, 9),
        rules: [rule()],
        periods: [period(DateTime(2026, 9, 28, 10))],
      );
      expect(values.length, 2);
      expect(values[0].start, DateTime(2026, 9, 28, 10));
      expect(values[1].start, DateTime(2026, 10, 5, 10));
      expect(values[1].recurring, isTrue);
    },
  );
  testWidgets(
    'home shortcut opens planning and shows no more than two periods',
    (tester) async {
      var opened = false;
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeAbsencePreview(
              userId: 'me',
              periods: [
                for (var i = 1; i <= 3; i++) period(now.add(Duration(days: i))),
              ],
              rules: [],
              onPlan: () => opened = true,
            ),
          ),
        ),
      );
      expect(find.text('Järgmised valvevälised ajad'), findsOneWidget);
      expect(find.textContaining(' – '), findsNWidgets(2));
      await tester.tap(find.text('Planeeri valvevälist aega'));
      expect(opened, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
