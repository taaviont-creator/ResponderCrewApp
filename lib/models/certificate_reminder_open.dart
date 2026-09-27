import 'dart:convert';

class CertificateReminderOpen {
  const CertificateReminderOpen(this.organizationId, this.memberUserId);
  final String organizationId;
  final String memberUserId;
  static CertificateReminderOpen? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'certificate_reminder') return null;
    final org = data['organizationId'];
    final member = data['memberUserId'];
    if (org is! String || org.isEmpty || member is! String || member.isEmpty) {
      return null;
    }
    return CertificateReminderOpen(org, member);
  }

  static CertificateReminderOpen? fromPayload(String? payload) {
    try {
      final data = jsonDecode(payload ?? '');
      return data is Map<String, dynamic> ? fromData(data) : null;
    } catch (_) {
      return null;
    }
  }
}
