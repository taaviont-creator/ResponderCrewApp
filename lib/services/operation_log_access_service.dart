import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/membership_model.dart';

/// Participation grants append-only access, never event management rights.
bool canAppendAsCalloutParticipant({
  required String organizationId,
  required String userId,
  required String calloutId,
  Map<String, dynamic>? organization,
  Map<String, dynamic>? membership,
  Map<String, dynamic>? callout,
  Map<String, dynamic>? response,
  Map<String, dynamic>? attendance,
}) {
  bool scoped(Map<String, dynamic>? d) =>
      d != null &&
      (d['organizationId'] ?? d['commandId']) == organizationId &&
      (d['commandId'] ?? organizationId) == organizationId;
  if (organization == null ||
      (organization['status'] ?? 'approved') != 'approved' ||
      !scoped(membership) ||
      membership!['userId'] != userId ||
      !MembershipModel.fromMap(
        id: '${userId}_$organizationId',
        data: membership,
      ).isActive ||
      !scoped(callout) ||
      callout!['status'] != 'active') {
    return false;
  }
  bool own(Map<String, dynamic>? d) =>
      scoped(d) && d!['userId'] == userId && d['calloutId'] == calloutId;
  // An explicit crew attendance decision takes precedence over a response.
  if (attendance != null) return own(attendance) && attendance['status'] == 'confirmed';
  return own(response) &&
      ['responding', 'delayed'].contains(response!['response']);
}

class OperationLogAccessService {
  final _db = FirebaseFirestore.instance;
  Stream<bool> participantAccess({
    required String organizationId,
    required String userId,
    required String calloutId,
  }) {
    final values = <String, Map<String, dynamic>?>{};
    final subscriptions = <StreamSubscription<dynamic>>[];
    late StreamController<bool> controller;
    final streams = <String, Stream<Map<String, dynamic>?>>{
      'organization': _db
          .doc('commands/$organizationId')
          .snapshots()
          .map((d) => d.data()),
      'membership': _db
          .doc('memberships/${userId}_$organizationId')
          .snapshots()
          .map((d) => d.data()),
      'callout': _db
          .doc('callouts/$calloutId')
          .snapshots()
          .map((d) => d.data()),
      for (final entry in const {
        'response': 'calloutResponses',
        'attendance': 'calloutAttendance',
      }.entries)
        entry.key: _db
            .collection(entry.value)
            .where('organizationId', isEqualTo: organizationId)
            .where('calloutId', isEqualTo: calloutId)
            .where('userId', isEqualTo: userId)
            .snapshots()
            .map((s) {
              for (final d in s.docs) {
                if (d.id == '${calloutId}_$userId') return d.data();
              }
              return null;
            }),
    };
    controller = StreamController<bool>(
      onListen: () {
        for (final entry in streams.entries) {
          subscriptions.add(
            entry.value.listen(
              (data) {
                values[entry.key] = data;
                if (values.length == streams.length) {
                  controller.add(
                    canAppendAsCalloutParticipant(
                      organizationId: organizationId,
                      userId: userId,
                      calloutId: calloutId,
                      organization: values['organization'],
                      membership: values['membership'],
                      callout: values['callout'],
                      response: values['response'],
                      attendance: values['attendance'],
                    ),
                  );
                }
              },
              onError: (Object error, StackTrace stack) {
                values.remove(entry.key);
                controller.add(false);
                controller.addError(error, stack);
              },
            ),
          );
        }
      },
      onCancel: () async {
        await Future.wait(subscriptions.map((s) => s.cancel()));
      },
    );
    return controller.stream.distinct();
  }
}
