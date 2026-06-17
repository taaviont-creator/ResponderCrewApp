import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/membership_model.dart';

class InviteService {
  InviteService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('organizationInvites');

  Future<void> createMemberInvite({
    required String organizationId,
    required String email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Kutse loomiseks pead olema sisse logitud.');
    }

    final normalizedOrganizationId = organizationId.trim();
    if (normalizedOrganizationId.isEmpty) {
      throw Exception('Kutse loomiseks puudub aktiivne ühing.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      throw Exception('Sisesta korrektne e-posti aadress.');
    }

    final commandSnapshot = await _firestore
        .collection('commands')
        .doc(normalizedOrganizationId)
        .get();
    final commandData = commandSnapshot.data();
    if (!commandSnapshot.exists || commandData == null) {
      throw Exception('Ühingut ei leitud.');
    }

    final commandStatus = commandData['status'];
    if (commandStatus != null && commandStatus != 'approved') {
      throw Exception('Kutseid saab saata ainult kinnitatud ühingus.');
    }

    final userSnapshot =
        await _firestore.collection('users').doc(user.uid).get();
    final isPlatformAdmin = PlatformRole.isPlatformAdmin(
      userSnapshot.data()?['systemRole'],
    );

    if (!isPlatformAdmin) {
      final membershipSnapshot = await _firestore
          .collection('memberships')
          .doc('${user.uid}_$normalizedOrganizationId')
          .get();
      final membership = membershipSnapshot.data();

      if (membership == null ||
          !_isActiveMembership(membership) ||
          !MembershipRole.isOrgAdmin(membership['role'])) {
        throw Exception('Sul puudub õigus liikmeid kutsuda.');
      }
    }

    final existingInvite = await _invites
        .where('organizationId', isEqualTo: normalizedOrganizationId)
        .where('email', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingInvite.docs.isNotEmpty) {
      throw Exception('Selle e-postiga ootel kutse on juba olemas.');
    }

    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 14)),
    );

    await _invites.add({
      'organizationId': normalizedOrganizationId,
      // TODO: Remove commandId after all reads use organizationId.
      'commandId': normalizedOrganizationId,
      'email': normalizedEmail,
      'role': MembershipRole.member,
      'status': 'pending',
      'invitedBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'acceptedBy': null,
      'acceptedAt': null,
    });
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
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
