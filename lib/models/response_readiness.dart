class ResponseReadiness {
  const ResponseReadiness._({
    required this.minimumCrewRequired,
    required this.onDutyCount,
    required this.secondLevelOnDutyCount,
  });

  factory ResponseReadiness.evaluate({
    required int minimumCrewRequired,
    required int onDutyCount,
    required int secondLevelOnDutyCount,
  }) {
    return ResponseReadiness._(
      minimumCrewRequired:
          minimumCrewRequired < 0 ? 0 : minimumCrewRequired,
      onDutyCount: onDutyCount < 0 ? 0 : onDutyCount,
      secondLevelOnDutyCount:
          secondLevelOnDutyCount < 0 ? 0 : secondLevelOnDutyCount,
    );
  }

  final int minimumCrewRequired;
  final int onDutyCount;
  final int secondLevelOnDutyCount;

  bool get isConfigured => minimumCrewRequired > 0;
  bool get minimumCrewMet =>
      isConfigured && onDutyCount >= minimumCrewRequired;
  bool get secondLevelMet => secondLevelOnDutyCount >= 1;
  bool get isReady => minimumCrewMet && secondLevelMet;

  List<String> get missingRequirements {
    if (!isConfigured) {
      return const ['Miinimumkoosseis ei ole seadistatud'];
    }

    return [
      if (!minimumCrewMet) 'Miinimumkoosseis puudu',
      if (!secondLevelMet) 'II astme merepäästja puudub',
    ];
  }
}
