import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_model.dart';
import '../models/membership_model.dart';
import '../models/notification_model.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _participants =>
      _firestore.collection('activityParticipants');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  String participantId({
    required String activityId,
    required String userId,
  }) {
    return '${activityId}_$userId';
  }

  Stream<List<ActivityModel>> streamOrganizationActivities({
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    return _activities
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after activity migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      final activities =
          snapshot.docs.map(ActivityModel.fromFirestore).toList();

      activities.sort((a, b) {
        final aTime =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return activities;
    });
  }

  Stream<ActivityParticipantModel?> streamMyParticipation({
    required String activityId,
    required String userId,
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    return _participants
        .doc(participantId(activityId: activityId, userId: userId))
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final participant = ActivityParticipantModel.fromFirestore(snapshot);
      final participantOrganizationId = participant.organizationId.isNotEmpty
          ? participant.organizationId
          : participant.commandId;
      return participantOrganizationId == organizationId ? participant : null;
    });
  }

  Future<void> addActivity({
    required String organizationId,
    required String title,
    required String description,
    required String type,
    required String startTime,
    required String location,
    required String createdBy,
  }) async {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedCreatedBy = createdBy.trim();
    _requireOrganizationId(trimmedOrganizationId);
    await _ensureCanCreateActivity(
      organizationId: trimmedOrganizationId,
      createdBy: trimmedCreatedBy,
    );
    if (title.trim().isEmpty) {
      throw Exception('Pealkiri on kohustuslik.');
    }

    if (startTime.trim().isEmpty) {
      throw Exception('Kuupäev on kohustuslik.');
    }

    if (!ActivityType.values.contains(type)) {
      throw Exception('Tegevuse tüüp ei ole toetatud.');
    }

    final activityDoc = _activities.doc();
    final notificationDoc = _notifications.doc();
    final batch = _firestore.batch();
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    final trimmedStartTime = startTime.trim();
    final trimmedLocation = location.trim();

    batch.set(activityDoc, {
      'id': activityDoc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all activity reads use organizationId.
      'commandId': trimmedOrganizationId,
      'title': trimmedTitle,
      'description': trimmedDescription,
      'type': type,
      'startTime': trimmedStartTime,
      'endTime': '',
      'location': trimmedLocation,
      'createdBy': trimmedCreatedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(notificationDoc, {
      'id': notificationDoc.id,
      'organizationId': trimmedOrganizationId,
      // TODO: Remove commandId after all notification reads use organizationId.
      'commandId': trimmedOrganizationId,
      'title': 'Uus tegevus',
      'message': 'Lisatud on uus tegevus või koolitus: $trimmedTitle',
      'type': NotificationType.activity,
      'priority': NotificationPriority.normal,
      'relatedType': 'activity',
      'relatedId': activityDoc.id,
      'createdBy': trimmedCreatedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> setMyParticipation({
    required String activityId,
    required String userId,
    required String organizationId,
    required String status,
  }) async {
    _requireOrganizationId(organizationId);
    if (!ActivityParticipationStatus.values.contains(status)) {
      throw Exception('Unsupported participation status: $status');
    }

    await _ensureActivityBelongsToOrganization(
      activityId: activityId,
      organizationId: organizationId,
    );

    final id = participantId(activityId: activityId, userId: userId);
    final participantRef = _participants.doc(id);
    final participantSnapshot = await participantRef.get();

    final data = {
      'id': id,
      'activityId': activityId,
      'userId': userId,
      'organizationId': organizationId,
      // TODO: Remove commandId after all activity participation reads use
      // organizationId.
      'commandId': organizationId,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!participantSnapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await participantRef.set(data, SetOptions(merge: true));
  }

  Future<void> confirmParticipation({
    required String activityId,
    required String userId,
    required String organizationId,
    required String attendanceStatus,
    required String confirmedBy,
    double? hours,
  }) async {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedUserId = userId.trim();
    final trimmedConfirmedBy = confirmedBy.trim();
    _requireOrganizationId(trimmedOrganizationId);

    if (activityId.trim().isEmpty || trimmedUserId.isEmpty) {
      throw Exception('Osalemise kirjet ei leitud.');
    }
    if (!ActivityAttendanceStatus.values.contains(attendanceStatus)) {
      throw Exception('Osalemise kinnituse staatus ei ole toetatud.');
    }
    if (hours != null && hours < 0) {
      throw Exception('Tundide arv ei saa olla negatiivne.');
    }

    await _ensureCanConfirmParticipation(
      organizationId: trimmedOrganizationId,
      confirmedBy: trimmedConfirmedBy,
    );
    await _ensureActivityBelongsToOrganization(
      activityId: activityId,
      organizationId: trimmedOrganizationId,
    );

    final id = participantId(activityId: activityId, userId: trimmedUserId);
    final participantRef = _participants.doc(id);
    final participantSnapshot = await participantRef.get();
    final participantData = participantSnapshot.data();
    if (participantData == null) {
      await participantRef.set({
        'id': id,
        'activityId': activityId,
        'userId': trimmedUserId,
        'organizationId': trimmedOrganizationId,
        // TODO: Remove commandId after all activity participation reads use
        // organizationId.
        'commandId': trimmedOrganizationId,
        'status': ActivityParticipationStatus.notResponded,
        'attendanceStatus': attendanceStatus,
        'hours': hours,
        'confirmedBy': trimmedConfirmedBy,
        'confirmedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    } else {
      final participantOrganizationId =
          (participantData['organizationId'] ?? participantData['commandId'] ?? '')
              .toString()
              .trim();
      if (participantOrganizationId != trimmedOrganizationId ||
          participantData['activityId'] != activityId ||
          participantData['userId'] != trimmedUserId) {
        throw Exception('Osalemise kirje kuulub teise organisatsiooni.');
      }
    }

    await participantRef.update({
      'attendanceStatus': attendanceStatus,
      'hours': hours,
      'confirmedBy': trimmedConfirmedBy,
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Tegevust ei saa lisada ilma aktiivse ühinguta.');
    }
  }

  Future<void> _ensureCanCreateActivity({
    required String organizationId,
    required String createdBy,
  }) async {
    final trimmedOrganizationId = organizationId.trim();
    final trimmedCreatedBy = createdBy.trim();
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != trimmedCreatedBy) {
      throw Exception('Sul puudub õigus tegevust lisada.');
    }

    final membershipSnapshot = await _firestore
        .collection('memberships')
        .doc('${currentUser.uid}_$trimmedOrganizationId')
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
      throw Exception('Sul puudub õigus tegevust lisada.');
    }

    final membershipOrganizationId =
        (membership['organizationId'] ?? membership['commandId'] ?? '')
            .toString()
            .trim();
    if (membershipOrganizationId != trimmedOrganizationId) {
      throw Exception('Sul puudub õigus tegevust lisada.');
    }

    if (MembershipRole.isOrgAdmin(membership['role'])) return;

    final commandSnapshot =
        await _firestore.collection('commands').doc(trimmedOrganizationId).get();
    if (commandSnapshot.data()?['allowMembersToCreateActivities'] != true) {
      throw Exception('Sul puudub õigus tegevust lisada.');
    }
  }

  Future<void> _ensureCanConfirmParticipation({
    required String organizationId,
    required String confirmedBy,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != confirmedBy) {
      throw Exception('Sul puudub oigus osalemist kinnitada.');
    }

    final membershipSnapshot = await _firestore
        .collection('memberships')
        .doc('${currentUser.uid}_$organizationId')
        .get();
    final membership = membershipSnapshot.data();
    if (membership == null ||
        !_isActiveMembership(membership) ||
        !_membershipIsForOrganization(
          membership: membership,
          organizationId: organizationId,
        ) ||
        !MembershipRole.isOrgAdmin(membership['role'])) {
      throw Exception('Sul puudub oigus osalemist kinnitada.');
    }
  }

  Future<void> _ensureActivityBelongsToOrganization({
    required String activityId,
    required String organizationId,
  }) async {
    final activitySnapshot = await _activities.doc(activityId).get();
    final activityData = activitySnapshot.data();
    if (activityData == null) {
      throw Exception('Activity not found');
    }
    final activityOrganizationId =
        (activityData['organizationId'] ?? activityData['commandId'] ?? '')
            .toString()
            .trim();
    if (activityOrganizationId != organizationId) {
      throw Exception('Activity belongs to another organization');
    }
  }

  bool _membershipIsForOrganization({
    required Map<String, dynamic> membership,
    required String organizationId,
  }) {
    return (membership['organizationId'] ?? membership['commandId'] ?? '')
            .toString()
            .trim() ==
        organizationId;
  }

  bool _isActiveMembership(Map<String, dynamic> membership) {
    final hasActiveMarker =
        membership['status'] == 'active' || membership['isActive'] == true;
    final statusIsActive = !membership.containsKey('status') ||
        membership['status'] == 'active';
    final flagIsActive = !membership.containsKey('isActive') ||
        membership['isActive'] == true;
    return hasActiveMarker && statusIsActive && flagIsActive;
  }
}
