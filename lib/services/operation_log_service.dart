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
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
