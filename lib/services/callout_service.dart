import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/callout_model.dart';

class CalloutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _callouts =>
      _firestore.collection('callouts');

  CollectionReference<Map<String, dynamic>> get _responses =>
      _firestore.collection('calloutResponses');

  Stream<List<CalloutModel>> streamActiveCallouts({
    required String organizationId,
  }) {
    return _callouts
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after callout migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      final callouts = snapshot.docs
          .map(CalloutModel.fromFirestore)
          .where((callout) => callout.status == CalloutStatus.active)
          .toList();

      callouts.sort((a, b) {
        final aTime =
            a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return callouts;
    });
  }

  Stream<List<CalloutResponseModel>> streamCalloutResponses({
    required String calloutId,
  }) {
    return _responses
        .where('calloutId', isEqualTo: calloutId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(CalloutResponseModel.fromFirestore).toList();
    });
  }

  Stream<CalloutResponseModel?> streamMyResponse({
    required String calloutId,
    required String userId,
  }) {
    return _responses
        .where('calloutId', isEqualTo: calloutId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CalloutResponseModel.fromFirestore(snapshot.docs.first);
    });
  }

  Future<void> addCallout({
    required String organizationId,
    required String title,
    required String description,
    required String location,
    required String priority,
    required String createdBy,
    required String createdByName,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('Callout title is required');
    }

    if (!CalloutPriority.values.contains(priority)) {
      throw Exception('Unsupported callout priority: $priority');
    }

    final doc = _callouts.doc();

    await doc.set({
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all callout reads use organizationId.
      'commandId': organizationId,
      'title': title.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'status': CalloutStatus.active,
      'priority': priority,
      'createdBy': createdBy,
      'createdByName': createdByName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': null,
    });
  }

  Future<void> updateCalloutStatus({
    required String calloutId,
    required String status,
  }) async {
    if (status != CalloutStatus.closed && status != CalloutStatus.cancelled) {
      throw Exception('Unsupported callout status update: $status');
    }

    await _callouts.doc(calloutId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setMyResponse({
    required String calloutId,
    required String userId,
    required String userName,
    required String organizationId,
    required String response,
    int? responseMinutes,
    String note = '',
  }) async {
    if (!CalloutResponseValue.values.contains(response) ||
        response == CalloutResponseValue.noResponse) {
      throw Exception('Unsupported callout response: $response');
    }

    if (response == CalloutResponseValue.delayed &&
        (responseMinutes == null || responseMinutes <= 0)) {
      throw Exception('Delayed response requires response minutes');
    }

    final responseId = '${calloutId}_$userId';
    await _responses.doc(responseId).set({
      'id': responseId,
      'calloutId': calloutId,
      'userId': userId,
      'userName': userName.trim(),
      'organizationId': organizationId,
      // TODO: Remove commandId after all callout reads use organizationId.
      'commandId': organizationId,
      'response': response,
      'responseMinutes':
          response == CalloutResponseValue.delayed ? responseMinutes : null,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
