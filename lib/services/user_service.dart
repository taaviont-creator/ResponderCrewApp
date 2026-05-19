import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String name,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'name': name,
      'status': 'available', // vaba
      'activeOrganizationId': null,
      // TODO: Migrate commandId/role to organization-specific memberships.
      'commandId': null,     // komando pole veel
      'role': 'member',      // hiljem admin/member
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
