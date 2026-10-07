import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/effective_availability.dart';
import 'package:respondcrew_app/models/upcoming_absence.dart';
import 'package:respondcrew_app/models/planned_unavailability_rule_model.dart';

PlannedUnavailabilityRuleModel rule(int weekday, int start, int end) =>
    PlannedUnavailabilityRuleModel(
      id: 'r',
      organizationId: 'org',
      commandId: 'org',
      userId: 'u',
      daysOfWeek: [weekday],
      startTime: '',
      endTime: '',
      startMinute: start,
      endMinute: end,
      note: '',
      status: 'active',
      createdBy: 'u',
    );
bool unavailable(String instant, PlannedUnavailabilityRuleModel r) =>
    EffectiveAvailability.isPlannedUnavailable(
      userId: 'u',
      periods: const [],
      rules: [r],
      now: DateTime.parse(instant),
    );

void main() {
  test(
    'recurring availability uses Estonia civil time regardless of UTC/device representation',
    () {
      final monday = rule(DateTime.monday, 600, 660);
      expect(unavailable('2026-09-28T07:00:00Z', monday), true);
      expect(unavailable('2026-09-28T08:00:00Z', monday), false);
      expect(unavailable('2026-12-28T08:00:00Z', monday), true);
      expect(unavailable('2026-12-28T09:00:00Z', monday), false);
      final midnight = rule(DateTime.monday, 0, 60);
      expect(unavailable('2026-09-27T21:30:00Z', midnight), true);
      expect(unavailable('2026-09-27T20:30:00Z', midnight), false);
    },
  );
  test(
    'repeated autumn hour and skipped spring hour match server civil-time rules',
    () {
      final sunday = rule(DateTime.sunday, 180, 240);
      expect(unavailable('2026-10-25T00:30:00Z', sunday), true);
      expect(unavailable('2026-10-25T01:30:00Z', sunday), true);
      expect(unavailable('2026-10-25T02:00:00Z', sunday), false);
      expect(unavailable('2026-03-29T00:59:00Z', sunday), false);
      expect(unavailable('2026-03-29T01:00:00Z', sunday), false);
    },
  );
  test('upcoming weekly periods remain at 10:00 Estonia across DST', () {
    final result = upcomingAbsences(
      userId: 'u',
      periods: const [],
      rules: [rule(DateTime.monday, 600, 660)],
      now: DateTime.parse('2026-10-19T06:00:00Z'),
    );
    expect(result.map((a) => a.start.hour), [10, 10]);
    expect(result[0].start.toUtc(), DateTime.parse('2026-10-19T07:00:00Z'));
    expect(result[1].start.toUtc(), DateTime.parse('2026-10-26T08:00:00Z'));
  });
}
