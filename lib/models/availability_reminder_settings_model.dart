import 'package:cloud_firestore/cloud_firestore.dart';

class AvailabilityReminderSettingsModel {
  const AvailabilityReminderSettingsModel({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.commandId,
    required this.enabled,
    required this.intervalHours,
    required this.reminderTime,
    this.createdAt,
    this.updatedAt,
  });

  static const defaultEnabled = false;
  static const defaultIntervalHours = 24;
  static const defaultReminderTime = '09:00';
  static const allowedIntervalHours = {12, 24, 48, 168};

  final String id;
  final String userId;
  final String organizationId;
  final String commandId;
  final bool enabled;
  final int intervalHours;
  final String reminderTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AvailabilityReminderSettingsModel.defaults({
    required String userId,
    required String organizationId,
  }) {
    return AvailabilityReminderSettingsModel(
      id: '${userId}_$organizationId',
      userId: userId,
      organizationId: organizationId,
      commandId: organizationId,
      enabled: defaultEnabled,
      intervalHours: defaultIntervalHours,
      reminderTime: defaultReminderTime,
    );
  }

  factory AvailabilityReminderSettingsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AvailabilityReminderSettingsModel(
      id: document.id,
      userId: _stringValue(data['userId']),
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      enabled: _boolValue(
        data['enabled'],
        fallback: defaultEnabled,
      ),
      intervalHours: _intervalValue(data['intervalHours']),
      reminderTime: _stringValue(
        data['reminderTime'],
        fallback: defaultReminderTime,
      ),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'organizationId': organizationId,
      'commandId': commandId,
      'enabled': enabled,
      'intervalHours': intervalHours,
      'reminderTime': reminderTime,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

bool _boolValue(Object? value, {required bool fallback}) {
  return value is bool ? value : fallback;
}

int _intervalValue(Object? value) {
  final interval = value is int ? value : null;
  if (AvailabilityReminderSettingsModel.allowedIntervalHours
      .contains(interval)) {
    return interval!;
  }

  return AvailabilityReminderSettingsModel.defaultIntervalHours;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
