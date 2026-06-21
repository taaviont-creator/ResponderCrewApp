import 'package:cloud_firestore/cloud_firestore.dart';

class PlannedUnavailabilityRuleStatus {
  static const active = 'active';
  static const cancelled = 'cancelled';

  static const values = {
    active,
    cancelled,
  };
}

class PlannedUnavailabilityRuleModel {
  const PlannedUnavailabilityRuleModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.userId,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.startMinute,
    required this.endMinute,
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
  final List<int> daysOfWeek;
  final String startTime;
  final String endTime;
  final int startMinute;
  final int endMinute;
  final String note;
  final String status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  factory PlannedUnavailabilityRuleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return PlannedUnavailabilityRuleModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      userId: _stringValue(data['userId']),
      daysOfWeek: _intListValue(data['daysOfWeek']),
      startTime: _stringValue(data['startTime']),
      endTime: _stringValue(data['endTime']),
      startMinute: _intValue(data['startMinute']),
      endMinute: _intValue(data['endMinute']),
      note: _stringValue(data['note']),
      status: _stringValue(
        data['status'],
        fallback: PlannedUnavailabilityRuleStatus.active,
      ),
      createdBy: _stringValue(data['createdBy']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
      cancelledAt: _dateTimeValue(data['cancelledAt']),
      cancelledBy: _nullableStringValue(data['cancelledBy']),
    );
  }

  bool get isActive => status == PlannedUnavailabilityRuleStatus.active;
  bool get isCancelled =>
      status == PlannedUnavailabilityRuleStatus.cancelled;
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

String? _nullableStringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

List<int> _intListValue(Object? value) {
  if (value is! Iterable) return const <int>[];
  return value.whereType<num>().map((item) => item.toInt()).toList();
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
