import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

/// Authoritative readiness and effective roster; private schedule notes stay on the server.
class ReadinessAvailabilityService {
  Stream<Set<String>> streamUnavailableMembers(String organizationId) =>
      streamReadiness(organizationId).map(
        (data) => (data['unavailableUserIds'] as List).cast<String>().toSet(),
      );

  Stream<Map<String, dynamic>> streamReadiness(String organizationId) {
    late StreamController<Map<String, dynamic>> controller;
    Timer? timer;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? invalidation;
    var queued = false;
    var closed = false;
    var loading = false;
    Future<void> refresh() async {
      if (closed) return;
      if (loading) {
        queued = true;
        return;
      }
      loading = true;
      try {
        final response =
            await FirebaseFunctions.instanceFor(region: 'europe-north1')
                .httpsCallable('getOrganizationReadinessAvailability')
                .call({'organizationId': organizationId});
        if (!closed) {
          controller.add(Map<String, dynamic>.from(response.data as Map));
        }
      } catch (error, stack) {
        if (!closed) controller.addError(error, stack);
      } finally {
        loading = false;
        if (queued && !closed) {
          queued = false;
          unawaited(refresh());
        }
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        unawaited(refresh());
        invalidation = FirebaseFirestore.instance
            .doc('readinessNotificationState/$organizationId')
            .snapshots()
            .listen((_) => unawaited(refresh()), onError: (Object _) {});
        timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
      },
      onCancel: () {
        closed = true;
        timer?.cancel();
        unawaited(invalidation?.cancel());
      },
    );
    return controller.stream;
  }
}
