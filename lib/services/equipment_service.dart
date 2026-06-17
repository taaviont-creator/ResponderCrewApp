import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/equipment_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class EquipmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> get _equipment =>
      _firestore.collection('equipment');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<List<EquipmentModel>> streamOrganizationEquipment({
    required String organizationId,
  }) {
    return _streamOrganizationEquipment(organizationId: organizationId)
        .map(_sortEquipment);
  }

  Stream<List<EquipmentModel>> streamVisibleEquipment({
    required String organizationId,
    required String currentUserId,
    required bool canViewMemberPersonalEquipment,
  }) {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedUserId = currentUserId.trim();

    _requireOrganizationId(trimmedOrganizationId);
    if (trimmedUserId.isEmpty) {
      throw Exception('Kasutaja puudub.');
    }

    late StreamController<List<EquipmentModel>> controller;
    StreamSubscription<List<EquipmentModel>>? organizationSubscription;
    StreamSubscription<List<EquipmentModel>>? personalSubscription;
    List<EquipmentModel>? organizationEquipment;
    List<EquipmentModel>? personalEquipment;

    void emitEquipment() {
      if (controller.isClosed ||
          organizationEquipment == null ||
          personalEquipment == null) {
        return;
      }

      controller.add(
        _sortEquipment([
          ...organizationEquipment!,
          ...personalEquipment!,
        ]),
      );
    }

    controller = StreamController<List<EquipmentModel>>(
      onListen: () {
        organizationSubscription = _streamOrganizationEquipment(
          organizationId: trimmedOrganizationId,
        ).listen(
          (value) {
            organizationEquipment = value;
            emitEquipment();
          },
          onError: controller.addError,
        );

        final personalStream = canViewMemberPersonalEquipment
            ? _streamPersonalEquipmentForOrganization(
                organizationId: trimmedOrganizationId,
              )
            : _streamPersonalEquipment(
                organizationId: trimmedOrganizationId,
                ownerUserId: trimmedUserId,
              );

        personalSubscription = personalStream.listen(
          (value) {
            personalEquipment = value;
            emitEquipment();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await organizationSubscription?.cancel();
        await personalSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<EquipmentModel>> _streamOrganizationEquipment({
    required String organizationId,
  }) {
    final trimmedOrganizationId = organizationId.trim();
    _requireOrganizationId(trimmedOrganizationId);
    return _equipment
        .where(
          Filter.and(
            Filter.or(
              Filter('organizationId', isEqualTo: trimmedOrganizationId),
              // TODO: Remove commandId fallback after equipment migration.
              Filter('commandId', isEqualTo: trimmedOrganizationId),
            ),
            Filter('scope', isEqualTo: EquipmentScope.organization),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(EquipmentModel.fromFirestore).where((item) {
        final itemOrganizationId = item.organizationId.isNotEmpty
            ? item.organizationId
            : item.commandId;
        return itemOrganizationId == trimmedOrganizationId &&
            item.scope == EquipmentScope.organization;
      }).toList(growable: false);
    });
  }

  Stream<List<EquipmentModel>> _streamPersonalEquipment({
    required String organizationId,
    required String ownerUserId,
  }) {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedOwnerUserId = ownerUserId.trim();
    _requireOrganizationId(trimmedOrganizationId);
    return _equipment
        .where(
          Filter.and(
            Filter.or(
              Filter('organizationId', isEqualTo: trimmedOrganizationId),
              // TODO: Remove commandId fallback after equipment migration.
              Filter('commandId', isEqualTo: trimmedOrganizationId),
            ),
            Filter('scope', isEqualTo: EquipmentScope.personal),
            Filter('ownerUserId', isEqualTo: trimmedOwnerUserId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(EquipmentModel.fromFirestore).where((item) {
        final itemOrganizationId = item.organizationId.isNotEmpty
            ? item.organizationId
            : item.commandId;
        return itemOrganizationId == trimmedOrganizationId &&
            item.scope == EquipmentScope.personal &&
            item.ownerUserId == trimmedOwnerUserId;
      }).toList(growable: false);
    });
  }

  Stream<List<EquipmentModel>> _streamPersonalEquipmentForOrganization({
    required String organizationId,
  }) {
    final trimmedOrganizationId = organizationId.trim();
    _requireOrganizationId(trimmedOrganizationId);
    return _equipment
        .where(
          Filter.and(
            Filter.or(
              Filter('organizationId', isEqualTo: trimmedOrganizationId),
              // TODO: Remove commandId fallback after equipment migration.
              Filter('commandId', isEqualTo: trimmedOrganizationId),
            ),
            Filter('scope', isEqualTo: EquipmentScope.personal),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(EquipmentModel.fromFirestore).where((item) {
        final itemOrganizationId = item.organizationId.isNotEmpty
            ? item.organizationId
            : item.commandId;
        return itemOrganizationId == trimmedOrganizationId &&
            item.scope == EquipmentScope.personal;
      }).toList(growable: false);
    });
  }

  List<EquipmentModel> _sortEquipment(List<EquipmentModel> equipment) {
    final sorted = [...equipment];
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  Future<void> addEquipment({
    required String organizationId,
    required String scope,
    required String ownerUserId,
    required String name,
    required String category,
    required String status,
    required String location,
    required String nextMaintenanceDate,
    required String note,
    required String createdBy,
    required bool canManageOrganizationEquipment,
  }) async {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedOwnerUserId = ownerUserId.trim();
    final trimmedName = name.trim();
    final trimmedCategory = category.trim();
    final trimmedStatus = status.trim();
    final trimmedCreatedBy = createdBy.trim();

    _requireOrganizationId(trimmedOrganizationId);
    _validateEquipmentOwnership(
      scope: scope,
      ownerUserId: trimmedOwnerUserId,
      currentUserId: trimmedCreatedBy,
      canManageOrganizationEquipment: canManageOrganizationEquipment,
      allowAdminPersonalEquipment: false,
    );
    if (trimmedName.isEmpty) {
      throw Exception('Varustuse nimi on kohustuslik.');
    }

    if (!EquipmentCategory.values.contains(trimmedCategory)) {
      throw Exception('Varustuse kategooria ei ole toetatud.');
    }

    if (!EquipmentStatus.values.contains(trimmedStatus)) {
      throw Exception('Varustuse staatus ei ole toetatud.');
    }

    final doc = _equipment.doc();
    final batch = _firestore.batch();
    final equipmentData = {
      'id': doc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all equipment reads use organizationId.
      'commandId': trimmedOrganizationId,
      'scope': scope,
      if (scope == EquipmentScope.personal) 'ownerUserId': trimmedOwnerUserId,
      'name': trimmedName,
      'category': trimmedCategory,
      'status': trimmedStatus,
      'location': location.trim(),
      'nextMaintenanceDate': nextMaintenanceDate.trim(),
      'note': note.trim(),
      'createdBy': trimmedCreatedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.set(doc, equipmentData);
    if (scope == EquipmentScope.organization) {
      _addProblemStatusNotificationToBatch(
        batch: batch,
        organizationId: trimmedOrganizationId,
        equipmentId: doc.id,
        equipmentName: trimmedName,
        status: trimmedStatus,
        createdBy: trimmedCreatedBy,
      );
    }

    await batch.commit();
  }

  Future<void> updateEquipment({
    required String equipmentId,
    required String organizationId,
    required String name,
    required String category,
    required String status,
    required String location,
    required String nextMaintenanceDate,
    required String note,
    required String updatedBy,
    required bool canManageOrganizationEquipment,
  }) async {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedEquipmentId = equipmentId.trim();
    final trimmedName = name.trim();
    final trimmedCategory = category.trim();
    final trimmedStatus = status.trim();
    final trimmedUpdatedBy = updatedBy.trim();

    _requireOrganizationId(trimmedOrganizationId);
    if (trimmedName.isEmpty) {
      throw Exception('Varustuse nimi on kohustuslik.');
    }

    if (!EquipmentCategory.values.contains(trimmedCategory)) {
      throw Exception('Varustuse kategooria ei ole toetatud.');
    }

    if (!EquipmentStatus.values.contains(trimmedStatus)) {
      throw Exception('Varustuse staatus ei ole toetatud.');
    }

    final doc = _equipment.doc(trimmedEquipmentId);
    final snapshot = await doc.get();
    final existing = snapshot.data();
    if (existing == null) {
      throw Exception('Varustust ei leitud.');
    }

    final existingOrganizationId =
        (existing['organizationId'] ?? existing['commandId'] ?? '')
            .toString()
            .trim();
    if (existingOrganizationId != trimmedOrganizationId) {
      throw Exception('Varustus kuulub teise ühingusse.');
    }
    final scope = _equipmentScope(existing);
    final ownerUserId = (existing['ownerUserId'] ?? '').toString();
    _validateEquipmentOwnership(
      scope: scope,
      ownerUserId: ownerUserId,
      currentUserId: trimmedUpdatedBy,
      canManageOrganizationEquipment: canManageOrganizationEquipment,
      allowAdminPersonalEquipment: true,
    );
    final createdBy = (existing['createdBy'] ?? '').toString();
    final previousStatus = (existing['status'] ?? EquipmentStatus.ok).toString();

    final batch = _firestore.batch();

    batch.set(doc, {
      'id': trimmedEquipmentId,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all equipment reads use organizationId.
      'commandId': trimmedOrganizationId,
      'scope': scope,
      if (scope == EquipmentScope.personal) 'ownerUserId': ownerUserId,
      'name': trimmedName,
      'category': trimmedCategory,
      'status': trimmedStatus,
      'location': location.trim(),
      'nextMaintenanceDate': nextMaintenanceDate.trim(),
      'note': note.trim(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (scope == EquipmentScope.organization &&
        previousStatus != trimmedStatus) {
      _addProblemStatusNotificationToBatch(
        batch: batch,
        organizationId: trimmedOrganizationId,
        equipmentId: trimmedEquipmentId,
        equipmentName: trimmedName,
        status: trimmedStatus,
        createdBy: trimmedUpdatedBy,
      );
    }

    await batch.commit();
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Varustust ei saa salvestada ilma aktiivse ühinguta.');
    }
  }

  String _equipmentScope(Map<String, dynamic> data) {
    final scope = (data['scope'] ?? '').toString();
    return EquipmentScope.values.contains(scope)
        ? scope
        : EquipmentScope.organization;
  }

  void _validateEquipmentOwnership({
    required String scope,
    required String ownerUserId,
    required String currentUserId,
    required bool canManageOrganizationEquipment,
    required bool allowAdminPersonalEquipment,
  }) {
    if (!EquipmentScope.values.contains(scope)) {
      throw Exception('Varustuse tüüp ei ole toetatud.');
    }

    if (scope == EquipmentScope.personal) {
      if (ownerUserId.isEmpty) {
        throw Exception('Sul puudub õigus seda varustust muuta');
      }
      if (ownerUserId == currentUserId ||
          (allowAdminPersonalEquipment && canManageOrganizationEquipment)) {
        return;
      }
      throw Exception('Sul puudub õigus seda varustust muuta');
    }

    if (!canManageOrganizationEquipment) {
      throw Exception('Sul puudub õigus ühingu varustust muuta.');
    }
  }

  Future<void> checkMaintenanceDueNotifications({
    required String organizationId,
    required String createdBy,
    required bool canManageOrganizationEquipment,
  }) async {
    _requireOrganizationId(organizationId);
    if (!canManageOrganizationEquipment) {
      throw Exception(
        'Organisatsiooni hooldusteavitusi saab kontrollida ainult administraator',
      );
    }
    final snapshot = await _equipment
        .where(
          Filter.and(
            Filter.or(
              Filter('organizationId', isEqualTo: organizationId),
              // TODO: Remove commandId fallback after equipment migration.
              Filter('commandId', isEqualTo: organizationId),
            ),
            Filter('scope', isEqualTo: EquipmentScope.organization),
          ),
        )
        .get();
    final today = _dateOnly(DateTime.now());
    final warningLimit = today.add(const Duration(days: 30));

    for (final document in snapshot.docs) {
      final item = EquipmentModel.fromFirestore(document);
      final itemOrganizationId = item.organizationId.isNotEmpty
          ? item.organizationId
          : item.commandId;
      if (itemOrganizationId != organizationId) continue;
      if (item.scope != EquipmentScope.organization) continue;

      final parsedDueDate =
          DateTime.tryParse(item.nextMaintenanceDate.trim());
      if (parsedDueDate == null) continue;

      final dueDate = _dateOnly(parsedDueDate);
      final isOverdue = dueDate.isBefore(today);
      final isDueSoon = !isOverdue && !dueDate.isAfter(warningLimit);
      if (!isOverdue && !isDueSoon) continue;

      final equipmentName =
          item.name.trim().isEmpty ? 'Varustus' : item.name.trim();
      final dueDateKey = _dateKey(dueDate);
      final dueState = isOverdue ? 'overdue' : 'dueSoon';

      await _notificationService.addNotification(
        organizationId: organizationId,
        title: isOverdue
            ? 'Varustuse hooldus üle tähtaja'
            : 'Varustuse hooldus läheneb',
        message: isOverdue
            ? 'Varustuse „$equipmentName” hooldus või kontroll on üle tähtaja.'
            : 'Varustuse „$equipmentName” hoolduse või kontrolli tähtaeg '
                'läheneb.',
        type: NotificationType.equipment,
        priority: isOverdue
            ? NotificationPriority.high
            : NotificationPriority.normal,
        createdBy: createdBy,
        relatedType: NotificationType.equipment,
        relatedId: item.id,
        notificationId:
            'equipment_${item.id}_maintenance_${dueDateKey}_$dueState',
        createOnlyIfMissing: true,
      );
    }
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
        return 'vajab hooldust';
      case EquipmentStatus.broken:
        return 'katki';
      case EquipmentStatus.outOfService:
        return 'kasutusest väljas';
      default:
        return 'korras';
    }
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _dateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}
