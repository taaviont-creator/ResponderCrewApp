import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/membership_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
}
