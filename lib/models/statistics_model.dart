class StatisticsSummary {
  const StatisticsSummary({
    required this.memberCount,
    required this.onDutyCount,
    required this.delayedCount,
    required this.offDutyCount,
    required this.equipmentCount,
    required this.equipmentNeedsMaintenanceCount,
    required this.equipmentUnavailableCount,
    required this.operationLogCount,
    required this.upcomingActivityCount,
    required this.validCertificateCount,
    required this.expiredCertificateCount,
    this.confirmedParticipationCount,
    this.confirmedParticipationHours,
    this.memberContributions,
  });

  final int memberCount;
  final int onDutyCount;
  final int delayedCount;
  final int offDutyCount;
  final int equipmentCount;
  final int equipmentNeedsMaintenanceCount;
  final int equipmentUnavailableCount;
  final int operationLogCount;
  final int upcomingActivityCount;
  final int validCertificateCount;
  final int expiredCertificateCount;
  final int? confirmedParticipationCount;
  final double? confirmedParticipationHours;
  final List<MemberContributionSummary>? memberContributions;

  bool get hasConfirmedParticipationStatistics =>
      confirmedParticipationCount != null &&
      confirmedParticipationHours != null;

  bool get hasMemberContributionStatistics => memberContributions != null;
}

class MemberContributionSummary {
  const MemberContributionSummary({
    required this.userId,
    required this.displayName,
    required this.confirmedParticipationCount,
    required this.confirmedParticipationHours,
  });

  final String userId;
  final String displayName;
  final int confirmedParticipationCount;
  final double confirmedParticipationHours;
}
