import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/membership_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String name,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'normalizedEmail': normalizedEmail,
      'name': name,
      'status': 'available', // vaba
      'activeOrganizationId': null,
      'systemRole': PlatformRole.user,
      // TODO: Remove commandId after activeOrganizationId migration.
      'commandId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateOwnBasicProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid != uid) {
      throw StateError('Only the current user can update their profile.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Name is required.');
    }

    final trimmedPhone = phone.trim();
    final data = <String, dynamic>{
      'name': trimmedName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (trimmedPhone.isEmpty) {
      data['phone'] = FieldValue.delete();
    } else {
      data['phone'] = trimmedPhone;
    }

    await _firestore.collection('users').doc(uid).set(
          data,
          SetOptions(merge: true),
        );
    await _syncOwnActiveMembershipDisplayNames(
      uid: uid,
      displayName: trimmedName,
    );
  }

  Future<void> _syncOwnActiveMembershipDisplayNames({
    required String uid,
    required String displayName,
  }) async {
    final safeDisplayName = _safeDisplayName(displayName);
    if (safeDisplayName == null) return;

    final snapshot = await _firestore
        .collection('memberships')
        .where('userId', isEqualTo: uid)
        .get();
    final batch = _firestore.batch();
    var hasWrites = false;

    for (final doc in snapshot.docs) {
      final membership = doc.data();
      if (!_isActiveMembership(membership)) continue;
      final organizationId = _organizationIdFromMembership(membership);
      if (organizationId == null || doc.id != '${uid}_$organizationId') {
        continue;
      }

      batch.set(doc.reference, {
        'displayName': safeDisplayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  String? _safeDisplayName(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains('@')) return null;
    if (trimmed.length <= 80) return trimmed;
    return trimmed.substring(0, 80).trim();
  }

  String? _organizationIdFromMembership(Map<String, dynamic> membership) {
    final organizationId = membership['organizationId'];
    if (organizationId is String && organizationId.trim().isNotEmpty) {
      return organizationId.trim();
    }

    final commandId = membership['commandId'];
    if (commandId is String && commandId.trim().isNotEmpty) {
      return commandId.trim();
    }

    return null;
  }

  bool _isActiveMembership(Map<String, dynamic> membership) {
    final hasActiveMarker =
        membership['status'] == 'active' || membership['isActive'] == true;
    final statusIsActive =
        !membership.containsKey('status') || membership['status'] == 'active';
    final flagIsActive =
        !membership.containsKey('isActive') || membership['isActive'] == true;
    return hasActiveMarker && statusIsActive && flagIsActive;
  }
}
