import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityType {
  static const training = 'training';
  static const meeting = 'meeting';
  static const maintenance = 'maintenance';
  static const exercise = 'exercise';
  static const event = 'event';
  static const other = 'other';

  static const values = {
    training,
    meeting,
    maintenance,
    exercise,
    event,
    other,
  };
}

class ActivityParticipationStatus {
  static const attending = 'attending';
  static const notAttending = 'notAttending';
  static const maybe = 'maybe';

  static const values = {
    attending,
    notAttending,
    maybe,
  };
}

class ActivityModel {
  const ActivityModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.title,
    required this.description,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String title;
  final String description;
  final String type;
  final String startTime;
  final String endTime;
  final String location;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ActivityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return ActivityModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      type: _stringValue(data['type'], fallback: ActivityType.other),
      startTime: _stringValue(data['startTime']),
      endTime: _stringValue(data['endTime']),
      location: _stringValue(data['location']),
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
      'description': description,
      'type': type,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'createdBy': createdBy,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

class ActivityParticipantModel {
  const ActivityParticipantModel({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.organizationId,
    required this.commandId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String activityId;
  final String userId;
  final String organizationId;
  final String commandId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ActivityParticipantModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return ActivityParticipantModel(
      id: document.id,
      activityId: _stringValue(data['activityId']),
      userId: _stringValue(data['userId']),
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      status: _stringValue(data['status']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityId': activityId,
      'userId': userId,
      'organizationId': organizationId,
      'commandId': commandId,
      'status': status,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
