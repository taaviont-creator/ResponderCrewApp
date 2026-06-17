import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/availability_model.dart';
import '../models/certificate_model.dart';
import '../models/equipment_model.dart';
import '../models/membership_model.dart';
import '../models/statistics_model.dart';
import 'membership_service.dart';

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MembershipService _membershipService = MembershipService();

  Future<StatisticsSummary> loadOrganizationStatistics({
    required String organizationId,
    required String currentUid,
    required bool canViewOrganizationCertificates,
  }) async {
    _requireOrganizationId(organizationId);
    await _ensureCanViewStatistics(
      organizationId: organizationId,
      currentUid: currentUid,
    );
    final activeMemberships = await _membershipService
        .loadActiveMembershipsForOrganization(organizationId);
    final activeMemberIds = activeMemberships
        .map((doc) => (doc.data()['userId'] ?? '').toString())
        .where((userId) => userId.isNotEmpty)
        .toSet();

    final availabilitySnapshot = await _firestore
        .collection('availability')
        .where(_organizationFilter(organizationId))
        .get();
    final availabilityByUserId = <String, String>{};
    for (final doc in availabilitySnapshot.docs) {
      final data = doc.data();
      final userId = (data['userId'] ?? '').toString();
      final status = (data['status'] ?? AvailabilityStatus.offDuty).toString();
      if (activeMemberIds.contains(userId)) {
        availabilityByUserId[userId] = status;
      }
    }

    var onDutyCount = 0;
    var delayedCount = 0;
    var offDutyCount = 0;
    for (final userId in activeMemberIds) {
      final status = availabilityByUserId[userId] ?? AvailabilityStatus.offDuty;
      if (status == AvailabilityStatus.onDuty) {
        onDutyCount++;
      } else if (status == AvailabilityStatus.delayed) {
        delayedCount++;
      } else {
        offDutyCount++;
      }
    }

    final equipmentSnapshot = await _firestore
        .collection('equipment')
        .where(
          Filter.and(
            _organizationFilter(organizationId),
            Filter('scope', isEqualTo: EquipmentScope.organization),
          ),
        )
        .get();
    var equipmentNeedsMaintenanceCount = 0;
    var equipmentUnavailableCount = 0;
    for (final doc in equipmentSnapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == EquipmentStatus.needsMaintenance) {
        equipmentNeedsMaintenanceCount++;
      }
      if (status == EquipmentStatus.broken ||
          status == EquipmentStatus.outOfService) {
        equipmentUnavailableCount++;
      }
    }

    final operationLogsSnapshot = await _firestore
        .collection('operationLogs')
        .where(_organizationFilter(organizationId))
        .get();

    final activitiesSnapshot = await _firestore
        .collection('activities')
        .where(_organizationFilter(organizationId))
        .get();
    var upcomingActivityCount = 0;
    for (final doc in activitiesSnapshot.docs) {
      final data = doc.data();
      final startTime = (data['startTime'] ?? '').toString().trim();
      final createdAt = data['createdAt'];
      if (startTime.isNotEmpty || createdAt is Timestamp) {
        upcomingActivityCount++;
      }
    }

    final certificatesQuery = canViewOrganizationCertificates
        ? _firestore
            .collection('certificates')
            .where(_organizationFilter(organizationId))
        : _firestore
            .collection('certificates')
            .where('userId', isEqualTo: currentUid)
            .where(_organizationFilter(organizationId));
    final certificatesSnapshot = await certificatesQuery.get();
    var validCertificateCount = 0;
    var expiredCertificateCount = 0;
    for (final doc in certificatesSnapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == CertificateStatus.valid) {
        validCertificateCount++;
      } else if (status == CertificateStatus.expired) {
        expiredCertificateCount++;
      }
    }

    return StatisticsSummary(
      memberCount: activeMemberIds.length,
      onDutyCount: onDutyCount,
      delayedCount: delayedCount,
      offDutyCount: offDutyCount,
      equipmentCount: equipmentSnapshot.docs.length,
      equipmentNeedsMaintenanceCount: equipmentNeedsMaintenanceCount,
      equipmentUnavailableCount: equipmentUnavailableCount,
      operationLogCount: operationLogsSnapshot.docs.length,
      upcomingActivityCount: upcomingActivityCount,
      validCertificateCount: validCertificateCount,
      expiredCertificateCount: expiredCertificateCount,
    );
  }

  Filter _organizationFilter(String organizationId) {
    return Filter.or(
      Filter('organizationId', isEqualTo: organizationId),
      // TODO: Remove commandId fallback after statistics reads use
      // organizationId-only data.
      Filter('commandId', isEqualTo: organizationId),
    );
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }
  }

  Future<void> _ensureCanViewStatistics({
    required String organizationId,
    required String currentUid,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != currentUid) {
      throw Exception('Sul puudub õigus seda vaadet kasutada');
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
    if (membership == null ||
        !membershipIsActive) {
      throw Exception('Sul puudub õigus seda vaadet kasutada');
    }

    final membershipOrganizationId =
        (membership['organizationId'] ?? membership['commandId'] ?? '')
            .toString();
    if (membershipOrganizationId != organizationId) {
      throw Exception('Sul puudub õigus seda vaadet kasutada');
    }

    if (MembershipRole.isOrgAdmin(membership['role'])) return;

    final commandSnapshot =
        await _firestore.collection('commands').doc(organizationId).get();
    if (commandSnapshot.data()?['allowMembersToViewStatistics'] != true) {
      throw Exception('Sul puudub õigus seda vaadet kasutada');
    }
  }
}
