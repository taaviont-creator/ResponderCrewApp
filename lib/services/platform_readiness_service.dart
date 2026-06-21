import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/platform_readiness_model.dart';

class PlatformReadinessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _summaries =>
      _firestore.collection('organizationReadinessSummaries');

  Stream<List<PlatformReadinessSummary>> streamAllSummaries() {
    return _summaries.snapshots().map((snapshot) {
      final summaries =
          snapshot.docs.map(PlatformReadinessSummary.fromFirestore).toList();
      summaries.sort(
        (a, b) => a.organizationName.compareTo(b.organizationName),
      );
      return summaries;
    });
  }

  Stream<List<PlatformReadinessSummary>> streamOrganizationSummary({
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    return _summaries.doc(organizationId).snapshots().map((snapshot) {
      if (!snapshot.exists) return const <PlatformReadinessSummary>[];
      return [PlatformReadinessSummary.fromFirestore(snapshot)];
    });
  }

  Future<void> saveOrganizationSummary({
    required String organizationId,
    required String organizationName,
    required String region,
    required String contactName,
    required String contactPhone,
    required String readinessStatus,
    required int onDutyCount,
    required int delayedCount,
    required int minimumCrewRequired,
    required bool minimumCrewMet,
    required String primaryVesselStatus,
    required String equipmentStatus,
    required String criticalIssues,
    required String lastUpdatedBy,
  }) async {
    _requireOrganizationId(organizationId);
    if (!ReadinessStatus.values.contains(readinessStatus)) {
      throw Exception('Unsupported readiness status: $readinessStatus');
    }

    if (!ReadinessEquipmentStatus.values.contains(primaryVesselStatus)) {
      throw Exception('Unsupported vessel status: $primaryVesselStatus');
    }

    if (!ReadinessEquipmentStatus.values.contains(equipmentStatus)) {
      throw Exception('Unsupported equipment status: $equipmentStatus');
    }

    final doc = _summaries.doc(organizationId);
    final snapshot = await doc.get();

    final data = {
      'id': organizationId,
      'organizationId': organizationId,
      // TODO: Remove commandId after all readiness reads use organizationId.
      'commandId': organizationId,
      'organizationName': organizationName.trim().isEmpty
          ? organizationId
          : organizationName.trim(),
      'region': region.trim(),
      'contactName': contactName.trim(),
      'contactPhone': contactPhone.trim(),
      'readinessStatus': readinessStatus,
      'onDutyCount': onDutyCount < 0 ? 0 : onDutyCount,
      'delayedCount': delayedCount < 0 ? 0 : delayedCount,
      'minimumCrewRequired':
          minimumCrewRequired < 0 ? 0 : minimumCrewRequired,
      'minimumCrewMet': minimumCrewMet,
      'primaryVesselStatus': primaryVesselStatus,
      'equipmentStatus': equipmentStatus,
      'criticalIssues': criticalIssues.trim(),
      'lastUpdatedBy': lastUpdatedBy,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    await doc.set(data, SetOptions(merge: true));
  }

  Future<void> saveMinimumCrewRequired({
    required String organizationId,
    required String organizationName,
    required int minimumCrewRequired,
    required String lastUpdatedBy,
  }) async {
    _requireOrganizationId(organizationId);
    if (minimumCrewRequired < 0) {
      throw Exception('Sisesta korrektne arv.');
    }

    final doc = _summaries.doc(organizationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final existing = snapshot.data() ?? <String, dynamic>{};
      final onDutyCount = _nonNegativeInt(existing['onDutyCount']);
      final sanitizedMinimumCrewRequired = minimumCrewRequired;

      transaction.set(doc, {
        'id': organizationId,
        'organizationId': organizationId,
        // TODO: Remove commandId after all readiness reads use organizationId.
        'commandId': organizationId,
        'organizationName': _stringValue(
          existing['organizationName'],
          fallback: organizationName.trim().isEmpty
              ? organizationId
              : organizationName.trim(),
        ),
        'region': _stringValue(existing['region']),
        'contactName': _stringValue(existing['contactName']),
        'contactPhone': _stringValue(existing['contactPhone']),
        'readinessStatus': _readinessStatusValue(
          existing['readinessStatus'],
        ),
        'onDutyCount': onDutyCount,
        'delayedCount': _nonNegativeInt(existing['delayedCount']),
        'minimumCrewRequired': sanitizedMinimumCrewRequired,
        'minimumCrewMet': sanitizedMinimumCrewRequired > 0 &&
            onDutyCount >= sanitizedMinimumCrewRequired,
        'primaryVesselStatus': _equipmentStatusValue(
          existing['primaryVesselStatus'],
        ),
        'equipmentStatus': _equipmentStatusValue(existing['equipmentStatus']),
        'criticalIssues': _stringValue(existing['criticalIssues']),
        'lastUpdatedBy': lastUpdatedBy,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  int _nonNegativeInt(Object? value) {
    final number = value is num ? value.toInt() : 0;
    return number < 0 ? 0 : number;
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  String _readinessStatusValue(Object? value) {
    final status = _stringValue(value, fallback: ReadinessStatus.unknown);
    return ReadinessStatus.values.contains(status)
        ? status
        : ReadinessStatus.unknown;
  }

  String _equipmentStatusValue(Object? value) {
    final status = _stringValue(
      value,
      fallback: ReadinessEquipmentStatus.unknown,
    );
    return ReadinessEquipmentStatus.values.contains(status)
        ? status
        : ReadinessEquipmentStatus.unknown;
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }
  }
}
