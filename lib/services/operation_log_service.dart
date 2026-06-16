import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/membership_model.dart';
import '../models/operation_log_model.dart';

class OperationLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _operationLogs =>
      _firestore.collection('operationLogs');

  Stream<List<OperationLogModel>> streamOrganizationLogs({
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
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
    _requireOrganizationId(organizationId);
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
    _requireOrganizationId(organizationId);
    await _ensureCanStartOperationLog(
      organizationId: organizationId,
      createdBy: createdBy,
    );
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
    _requireOrganizationId(organizationId);
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
    _requireOrganizationId(organizationId);
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

  Future<void> updateFinalSummary({
    required String operationLogId,
    required String organizationId,
    required String summary,
    required String outcome,
    required String completedBy,
  }) async {
    _requireOrganizationId(organizationId);
    final trimmedSummary = summary.trim();
    final trimmedOutcome = outcome.trim();
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

      final status =
          (data['status'] ?? OperationLogStatus.created).toString();
      if (status != OperationLogStatus.completed) {
        throw Exception('Only a completed operation can have a final summary');
      }

      final currentSummary = (data['summary'] ?? '').toString();
      final currentOutcome = (data['outcome'] ?? '').toString();
      if (currentSummary == trimmedSummary &&
          currentOutcome == trimmedOutcome) {
        return;
      }

      transaction.update(doc, {
        'summary': trimmedSummary,
        'outcome': trimmedOutcome,
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': completedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(eventDoc, {
        'id': eventDoc.id,
        'organizationId': organizationId,
        'commandId': organizationId,
        'operationLogId': operationLogId,
        'type': OperationLogEventType.summarySaved,
        'status': OperationLogStatus.completed,
        'title': 'Lõppkokkuvõte salvestatud',
        'description': trimmedOutcome,
        'createdBy': completedBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }
  }

  Future<void> _ensureCanStartOperationLog({
    required String organizationId,
    required String createdBy,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != createdBy) {
      throw Exception('Sul puudub õigus seda toimingut teha');
    }

    final membershipSnapshot = await _firestore
        .collection('memberships')
        .doc('${currentUser.uid}_$organizationId')
        .get();
    final membership = membershipSnapshot.data();
    final membershipIsActive = membership != null &&
        ((membership['status'] == 'active') ||
            (membership['isActive'] == true)) &&
        (!membership.containsKey('status') ||
            membership['status'] == 'active') &&
        (!membership.containsKey('isActive') ||
            membership['isActive'] == true);
    if (membership == null || !membershipIsActive) {
      throw Exception('Sul puudub õigus seda toimingut teha');
    }

    final membershipOrganizationId =
        (membership['organizationId'] ?? membership['commandId'] ?? '')
            .toString();
    if (membershipOrganizationId != organizationId) {
      throw Exception('Sul puudub õigus seda toimingut teha');
    }

    if (MembershipRole.isOrgAdmin(membership['role'])) return;

    final commandSnapshot =
        await _firestore.collection('commands').doc(organizationId).get();
    if (commandSnapshot.data()?['allowMembersToStartOperationLog'] != true) {
      throw Exception('Sul puudub õigus seda toimingut teha');
    }
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
