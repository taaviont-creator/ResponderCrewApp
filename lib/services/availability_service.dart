import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/availability_model.dart';

class AvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _availability =>
      _firestore.collection('availability');

  String availabilityId({
    required String userId,
    required String organizationId,
  }) {
    return '${userId}_$organizationId';
  }

  Stream<AvailabilityModel?> streamMyAvailability({
    required String userId,
    required String organizationId,
  }) {
    return _availability
        .doc(availabilityId(userId: userId, organizationId: organizationId))
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return AvailabilityModel.fromFirestore(snapshot);
    });
  }

  Stream<List<AvailabilityModel>> streamOrganizationAvailability({
    required String organizationId,
  }) {
    return _availability
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after availability migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(AvailabilityModel.fromFirestore)
          .toList(growable: false);
    });
  }

  Future<void> setMyAvailability({
    required String userId,
    required String organizationId,
    required String status,
    int? responseMinutes,
    String? note,
  }) async {
    if (!AvailabilityStatus.values.contains(status)) {
      throw Exception('Unsupported availability status: $status');
    }

    final id = availabilityId(
      userId: userId,
      organizationId: organizationId,
    );

    await _availability.doc(id).set({
      'id': id,
      'userId': userId,
      'organizationId': organizationId,
      // TODO: Remove commandId after all availability reads use organizationId.
      'commandId': organizationId,
      'status': status,
      'responseMinutes':
          status == AvailabilityStatus.delayed ? responseMinutes : null,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
