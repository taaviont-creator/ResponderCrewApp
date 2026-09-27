import 'dart:convert';

class MemberRequestNotification {
  const MemberRequestNotification(this.organizationId);
  final String organizationId;

  static MemberRequestNotification? fromData(Map<String, dynamic> data) {
    final org = data['organizationId'];
    if (data['type'] != 'member_request' ||
        org is! String ||
        org.trim().isEmpty ||
        org.contains('/')) {
      return null;
    }
    return MemberRequestNotification(org.trim());
  }

  String toPayload() =>
      jsonEncode({'type': 'member_request', 'organizationId': organizationId});

  static MemberRequestNotification? fromPayload(String? payload) {
    try {
      final data = jsonDecode(payload ?? '');
      return data is Map<String, dynamic> ? fromData(data) : null;
    } catch (_) {
      return null;
    }
  }
}
