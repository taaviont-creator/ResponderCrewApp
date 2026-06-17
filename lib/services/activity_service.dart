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

    final activitySnapshot = await _activities.doc(activityId).get();
    final activityData = activitySnapshot.data();
    if (activityData == null) {
      throw Exception('Activity not found');
    }
    final activityOrganizationId =
        (activityData['organizationId'] ?? activityData['commandId'] ?? '')
            .toString();
    if (activityOrganizationId != organizationId) {
      throw Exception('Activity belongs to another organization');
    }

    final id = participantId(activityId: activityId, userId: userId);

    await _participants.doc(id).set({
      'id': id,
      'activityId': activityId,
      'userId': userId,
      'organizationId': organizationId,
      // TODO: Remove commandId after all activity participation reads use
      // organizationId.
      'commandId': organizationId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
}
