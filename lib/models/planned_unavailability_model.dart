import 'package:cloud_firestore/cloud_firestore.dart';

class PlannedUnavailabilityStatus {
  static const active = 'active';
  static const cancelled = 'cancelled';

  static const values = {
    active,
    cancelled,
  };
}

class PlannedUnavailabilityModel {
  const PlannedUnavailabilityModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.userId,
    required this.startAt,
    required this.endAt,
    required this.note,
    required this.status,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
    this.cancelledBy,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String userId;
  final DateTime? startAt;
  final DateTime? endAt;
  final String note;
  final String status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  factory PlannedUnavailabilityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return PlannedUnavailabilityModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      userId: _stringValue(data['userId']),
      startAt: _dateTimeValue(data['startAt']),
      endAt: _dateTimeValue(data['endAt']),
      note: _stringValue(data['note']),
      status: _stringValue(
        data['status'],
        fallback: PlannedUnavailabilityStatus.active,
      ),
      createdBy: _stringValue(data['createdBy']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
      cancelledAt: _dateTimeValue(data['cancelledAt']),
      cancelledBy: _nullableStringValue(data['cancelledBy']),
    );
  }

  bool get isActive => status == PlannedUnavailabilityStatus.active;
  bool get isCancelled => status == PlannedUnavailabilityStatus.cancelled;
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

String? _nullableStringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
