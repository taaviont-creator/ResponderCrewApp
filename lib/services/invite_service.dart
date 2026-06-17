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

  Future<String?> ensureCurrentUserNormalizedEmail() async {
    final user = _auth.currentUser;
    final normalizedEmail = user?.email?.trim().toLowerCase();
    if (user == null || normalizedEmail == null || normalizedEmail.isEmpty) {
      return null;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'normalizedEmail': normalizedEmail,
    }, SetOptions(merge: true));

    return normalizedEmail;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamPendingInvitesForEmail(String normalizedEmail) {
    final email = normalizedEmail.trim().toLowerCase();
    if (email.isEmpty) {
      return Stream.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    return _invites
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final now = Timestamp.now();
      return snapshot.docs.where((doc) {
        final invite = doc.data();
        final expiresAt = _timestampValue(invite['expiresAt']);
        return expiresAt != null && expiresAt.compareTo(now) > 0;
      }).toList(growable: false);
    });
  }

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

  Future<void> acceptInvite(String inviteId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final normalizedEmail = await ensureCurrentUserNormalizedEmail();
    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final inviteRef = _invites.doc(inviteId);
    final inviteSnapshot = await inviteRef.get();
    final invite = inviteSnapshot.data();
    if (!inviteSnapshot.exists || invite == null) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    if (invite['status'] != 'pending' || invite['email'] != normalizedEmail) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final expiresAt = _timestampValue(invite['expiresAt']);
    if (expiresAt == null || expiresAt.compareTo(Timestamp.now()) <= 0) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final organizationId =
        (invite['organizationId'] ?? invite['commandId'] ?? '').toString();
    if (organizationId.trim().isEmpty) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final commandSnapshot =
        await _firestore.collection('commands').doc(organizationId).get();
    final commandData = commandSnapshot.data();
    if (!commandSnapshot.exists || commandData == null) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final commandStatus = commandData['status'];
    if (commandStatus != null && commandStatus != 'approved') {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final role = MembershipRole.normalize(invite['role']);
    if (role != MembershipRole.member) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final membershipRef = _firestore
        .collection('memberships')
        .doc('${user.uid}_$organizationId');
    final membershipSnapshot = await membershipRef.get();
    final membership = membershipSnapshot.data();
    if (membership != null && _isActiveMembership(membership)) {
      throw Exception('Seda kutset ei saa vastu võtta.');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final batch = _firestore.batch();

    batch.update(inviteRef, {
      'status': 'accepted',
      'acceptedBy': user.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    batch.set(membershipRef, {
      'userId': user.uid,
      'organizationId': organizationId,
      // TODO: Remove commandId after all reads use organizationId.
      'commandId': organizationId,
      'role': role,
      'seaRescueLevel': SeaRescueLevel.none,
      'status': 'active',
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'acceptedInviteId': inviteId,
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'activeOrganizationId': organizationId,
      'activeCommandId': organizationId,
      'commandId': organizationId,
      'normalizedEmail': normalizedEmail,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Timestamp? _timestampValue(Object? value) {
    return value is Timestamp ? value : null;
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
