import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operation_log_model.dart';

class OperationLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _operationLogs =>
      _firestore.collection('operationLogs');

  Stream<List<OperationLogModel>> streamOrganizationLogs({
    required String organizationId,
  }) {
    return _operationLogs
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after operation log migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      final logs =
          snapshot.docs.map(OperationLogModel.fromFirestore).toList();

      logs.sort((a, b) {
        final aTime =
            a.timestamp ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.timestamp ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return logs;
    });
  }

  Future<void> addLog({
    required String organizationId,
    required String createdBy,
    required String createdByName,
    required String type,
    required String title,
    required String description,
  }) async {
    if (!OperationLogType.values.contains(type)) {
      throw Exception('Unsupported operation log type: $type');
    }

    if (title.trim().isEmpty) {
      throw Exception('Operation log title is required');
    }

    final doc = _operationLogs.doc();

    await doc.set({
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all operation log reads use organizationId.
      'commandId': organizationId,
      'createdBy': createdBy,
      'createdByName': createdByName.trim(),
      'type': type,
      'title': title.trim(),
      'description': description.trim(),
      'status': OperationLogStatus.created,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLogStatus({
    required String operationLogId,
    required String organizationId,
    required String status,
  }) async {
    if (!OperationLogStatus.values.contains(status)) {
      throw Exception('Unsupported operation log status: $status');
    }

    final doc = _operationLogs.doc(operationLogId);
    final snapshot = await doc.get();
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Operation log entry not found');
    }

    final logOrganizationId =
        (data['organizationId'] ?? data['commandId'] ?? '').toString();
    if (logOrganizationId != organizationId) {
      throw Exception('Operation log belongs to another organization');
    }

    final currentStatus =
        (data['status'] ?? OperationLogStatus.created).toString();
    if (currentStatus == status) return;

    await doc.set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
