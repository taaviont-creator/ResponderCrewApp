enum CenterReadinessStatus {
  ready,
  delayed,
  unavailable,
  unknown;

  String get label => switch (this) {
    ready => 'Reageerimisvalmis',
    delayed => 'Reageerib viivitusega',
    unavailable => 'Ei saa reageerida',
    unknown => 'Valmidus teadmata',
  };
  static CenterReadinessStatus parse(Object? v) =>
      values.where((s) => s.name == v).firstOrNull ?? unknown;
}

class CenterBoardItem {
  CenterBoardItem.fromMap(Map<String, dynamic> data)
    : automatic = data['automatic'] == true,
      id = data['id'] is String ? data['id'] as String : '',
      name = data['name'] is String ? data['name'] as String : 'Ühing',
      restrictionReason = data['restrictionReason'] is String
          ? data['restrictionReason'] as String
          : '',
      status = CenterReadinessStatus.parse(data['status']),
      latitude = _coordinate(data['latitude'], 90),
      longitude = _coordinate(data['longitude'], 180),
      reasons = _list(data['reasons']).whereType<String>().toList(),
      contactName = data['contactName'] is String
          ? data['contactName'] as String
          : '',
      contactPhone = data['contactPhone'] is String
          ? data['contactPhone'] as String
          : '',
      onDutyCount = _int(data['onDutyCount']),
      minimum = _int(data['minimum']),
      secondLevelCount = _int(data['secondLevelCount']),
      departureMinutes = _int(data['departureMinutes']),
      computedAt = _time(data['computedAtMs']),
      confirmedAt = _time(data['confirmedAtMs']),
      freshUntil = _time(data['freshUntilMs']),
      expectedReadyAt = _time(data['expectedReadyAtMs']),
      vessels = _list(
        data['vessels'],
      ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  final String id, name, contactName, contactPhone, restrictionReason;
  final CenterReadinessStatus status;
  final bool automatic;
  final double? latitude, longitude;
  final List<String> reasons;
  final List<Map<String, dynamic>> vessels;
  final int? onDutyCount, minimum, secondLevelCount, departureMinutes;
  final DateTime? computedAt, confirmedAt, freshUntil, expectedReadyAt;
  bool get hasPosition => latitude != null && longitude != null;
  CenterReadinessStatus effectiveStatus(
    DateTime now, {
    required bool connected,
  }) => !connected || freshUntil == null || !freshUntil!.isAfter(now)
      ? CenterReadinessStatus.unknown
      : status;
  static List<dynamic> _list(Object? value) => value is List ? value : const [];
  static double? _coordinate(Object? v, int max) =>
      v is num && v.isFinite && v.abs() <= max ? v.toDouble() : null;
  static int? _int(Object? v) =>
      v is num && v.isFinite && v >= 0 && v == v.roundToDouble()
      ? v.toInt()
      : null;
  static DateTime? _time(Object? v) => v is int && v.abs() <= 8640000000000000
      ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)
      : null;
}
