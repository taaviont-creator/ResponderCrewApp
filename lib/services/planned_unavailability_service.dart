import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/planned_unavailability_model.dart';

class PlannedUnavailabilityService {
  PlannedUnavailabilityService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _plannedUnavailability =>
      _firestore.collection('plannedUnavailability');

  Stream<List<PlannedUnavailabilityModel>> streamMyPeriods({
    required String organizationId,
    bool includeCancelled = false,
  }) {
    final user = _requireUser();
    final trimmedOrganizationId = _requireOrganizationId(organizationId);

    return _plannedUnavailability
        .where('organizationId', isEqualTo: trimmedOrganizationId)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snapshot) => _sortedPeriods(
            snapshot.docs.map(PlannedUnavailabilityModel.fromFirestore),
            includeCancelled: includeCancelled,
          ),
        );
  }

  Stream<List<PlannedUnavailabilityModel>> streamOrganizationPeriods({
    required String organizationId,
    bool includeCancelled = false,
  }) {
    _requireUser();
    final trimmedOrganizationId = _requireOrganizationId(organizationId);

    return _plannedUnavailability
        .where('organizationId', isEqualTo: trimmedOrganizationId)
        .snapshots()
        .map(
          (snapshot) => _sortedPeriods(
            snapshot.docs.map(PlannedUnavailabilityModel.fromFirestore),
            includeCancelled: includeCancelled,
          ),
        );
  }

  Future<void> createMyPeriod({
    required String organizationId,
    required DateTime startAt,
    required DateTime endAt,
    String? note,
  }) async {
    final user = _requireUser();
    final trimmedOrganizationId = _requireOrganizationId(organizationId);
    _requireValidPeriod(startAt: startAt, endAt: endAt);

    final doc = _plannedUnavailability.doc();
    await doc.set({
      'id': doc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all planned unavailability reads use
      // organizationId.
      'commandId': trimmedOrganizationId,
      'userId': user.uid,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'note': note?.trim() ?? '',
      'status': PlannedUnavailabilityStatus.active,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelMyPeriod({
    required String periodId,
  }) async {
    final user = _requireUser();
    final trimmedPeriodId = periodId.trim();
    if (trimmedPeriodId.isEmpty) {
      throw Exception('Sul puudub õigus seda kirjet muuta.');
    }

    final doc = _plannedUnavailability.doc(trimmedPeriodId);
    final snapshot = await doc.get();
    final data = snapshot.data();
    if (data == null || data['userId'] != user.uid) {
      throw Exception('Sul puudub õigus seda kirjet muuta.');
    }

    await doc.update({
      'status': PlannedUnavailabilityStatus.cancelled,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<PlannedUnavailabilityModel> _sortedPeriods(
    Iterable<PlannedUnavailabilityModel> periods, {
    required bool includeCancelled,
  }) {
    final sorted = periods
        .where(
          (period) => includeCancelled || period.isActive,
        )
        .toList(growable: false);

    sorted.sort((a, b) {
      final aStart = a.startAt;
      final bStart = b.startAt;
      if (aStart == null && bStart == null) return a.id.compareTo(b.id);
      if (aStart == null) return 1;
      if (bStart == null) return -1;
      return aStart.compareTo(bStart);
    });

    return sorted;
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sul puudub õigus seda kirjet muuta.');
    }
    return user;
  }

  String _requireOrganizationId(String organizationId) {
    final trimmed = organizationId.trim();
    if (trimmed.isEmpty) {
      throw Exception(
        'Planeeritud mittevalves aega ei saa lisada ilma aktiivse ühinguta.',
      );
    }
    return trimmed;
  }

  void _requireValidPeriod({
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (!startAt.isBefore(endAt)) {
      throw Exception('Algusaeg peab olema enne lõpuaega.');
    }
  }
}
