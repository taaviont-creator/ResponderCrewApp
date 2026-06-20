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
  }
}
