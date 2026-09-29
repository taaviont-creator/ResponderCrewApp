import 'dart:convert';

class InformationNotificationOpen {
  const InformationNotificationOpen(this.type, this.organizationId);
  final String type, organizationId;
  static const types = {
    'organizationReadiness',
    'personalAvailability',
    'platformApplication',
  };
  static InformationNotificationOpen? fromData(Map<String, dynamic> data) {
    final type = data['type'], org = data['organizationId'];
    if (!types.contains(type) ||
        org is! String ||
        org.isEmpty ||
        org.contains('/')) {
      return null;
    }
    return InformationNotificationOpen(type as String, org);
  }

  static InformationNotificationOpen? fromPayload(String? payload) {
    try {
      final data = jsonDecode(payload ?? '');
      return data is Map<String, dynamic> ? fromData(data) : null;
    } catch (_) {
      return null;
    }
  }
}
