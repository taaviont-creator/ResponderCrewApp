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

  Stream<List<OperationLogEventModel>> streamLogEvents({
    required String operationLogId,
    required String organizationId,
  }) {
    return _operationLogs
        .doc(operationLogId)
        .collection('events')
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map(OperationLogEventModel.fromFirestore)
          .where((event) {
        final eventOrganizationId = event.organizationId.isNotEmpty
            ? event.organizationId
            : event.commandId;
        return event.operationLogId == operationLogId &&
            eventOrganizationId == organizationId;
      }).toList();

      events.sort((a, b) {
        final aTime =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      return events;
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

    final createdEvent = doc.collection('events').doc('created');
    final batch = _firestore.batch();

    batch.set(doc, {
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

    batch.set(createdEvent, {
      'id': createdEvent.id,
      'organizationId': organizationId,
      'commandId': organizationId,
      'operationLogId': doc.id,
      'type': OperationLogEventType.statusChange,
      'status': OperationLogStatus.created,
      'title': _operationLogStatusLabel(OperationLogStatus.created),
      'description': '',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> updateLogStatus({
    required String operationLogId,
    required String organizationId,
    required String status,
    required String updatedBy,
  }) async {
    if (!OperationLogStatus.values.contains(status)) {
      throw Exception('Unsupported operation log status: $status');
    }

    final doc = _operationLogs.doc(operationLogId);
    final eventDoc = doc.collection('events').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
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

      transaction.update(doc, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(eventDoc, {
        'id': eventDoc.id,
        'organizationId': organizationId,
        'commandId': organizationId,
        'operationLogId': operationLogId,
        'type': OperationLogEventType.statusChange,
        'status': status,
        'title': _operationLogStatusLabel(status),
        'description': '',
        'createdBy': updatedBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addManualEvent({
    required String operationLogId,
    required String organizationId,
    required String title,
    required String createdBy,
    String type = OperationLogEventType.manualNote,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw Exception('Operation log event title is required');
    }
    if (type != OperationLogEventType.manualNote &&
        type != OperationLogEventType.quickAction) {
      throw Exception('Unsupported manual operation log event type: $type');
    }

    final doc = _operationLogs.doc(operationLogId);
    final eventDoc = doc.collection('events').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
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
      transaction.set(eventDoc, {
        'id': eventDoc.id,
        'organizationId': organizationId,
        'commandId': organizationId,
        'operationLogId': operationLogId,
        'type': type,
        'status': currentStatus,
        'title': trimmedTitle,
        'description': '',
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

String _operationLogStatusLabel(String status) {
  switch (status) {
    case OperationLogStatus.departed:
      return 'Väljasõit';
    case OperationLogStatus.arrived:
      return 'Kohal';
    case OperationLogStatus.inProgress:
      return 'Tegevus käib';
    case OperationLogStatus.completed:
      return 'Lõpetatud';
    case OperationLogStatus.returnedToBase:
      return 'Tagasi baasis';
    default:
      return 'Logi loodud';
  }
}
