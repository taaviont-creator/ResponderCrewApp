class NotificationPreferences {
  static const labels = {
    'newCallout': 'Uus väljakutse',
    'readinessLost': 'SAR-valmidus kadus',
    'readinessRestored': 'SAR-valmidus taastus',
    'belowMinimum': 'Meeskond langes alla miinimumi',
    'missingLevel2': 'II astme merepäästja puudub',
    'memberOffDuty': 'Liige lahkus valvest',
    'ownAbsenceStarted': 'Minu planeeritud mittevalve algas',
    'ownAbsenceEnded': 'Minu planeeritud mittevalve lõppes',
    'certificates': 'Tunnistuste aegumine',
  };
  static Map<String, bool> resolve({
    required bool admin,
    Map<String, dynamic> stored = const {},
  }) {
    final defaults = {
      'newCallout': true,
      'readinessLost': admin,
      'readinessRestored': admin,
      'belowMinimum': admin,
      'missingLevel2': admin,
      'memberOffDuty': false,
      'ownAbsenceStarted': true,
      'ownAbsenceEnded': true,
      'certificates': true,
    };
    return {
      for (final key in labels.keys)
        key: stored[key] is bool ? stored[key] as bool : defaults[key]!,
    };
  }
}
