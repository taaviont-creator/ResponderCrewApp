import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/availability_reminder_settings_model.dart';

class AvailabilityReminderSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _settings =>
      _firestore.collection('availabilityReminderSettings');

  String settingId({
    required String userId,
    required String organizationId,
  }) {
    return '${userId}_$organizationId';
  }

  Stream<AvailabilityReminderSettingsModel> streamMySettings({
    required String userId,
    required String organizationId,
  }) {
    final id = settingId(
      userId: userId,
      organizationId: organizationId,
    );

    return _settings.doc(id).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return AvailabilityReminderSettingsModel.defaults(
          userId: userId,
          organizationId: organizationId,
        );
      }

      return AvailabilityReminderSettingsModel.fromFirestore(snapshot);
    });
  }

  Future<void> setMySettings({
    required String userId,
    required String organizationId,
    required bool enabled,
    required int intervalHours,
    required String reminderTime,
  }) async {
    if (!AvailabilityReminderSettingsModel.allowedIntervalHours
        .contains(intervalHours)) {
      throw Exception('Unsupported reminder interval: $intervalHours');
    }

    if (!_isValidReminderTime(reminderTime)) {
      throw Exception('Unsupported reminder time: $reminderTime');
    }

    final id = settingId(
      userId: userId,
      organizationId: organizationId,
    );

    await _settings.doc(id).set({
      'id': id,
      'userId': userId,
      'organizationId': organizationId,
      // TODO: Remove commandId after all reminder settings use organizationId.
      'commandId': organizationId,
      'enabled': enabled,
      'intervalHours': intervalHours,
      'reminderTime': reminderTime,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _isValidReminderTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;

    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }
}
