import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationType {
  static const info = 'info';
  static const warning = 'warning';
  static const equipment = 'equipment';
  static const availability = 'availability';
  static const activity = 'activity';
  static const operation = 'operation';
  static const callout = 'callout';
  static const other = 'other';

  static const values = {
    info,
    warning,
    equipment,
    availability,
    activity,
    operation,
    callout,
    other,
  };
}

class NotificationPriority {
  static const low = 'low';
  static const normal = 'normal';
  static const high = 'high';
  static const critical = 'critical';

  static const values = {
    low,
    normal,
    high,
    critical,
  };
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.relatedType,
    this.relatedId,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String? relatedType;
  final String? relatedId;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return NotificationModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      title: _stringValue(data['title']),
      message: _stringValue(data['message']),
      type: _stringValue(data['type'], fallback: NotificationType.info),
      priority: _stringValue(
        data['priority'],
        fallback: NotificationPriority.normal,
      ),
      relatedType: _nullableStringValue(data['relatedType']),
      relatedId: _nullableStringValue(data['relatedId']),
      createdBy: _stringValue(data['createdBy']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'commandId': commandId,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'relatedType': relatedType,
      'relatedId': relatedId,
      'createdBy': createdBy,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

class NotificationReadModel {
  const NotificationReadModel({
    required this.id,
    required this.notificationId,
    required this.userId,
    required this.organizationId,
    required this.commandId,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String notificationId;
  final String userId;
  final String organizationId;
  final String commandId;
  final DateTime? readAt;
  final DateTime? createdAt;

  factory NotificationReadModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return NotificationReadModel(
      id: document.id,
      notificationId: _stringValue(data['notificationId']),
      userId: _stringValue(data['userId']),
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      readAt: _dateTimeValue(data['readAt']),
      createdAt: _dateTimeValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notificationId': notificationId,
      'userId': userId,
      'organizationId': organizationId,
      'commandId': commandId,
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }
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
