import 'package:cloud_firestore/cloud_firestore.dart';

class MembershipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _memberships =>
      _firestore.collection('memberships');

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamActiveMembershipsForUser(String userId) {
    return _memberships
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => isActiveMembership(doc.data()))
          .toList(growable: false);
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamActiveMembershipsForOrganization(String organizationId) {
    return _memberships.snapshots().map((snapshot) {
      return snapshot.docs.where((doc) {
        final membership = doc.data();
        return isActiveMembership(membership) &&
            organizationIdFromMembership(membership) == organizationId;
      }).toList(growable: false);
    });
  }

  String? organizationIdFromMembership(Map<String, dynamic> membership) {
    final organizationId = _stringValue(membership['organizationId']);
    if (organizationId != null && organizationId.isNotEmpty) {
      return organizationId;
    }

    // TODO: Remove commandId fallback after membership migration is complete.
    final commandId = _stringValue(membership['commandId']);
    if (commandId != null && commandId.isNotEmpty) {
      return commandId;
    }

    return null;
  }

  bool isActiveMembership(Map<String, dynamic> membership) {
    return membership['status'] == 'active' || membership['isActive'] == true;
  }

  String? resolveActiveOrganizationId({
    required Map<String, dynamic> userData,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> memberships,
  }) {
    final membershipsByOrganizationId = <String, Map<String, dynamic>>{};

    for (final membershipDoc in memberships) {
      final membership = membershipDoc.data();
      if (!isActiveMembership(membership)) continue;

      final organizationId = organizationIdFromMembership(membership);
      if (organizationId != null) {
        membershipsByOrganizationId[organizationId] = membership;
      }
    }

    if (membershipsByOrganizationId.isEmpty) return null;

    final activeOrganizationId = _stringValue(userData['activeOrganizationId']);
    if (_hasMembership(activeOrganizationId, membershipsByOrganizationId)) {
      return activeOrganizationId;
    }

    // TODO: Remove activeCommandId/commandId fallbacks after HomeScreen is
    // fully migrated to activeOrganizationId.
    final activeCommandId = _stringValue(userData['activeCommandId']);
    if (_hasMembership(activeCommandId, membershipsByOrganizationId)) {
      return activeCommandId;
    }

    final commandId = _stringValue(userData['commandId']);
    if (_hasMembership(commandId, membershipsByOrganizationId)) {
      return commandId;
    }

    return membershipsByOrganizationId.keys.first;
  }

  Map<String, dynamic>? membershipForOrganizationId({
    required String organizationId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> memberships,
  }) {
    for (final membershipDoc in memberships) {
      final membership = membershipDoc.data();
      if (organizationIdFromMembership(membership) == organizationId) {
        return membership;
      }
    }

    return null;
  }

  bool _hasMembership(
    String? organizationId,
    Map<String, Map<String, dynamic>> membershipsByOrganizationId,
  ) {
    return organizationId != null &&
        organizationId.isNotEmpty &&
        membershipsByOrganizationId.containsKey(organizationId);
  }

  String? _stringValue(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}
