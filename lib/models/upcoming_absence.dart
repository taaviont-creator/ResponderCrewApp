import 'planned_unavailability_model.dart';
import 'planned_unavailability_rule_model.dart';

class UpcomingAbsence {
  const UpcomingAbsence(this.start, this.end, {this.recurring = false});
  final DateTime start, end;
  final bool recurring;
}

List<UpcomingAbsence> upcomingAbsences({
  required String userId,
  required Iterable<PlannedUnavailabilityModel> periods,
  required Iterable<PlannedUnavailabilityRuleModel> rules,
  required DateTime now,
}) {
  final result = <UpcomingAbsence>[];
  for (final period in periods) {
    final start = period.startAt;
    final end = period.endAt;
    if (period.userId == userId &&
        period.isActive &&
        start != null &&
        end != null &&
        start.isAfter(now) &&
        end.isAfter(start)) {
      result.add(UpcomingAbsence(start, end));
    }
  }
  for (final rule in rules) {
    if (rule.userId != userId ||
        !rule.isActive ||
        rule.startMinute < 0 ||
        rule.endMinute > 1440 ||
        rule.endMinute <= rule.startMinute) {
      continue;
    }
    // Two weeks contain at least two occurrences of any weekly schedule.
    for (var offset = 0; offset <= 14; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (!rule.daysOfWeek.contains(day.weekday)) continue;
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        rule.startMinute ~/ 60,
        rule.startMinute % 60,
      );
      final end = DateTime(
        day.year,
        day.month,
        day.day,
        rule.endMinute ~/ 60,
        rule.endMinute % 60,
      );
      if (start.isAfter(now)) {
        result.add(UpcomingAbsence(start, end, recurring: true));
      }
    }
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  final unique = <UpcomingAbsence>[];
  for (final item in result) {
    if (unique.any(
      (other) => other.start == item.start && other.end == item.end,
    )) {
      continue;
    }
    unique.add(item);
    if (unique.length == 2) break;
  }
  return unique;
}
