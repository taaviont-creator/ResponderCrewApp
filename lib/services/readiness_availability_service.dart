import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

/// Only current unavailability IDs; personal schedules remain private.
class ReadinessAvailabilityService {
  Stream<Set<String>> streamUnavailableMembers(String organizationId) {
    late StreamController<Set<String>> controller;
    Timer? timer;
    var closed = false;
    var loading = false;
    Future<void> refresh() async {
      if (closed || loading) return;
      loading = true;
      try {
        final response =
            await FirebaseFunctions.instanceFor(region: 'europe-north1')
                .httpsCallable('getOrganizationReadinessAvailability')
                .call({'organizationId': organizationId});
        final ids = (response.data['unavailableUserIds'] as List)
            .cast<String>()
            .toSet();
        if (!closed) controller.add(ids);
      } catch (error, stack) {
        if (!closed) controller.addError(error, stack);
      } finally {
        loading = false;
      }
    }

    controller = StreamController<Set<String>>(
      onListen: () {
        unawaited(refresh());
        timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
      },
      onCancel: () {
        closed = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}
