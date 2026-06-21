import 'package:cloud_firestore/cloud_firestore.dart';

class AvailabilityStatus {
  static const offDuty = 'offDuty';
  static const onDuty = 'onDuty';
  static const delayed = 'delayed';

  static const values = {
    offDuty,
    onDuty,
    delayed,
  };
}

class AvailabilityModel {
  const AvailabilityModel({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.commandId,
    required this.status,
    required this.manualStatus,
    this.scheduledStatus,
    this.responseMinutes,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String organizationId;
  final String commandId;
  final String status;
  final String manualStatus;
  final String? scheduledStatus;
  final int? responseMinutes;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveStatus => scheduledStatus ?? manualStatus;

  factory AvailabilityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final status = _availabilityStatusValue(data['status']);

    return AvailabilityModel(
      id: document.id,
      userId: _stringValue(data['userId']),
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      status: status,
      manualStatus: _availabilityStatusValue(
        data['manualStatus'],
        fallback: status,
      ),
      scheduledStatus: _nullableAvailabilityStatusValue(
        data['scheduledStatus'],
      ),
      responseMinutes: _intValue(data['responseMinutes']),
      note: _nullableStringValue(data['note']),
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
      'status': status,
      'responseMinutes': responseMinutes,
      'note': note,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

String _availabilityStatusValue(
  Object? value, {
  String fallback = AvailabilityStatus.offDuty,
}) {
  final status = _stringValue(value, fallback: fallback);
  return AvailabilityStatus.values.contains(status) ? status : fallback;
}

String? _nullableAvailabilityStatusValue(Object? value) {
  final status = _nullableStringValue(value);
  return AvailabilityStatus.values.contains(status) ? status : null;
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

String? _nullableStringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
