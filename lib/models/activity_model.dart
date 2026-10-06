import 'package:cloud_firestore/cloud_firestore.dart';
import 'activity_schedule.dart';

class ActivityType {
  static const training = 'training';
  static const meeting = 'meeting';
  static const maintenance = 'maintenance';
  static const repair = 'repair';
  static const groundskeeping = 'groundskeeping';
  static const exercise = 'exercise';
  static const event = 'event';
  static const other = 'other';

  static const values = {
    training,
    meeting,
    maintenance,
    repair,
    groundskeeping,
    exercise,
    event,
    other,
  };
}

class ActivityParticipationStatus {
  static const attending = 'attending';
  static const notAttending = 'notAttending';
  static const maybe = 'maybe';
  static const registered = 'registered';
  static const cannotAttend = 'cannotAttend';
  static const attendedSelfReported = 'attendedSelfReported';
  static const notResponded = 'notResponded';

  static const values = {
    attending,
    notAttending,
    maybe,
    registered,
    cannotAttend,
    attendedSelfReported,
    notResponded,
  };
}

class ActivityAttendanceStatus {
  static const notConfirmed = 'notConfirmed';
  static const confirmed = 'confirmed';
  static const absent = 'absent';

  static const values = {notConfirmed, confirmed, absent};
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
    this.entryKind = 'scheduled',
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
  final String entryKind;

  // Older contributions were already created by the same server endpoint.
  bool get isContribution =>
      entryKind == 'contribution' || id.startsWith('contribution_');

  DateTime? get startsAt => ActivitySchedule.parse(startTime);
  DateTime? get endsAt => ActivitySchedule.parse(endTime);
  bool occursOn(DateTime day) {
    final start = startsAt;
    if (start == null) return false;
    final from = ActivitySchedule.fromSelection(day, 0, 0)!;
    final until = ActivitySchedule.fromSelection(
      DateTime(day.year, day.month, day.day + 1),
      0,
      0,
    )!;
    final end = endsAt;
    return end != null && end.isAfter(start)
        ? start.isBefore(until) && end.isAfter(from)
        : ActivitySchedule.sameDay(start, day);
  }

  double? get durationHours {
    final start = startsAt, end = endsAt;
    return start != null && end != null && end.isAfter(start)
        ? end.difference(start).inMinutes / 60
        : null;
  }

  bool isUpcomingOrOngoing(DateTime now) {
    if (isContribution) return false;
    final start = startsAt;
    if (start == null) return false;
    final end = endsAt;
    if (end != null && end.isAfter(start)) return end.isAfter(now);
    // Date-only legacy activities remain visible throughout their day.
    if (RegExp(
      r'^(?:\d{4}-\d{2}-\d{2}|\d{1,2}\.\d{1,2}\.\d{4})$',
    ).hasMatch(startTime.trim())) {
      return !DateTime(start.year, start.month, start.day).isBefore(
        DateTime(
          ActivitySchedule.inEstonia(now).year,
          ActivitySchedule.inEstonia(now).month,
          ActivitySchedule.inEstonia(now).day,
        ),
      );
    }
    return !start.isBefore(now);
  }

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
      entryKind: _stringValue(data['entryKind'], fallback: 'scheduled'),
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
      'entryKind': entryKind,
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
    this.attendanceStatus = ActivityAttendanceStatus.notConfirmed,
    this.hours,
    this.confirmedBy = '',
    this.confirmedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String activityId;
  final String userId;
  final String organizationId;
  final String commandId;
  final String status;
  final String attendanceStatus;
  final double? hours;
  final String confirmedBy;
  final DateTime? confirmedAt;
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
      attendanceStatus: _stringValue(
        data['attendanceStatus'],
        fallback: ActivityAttendanceStatus.notConfirmed,
      ),
      hours: _doubleValue(data['hours']),
      confirmedBy: _stringValue(data['confirmedBy']),
      confirmedAt: _dateTimeValue(data['confirmedAt']),
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
      if (attendanceStatus != ActivityAttendanceStatus.notConfirmed)
        'attendanceStatus': attendanceStatus,
      if (hours != null) 'hours': hours,
      if (confirmedBy.isNotEmpty) 'confirmedBy': confirmedBy,
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
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

double? _doubleValue(Object? value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return null;
}
