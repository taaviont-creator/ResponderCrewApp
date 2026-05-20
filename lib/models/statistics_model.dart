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
}
