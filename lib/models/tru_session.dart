import 'package:flutter/widgets.dart';

/// Host-owned identity and server-confirmed access. This is never an access token.
class TruSession {
  const TruSession({required this.userId, required this.displayName,
    required this.role, required this.regions, required this.revision});
  final String userId, displayName, role;
  final List<String> regions;
  final int revision;
  bool get canManage => role == 'coordinator' || role == 'admin';
}

typedef TruWorkspaceBuilder = Widget Function(
  BuildContext context, TruSession session, VoidCallback changeWorkspace);

class TruMembership {
  const TruMembership({required this.role, required this.regions,
    required this.revision, this.validUntil});
  final String role;
  final List<String> regions;
  final int revision;
  final DateTime? validUntil;
  static const regionNames = ['Ida', 'Lääne', 'Lõuna', 'Põhja'];

  static TruMembership? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final role = raw['role'], regions = raw['regions'];
    final revision = raw['revision'], expiry = raw['validUntilMs'];
    if (!['member', 'coordinator', 'admin'].contains(role) ||
        regions is! List || regions.isEmpty || regions.length > 4 ||
        regions.any((r) => !regionNames.contains(r)) ||
        regions.toSet().length != regions.length ||
        revision is! int || revision < 1 ||
        (expiry != null && (expiry is! int || expiry.abs() > 8640000000000000))) {
      return null;
    }
    return TruMembership(role: role as String,
      regions: List<String>.unmodifiable(regions.cast<String>()),
      revision: revision,
      validUntil: expiry == null ? null : DateTime.fromMillisecondsSinceEpoch(expiry as int, isUtc: true));
  }
}
