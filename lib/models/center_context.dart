class CenterContext {
  const CenterContext({
    required this.centerId,
    required this.name,
    required this.service,
    this.validUntil,
  });

  final String centerId, name, service;
  final DateTime? validUntil;
  String get path => '/keskus/$service';

  static CenterContext? fromMap(Map<String, dynamic> data) {
    final service = data['service'];
    final id = data['centerId'];
    if (!((id == 'merevalvekeskus' && service == 'sar') ||
        (id == 'tross' && service == 'tross'))) {
      return null;
    }
    final expiry = data['validUntilMs'];
    if (expiry != null && (expiry is! int || expiry.abs() > 8640000000000000)) {
      return null;
    }
    return CenterContext(
      centerId: id as String,
      name: service == 'sar' ? 'Merevalvekeskus' : 'Trossi keskus',
      service: service as String,
      validUntil: expiry == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiry as int, isUtc: true),
    );
  }
}
