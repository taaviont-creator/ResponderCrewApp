import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_model.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _participants =>
      _firestore.collection('activityParticipants');

  String participantId({
    required String activityId,
    required String userId,
  }) {
    return '${activityId}_$userId';
  }

  Stream<List<ActivityModel>> streamOrganizationActivities({
    required String organizationId,
  }) {
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
  }) {
    return _participants
        .doc(participantId(activityId: activityId, userId: userId))
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return ActivityParticipantModel.fromFirestore(snapshot);
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
    if (title.trim().isEmpty) {
      throw Exception('Activity title is required');
    }

    if (!ActivityType.values.contains(type)) {
      throw Exception('Unsupported activity type: $type');
    }

    final doc = _activities.doc();

    await doc.set({
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all activity reads use organizationId.
      'commandId': organizationId,
      'title': title.trim(),
      'description': description.trim(),
      'type': type,
      'startTime': startTime.trim(),
      'endTime': '',
      'location': location.trim(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setMyParticipation({
    required String activityId,
    required String userId,
    required String organizationId,
    required String status,
  }) async {
    if (!ActivityParticipationStatus.values.contains(status)) {
      throw Exception('Unsupported participation status: $status');
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
}
