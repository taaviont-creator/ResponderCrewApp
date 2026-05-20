import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/equipment_model.dart';

class EquipmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _equipment =>
      _firestore.collection('equipment');

  Stream<List<EquipmentModel>> streamOrganizationEquipment({
    required String organizationId,
  }) {
    return _equipment
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after equipment migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      final equipment =
          snapshot.docs.map(EquipmentModel.fromFirestore).toList();

      equipment.sort((a, b) => a.name.compareTo(b.name));
      return equipment;
    });
  }

  Future<void> addEquipment({
    required String organizationId,
    required String name,
    required String category,
    required String status,
    required String location,
    required String note,
    required String createdBy,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Equipment name is required');
    }

    if (!EquipmentCategory.values.contains(category)) {
      throw Exception('Unsupported equipment category: $category');
    }

    if (!EquipmentStatus.values.contains(status)) {
      throw Exception('Unsupported equipment status: $status');
    }

    final doc = _equipment.doc();

    await doc.set({
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all equipment reads use organizationId.
      'commandId': organizationId,
      'name': name.trim(),
      'category': category,
      'status': status,
      'location': location.trim(),
      'note': note.trim(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
