import 'availability_model.dart';
import 'effective_availability.dart';
import 'membership_model.dart';
import 'planned_unavailability_model.dart';
import 'planned_unavailability_rule_model.dart';

class DutyCrewMember {
  const DutyCrewMember({
    required this.userId,
    required this.name,
    required this.status,
    required this.level,
    this.arrivalMinutes,
  });
  final String userId, name, status, level;
  final int? arrivalMinutes;
}

List<DutyCrewMember> dutyCrew({
  required Iterable<Map<String, dynamic>> memberships,
  required Iterable<AvailabilityModel> availability,
  required Iterable<PlannedUnavailabilityModel> periods,
  required Iterable<PlannedUnavailabilityRuleModel> rules,
  required DateTime now,
  Set<String> unavailableUserIds = const {},
  bool includeOffDuty = false,
}) {
  final byUser = {for (final a in availability) a.userId: a};
  final result = <DutyCrewMember>[];
  for (final member in memberships) {
    final uid = member['userId'];
    if (uid is! String ||
        uid.isEmpty ||
        !(member['status'] == 'active' || member['isActive'] == true) ||
        (member.containsKey('status') && member['status'] != 'active') ||
        (member.containsKey('isActive') && member['isActive'] != true)) {
      continue;
    }
    final a = byUser[uid];
    final status = unavailableUserIds.contains(uid)
        ? AvailabilityStatus.offDuty
        : EffectiveAvailability.resolve(
            userId: uid,
            manualStatus: a?.status ?? AvailabilityStatus.offDuty,
            periods: periods,
            rules: rules,
            now: now,
          );
    if (!includeOffDuty && status == AvailabilityStatus.offDuty) continue;
    final name = member['displayName'];
    result.add(
      DutyCrewMember(
        userId: uid,
        name: name is String && name.trim().isNotEmpty ? name.trim() : 'Liige',
        status: status,
        level: SeaRescueLevel.normalize(member['seaRescueLevel']),
        arrivalMinutes: a?.responseMinutes,
      ),
    );
  }
  result.sort((a, b) {
    final group = (a.status == AvailabilityStatus.onDuty ? 0 : 1).compareTo(
      b.status == AvailabilityStatus.onDuty ? 0 : 1,
    );
    return group != 0
        ? group
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return result;
}
