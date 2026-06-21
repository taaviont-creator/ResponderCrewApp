import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';

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

  CollectionReference<Map<String, dynamic>> get _plannedUnavailabilityRules =>
      _firestore.collection('plannedUnavailabilityRules');

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

  Stream<List<PlannedUnavailabilityRuleModel>> streamMyRules({
    required String organizationId,
    bool includeCancelled = false,
  }) {
    final user = _requireUser();
    final trimmedOrganizationId = _requireOrganizationId(organizationId);

    return _plannedUnavailabilityRules
        .where('organizationId', isEqualTo: trimmedOrganizationId)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snapshot) => _sortedRules(
            snapshot.docs.map(PlannedUnavailabilityRuleModel.fromFirestore),
            includeCancelled: includeCancelled,
          ),
        );
  }

  Stream<List<PlannedUnavailabilityRuleModel>> streamOrganizationRules({
    required String organizationId,
    bool includeCancelled = false,
  }) {
    _requireUser();
    final trimmedOrganizationId = _requireOrganizationId(organizationId);

    return _plannedUnavailabilityRules
        .where('organizationId', isEqualTo: trimmedOrganizationId)
        .snapshots()
        .map(
          (snapshot) => _sortedRules(
            snapshot.docs.map(PlannedUnavailabilityRuleModel.fromFirestore),
            includeCancelled: includeCancelled,
          ),
        );
  }

  Future<void> createMyRule({
    required String organizationId,
    required List<int> daysOfWeek,
    required int startMinute,
    required int endMinute,
    String? note,
  }) async {
    final user = _requireUser();
    final trimmedOrganizationId = _requireOrganizationId(organizationId);
    final normalizedDays = _requireValidDaysOfWeek(daysOfWeek);
    _requireValidMinuteRange(
      startMinute: startMinute,
      endMinute: endMinute,
    );

    final doc = _plannedUnavailabilityRules.doc();
    await doc.set({
      'id': doc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all planned unavailability reads use
      // organizationId.
      'commandId': trimmedOrganizationId,
      'userId': user.uid,
      'daysOfWeek': normalizedDays,
      'startTime': _formatMinuteOfDay(startMinute),
      'endTime': _formatMinuteOfDay(endMinute),
      'startMinute': startMinute,
      'endMinute': endMinute,
      'note': note?.trim() ?? '',
      'status': PlannedUnavailabilityRuleStatus.active,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelMyRule({
    required String ruleId,
  }) async {
    final user = _requireUser();
    final trimmedRuleId = ruleId.trim();
    if (trimmedRuleId.isEmpty) {
      throw Exception('Sul puudub õigus seda kirjet muuta.');
    }

    final doc = _plannedUnavailabilityRules.doc(trimmedRuleId);
    final snapshot = await doc.get();
    final data = snapshot.data();
    if (data == null || data['userId'] != user.uid) {
      throw Exception('Sul puudub õigus seda kirjet muuta.');
    }

    await doc.update({
      'status': PlannedUnavailabilityRuleStatus.cancelled,
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

  List<PlannedUnavailabilityRuleModel> _sortedRules(
    Iterable<PlannedUnavailabilityRuleModel> rules, {
    required bool includeCancelled,
  }) {
    final sorted = rules
        .where(
          (rule) => includeCancelled || rule.isActive,
        )
        .toList(growable: false);

    sorted.sort((a, b) {
      final aDay = a.daysOfWeek.isEmpty ? 8 : a.daysOfWeek.first;
      final bDay = b.daysOfWeek.isEmpty ? 8 : b.daysOfWeek.first;
      final dayCompare = aDay.compareTo(bDay);
      if (dayCompare != 0) return dayCompare;
      final startCompare = a.startMinute.compareTo(b.startMinute);
      if (startCompare != 0) return startCompare;
      return a.id.compareTo(b.id);
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

  List<int> _requireValidDaysOfWeek(List<int> daysOfWeek) {
    if (daysOfWeek.isEmpty ||
        daysOfWeek.any((day) => day < 1 || day > 7)) {
      throw Exception('Vali vähemalt üks nädalapäev.');
    }

    final normalized = daysOfWeek.toSet().toList()..sort();
    return normalized;
  }

  void _requireValidMinuteRange({
    required int startMinute,
    required int endMinute,
  }) {
    if (startMinute < 0 ||
        startMinute > 1439 ||
        endMinute < 0 ||
        endMinute > 1439 ||
        startMinute >= endMinute) {
      throw Exception('Algusaeg peab olema enne lõpuaega.');
    }
  }

  String _formatMinuteOfDay(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
