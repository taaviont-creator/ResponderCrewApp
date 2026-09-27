import 'availability_model.dart';
import 'planned_unavailability_model.dart';
import 'planned_unavailability_rule_model.dart';

class EffectiveAvailability {
  const EffectiveAvailability._();

  static String resolve({
    required String userId,
    required String manualStatus,
    required Iterable<PlannedUnavailabilityModel> periods,
    required Iterable<PlannedUnavailabilityRuleModel> rules,
    DateTime? now,
  }) {
    if (userId.trim().isEmpty) return AvailabilityStatus.offDuty;

    final moment = now ?? DateTime.now();
    if (_hasActivePeriod(
          userId: userId,
          periods: periods,
          now: moment,
        ) ||
        _hasActiveRule(
          userId: userId,
          rules: rules,
          now: moment,
        )) {
      return AvailabilityStatus.offDuty;
    }

    return AvailabilityStatus.values.contains(manualStatus)
        ? manualStatus
        : AvailabilityStatus.offDuty;
  }

  static bool _hasActivePeriod({
    required String userId,
    required Iterable<PlannedUnavailabilityModel> periods,
    required DateTime now,
  }) {
    return periods.any((period) {
      final startAt = period.startAt;
      final endAt = period.endAt;
      if (period.userId != userId ||
          !period.isActive ||
          startAt == null ||
          endAt == null) {
        return false;
      }
      return !now.isBefore(startAt) && now.isBefore(endAt);
    });
  }

  static bool _hasActiveRule({
    required String userId,
    required Iterable<PlannedUnavailabilityRuleModel> rules,
    required DateTime now,
  }) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return rules.any((rule) {
      return rule.userId == userId &&
          rule.isActive &&
          rule.daysOfWeek.contains(now.weekday) &&
          minuteOfDay >= rule.startMinute &&
          minuteOfDay < rule.endMinute;
    });
  }
}
