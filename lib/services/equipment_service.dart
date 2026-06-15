import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/equipment_model.dart';
import '../models/notification_model.dart';

class EquipmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _equipment =>
      _firestore.collection('equipment');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

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
    final batch = _firestore.batch();
    final equipmentData = {
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
    };

    batch.set(doc, equipmentData);
    _addProblemStatusNotificationToBatch(
      batch: batch,
      organizationId: organizationId,
      equipmentId: doc.id,
      equipmentName: name.trim(),
      status: status,
      createdBy: createdBy,
    );

    await batch.commit();
  }

  Future<void> updateEquipment({
    required String equipmentId,
    required String name,
    required String category,
    required String status,
    required String location,
    required String note,
    required String updatedBy,
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

    final doc = _equipment.doc(equipmentId);
    final snapshot = await doc.get();
    final existing = snapshot.data();
    if (existing == null) {
      throw Exception('Equipment item not found');
    }

    final organizationId =
        (existing['organizationId'] ?? existing['commandId'] ?? '').toString();
    final createdBy = (existing['createdBy'] ?? '').toString();
    final previousStatus = (existing['status'] ?? EquipmentStatus.ok).toString();

    final batch = _firestore.batch();

    batch.set(doc, {
      'id': equipmentId,
      'organizationId': organizationId,
      // TODO: Remove commandId after all equipment reads use organizationId.
      'commandId': organizationId,
      'name': name.trim(),
      'category': category,
      'status': status,
      'location': location.trim(),
      'note': note.trim(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (previousStatus != status) {
      _addProblemStatusNotificationToBatch(
        batch: batch,
        organizationId: organizationId,
        equipmentId: equipmentId,
        equipmentName: name.trim(),
        status: status,
        createdBy: updatedBy,
      );
    }

    await batch.commit();
  }

  void _addProblemStatusNotificationToBatch({
    required WriteBatch batch,
    required String organizationId,
    required String equipmentId,
    required String equipmentName,
    required String status,
    required String createdBy,
  }) {
    final priority = _notificationPriorityForStatus(status);
    if (priority == null) return;

    final notificationDoc = _notifications.doc();
    batch.set(notificationDoc, {
      'id': notificationDoc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all notification reads use organizationId.
      'commandId': organizationId,
      'title': 'Varustus: $equipmentName',
      'message': '$equipmentName status: ${_equipmentStatusLabel(status)}',
      'type': NotificationType.equipment,
      'priority': priority,
      'relatedType': 'equipment',
      'relatedId': equipmentId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String? _notificationPriorityForStatus(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return NotificationPriority.normal;
      case EquipmentStatus.broken:
        return NotificationPriority.high;
      case EquipmentStatus.outOfService:
        return NotificationPriority.high;
      default:
        return null;
    }
  }

  String _equipmentStatusLabel(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return 'needs maintenance';
      case EquipmentStatus.broken:
        return 'broken';
      case EquipmentStatus.outOfService:
        return 'out of service';
      default:
        return 'ok';
    }
  }
}
