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

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }
  }
}
