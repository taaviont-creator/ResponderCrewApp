import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/membership_model.dart';

class CommandService {
  static const _statusPending = 'pending';
  static const _statusRejected = 'rejected';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateJoinCode({int length = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _membershipId(String userId, String commandId) => '${userId}_$commandId';

  Future<String> _generateUniqueJoinCode({int length = 6}) async {
    for (int i = 0; i < 20; i++) {
      final code = _generateJoinCode(length: length);

      final existing = await _db
          .collection('commands')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return code;
      }
    }

    throw Exception('Unikaalse liitumiskoodi genereerimine ebaõnnestus');
  }

  Future<String> createCommand({required String name}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Command name is empty');
    }

    final joinCode = await _generateUniqueJoinCode();

    final commandRef = _db.collection('commands').doc();
    final membershipRef = _db
        .collection('memberships')
        .doc(_membershipId(user.uid, commandRef.id));
    final batch = _db.batch();

    batch.set(commandRef, {
      'name': trimmedName,
      'joinCode': joinCode,
      'createdBy': user.uid,
      'status': _statusPending,
      'allowMembersToCreateActivities': false,
      'allowMembersToViewStatistics': false,
      'allowMembersToStartOperationLog': false,
      'createdAt': FieldValue.serverTimestamp(),
      'isOnDuty': false,
    });

    batch.set(membershipRef, {
      'userId': user.uid,
      'organizationId': commandRef.id,
      'commandId': commandRef.id,
      'role': MembershipRole.orgAdmin,
      'seaRescueLevel': SeaRescueLevel.none,
      'status': 'pending',
      'isActive': false,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return commandRef.id;
  }

  Future<String> joinCommand({required String joinCode}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty) throw Exception('Join code is empty');

    final query = await _db
        .collection('commands')
        .where('joinCode', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Komandot selle koodiga ei leitud');
    }

    final commandDoc = query.docs.first;
    final commandId = commandDoc.id;
    final status = commandDoc.data()['status'];
    if (status == _statusPending) {
      throw Exception('Ühing ootab kinnitamist.');
    }
    if (status == _statusRejected) {
      throw Exception('Ühingu taotlus on tagasi lükatud.');
    }

    final membershipRef = _db
        .collection('memberships')
        .doc(_membershipId(user.uid, commandId));
    final userRef = _db.collection('users').doc(user.uid);

    final batch = _db.batch();

    batch.set(membershipRef, {
      'userId': user.uid,
      'organizationId': commandId,
      'commandId': commandId,
      'role': MembershipRole.member,
      'seaRescueLevel': SeaRescueLevel.none,
      'status': 'active',
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'activeOrganizationId': commandId,
      'activeCommandId': commandId,
      'commandId': commandId,
    }, SetOptions(merge: true));

    await batch.commit();

    return commandId;
  }

  Future<void> updateMemberPermissions({
    required String organizationId,
    required bool allowMembersToCreateActivities,
    required bool allowMembersToViewStatistics,
    required bool allowMembersToStartOperationLog,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }

    final userSnapshot = await _db.collection('users').doc(user.uid).get();
    final isPlatformAdmin = PlatformRole.isPlatformAdmin(
      userSnapshot.data()?['systemRole'],
    );

    final membershipSnapshot = await _db
        .collection('memberships')
        .doc(_membershipId(user.uid, organizationId))
        .get();
    final membership = membershipSnapshot.data();
    final membershipIsActive = membership != null &&
        ((membership['status'] == 'active') ||
            (membership['isActive'] == true)) &&
        (!membership.containsKey('status') ||
            membership['status'] == 'active') &&
        (!membership.containsKey('isActive') ||
            membership['isActive'] == true);
    if (!isPlatformAdmin &&
        (membership == null ||
            !MembershipRole.isOrgAdmin(membership['role']) ||
            !membershipIsActive)) {
      throw Exception('Sul puudub õigus neid seadeid muuta');
    }

    if (!isPlatformAdmin) {
      final membershipOrganizationId =
          (membership!['organizationId'] ?? membership['commandId'] ?? '')
              .toString();
      if (membershipOrganizationId != organizationId) {
        throw Exception('Membership belongs to another organization');
      }
    }

    await _db.collection('commands').doc(organizationId).update({
      'allowMembersToCreateActivities': allowMembersToCreateActivities,
      'allowMembersToViewStatistics': allowMembersToViewStatistics,
      'allowMembersToStartOperationLog': allowMembersToStartOperationLog,
      'updatedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveCommand({required String commandId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (commandId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }

    final uid = user.uid;
    final membershipRef = _db.collection('memberships').doc(_membershipId(uid, commandId));
    final userRef = _db.collection('users').doc(uid);

    final membershipSnap = await membershipRef.get();
    if (!membershipSnap.exists) {
      throw Exception('Membershipit ei leitud');
    }

    final membershipData = membershipSnap.data()!;
    final membershipOrganizationId =
        (membershipData['organizationId'] ?? membershipData['commandId'] ?? '')
            .toString();
    if (membershipOrganizationId != commandId) {
      throw Exception('Membership belongs to another organization');
    }
    final isActive = membershipData['isActive'] == true;
    final myRole = MembershipRole.normalize(membershipData['role']);

    if (!isActive) {
      throw Exception('Sa ei ole selles organisatsioonis aktiivne liige');
    }

    // Organisatsioonist peab lahkumise järel alles jääma vähemalt üks orgAdmin.
    if (myRole == MembershipRole.orgAdmin) {
      final activeMembershipsQuery = await _db
          .collection('memberships')
          .where('commandId', isEqualTo: commandId)
          .where('isActive', isEqualTo: true)
          .get();

      final otherActiveAdmins = activeMembershipsQuery.docs.where((doc) {
        final data = doc.data();
        return doc.id != membershipRef.id &&
            MembershipRole.isOrgAdmin(data['role']);
      }).length;

      if (otherActiveAdmins == 0) {
        throw Exception(
          'Sa oled selle organisatsiooni viimane administraator. '
          'Määra enne kellelegi teisele orgAdmin roll.',
        );
      }
    }

    final userSnap = await userRef.get();
    final userData = userSnap.data();
    final activeCommandId =
        userData?['activeOrganizationId'] as String? ??
        userData?['activeCommandId'] as String?;

    final myOtherMembershipsQuery = await _db
        .collection('memberships')
        .where('userId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .get();

    String? nextActiveCommandId;
    for (final doc in myOtherMembershipsQuery.docs) {
      final data = doc.data();
      final otherCommandId =
          data['organizationId'] as String? ?? data['commandId'] as String?;
      if (otherCommandId != null && otherCommandId.isNotEmpty && otherCommandId != commandId) {
        nextActiveCommandId = otherCommandId;
        break;
      }
    }

    final batch = _db.batch();

    batch.set(membershipRef, {
      'status': 'removed',
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (activeCommandId == commandId) {
      if (nextActiveCommandId != null) {
        batch.set(userRef, {
          'activeOrganizationId': nextActiveCommandId,
          'activeCommandId': nextActiveCommandId,
          'commandId': nextActiveCommandId,
        }, SetOptions(merge: true));
      } else {
        batch.update(userRef, {
          'activeOrganizationId': FieldValue.delete(),
          'activeCommandId': FieldValue.delete(),
          'commandId': FieldValue.delete(),
        });
      }
    }

    await batch.commit();
  }
}
