import 'package:cloud_firestore/cloud_firestore.dart';

class CalloutStatus {
  static const active = 'active';
  static const closed = 'closed';
  static const cancelled = 'cancelled';

  static const values = {
    active,
    closed,
    cancelled,
  };
}

class CalloutPriority {
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

class CalloutResponseValue {
  static const responding = 'responding';
  static const delayed = 'delayed';
  static const unavailable = 'unavailable';
  static const noResponse = 'noResponse';

  static const values = {
    responding,
    delayed,
    unavailable,
    noResponse,
  };
}

class CalloutModel {
  const CalloutModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    required this.priority,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String title;
  final String description;
  final String location;
  final String status;
  final String priority;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;

  factory CalloutModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return CalloutModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      location: _stringValue(data['location']),
      status: _stringValue(data['status'], fallback: CalloutStatus.active),
      priority: _stringValue(
        data['priority'],
        fallback: CalloutPriority.normal,
      ),
      createdBy: _stringValue(data['createdBy']),
      createdByName: _stringValue(data['createdByName']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
      closedAt: _dateTimeValue(data['closedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'commandId': commandId,
      'title': title,
      'description': description,
      'location': location,
      'status': status,
      'priority': priority,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
    };
  }
}

class CalloutResponseModel {
  const CalloutResponseModel({
    required this.id,
    required this.calloutId,
    required this.userId,
    required this.userName,
    required this.organizationId,
    required this.commandId,
    required this.response,
    this.responseMinutes,
    required this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String calloutId;
  final String userId;
  final String userName;
  final String organizationId;
  final String commandId;
  final String response;
  final int? responseMinutes;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CalloutResponseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return CalloutResponseModel(
      id: document.id,
      calloutId: _stringValue(data['calloutId']),
      userId: _stringValue(data['userId']),
      userName: _stringValue(data['userName']),
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      response: _stringValue(
        data['response'],
        fallback: CalloutResponseValue.noResponse,
      ),
      responseMinutes: _nullableIntValue(data['responseMinutes']),
      note: _stringValue(data['note']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'calloutId': calloutId,
      'userId': userId,
      'userName': userName,
      'organizationId': organizationId,
      'commandId': commandId,
      'response': response,
      'responseMinutes': responseMinutes,
      'note': note,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

class CalloutResponseSummary {
  const CalloutResponseSummary({
    required this.responding,
    required this.delayed,
    required this.unavailable,
    required this.noResponse,
  });

  final int responding;
  final int delayed;
  final int unavailable;
  final int noResponse;

  int get totalResponded => responding + delayed + unavailable;
}

class CalloutResponseMember {
  const CalloutResponseMember({
    required this.userId,
    required this.displayName,
    required this.response,
    this.responseMinutes,
  });

  final String userId;
  final String displayName;
  final String response;
  final int? responseMinutes;
}

class CalloutResponseDetails {
  const CalloutResponseDetails({
    required this.responding,
    required this.delayed,
    required this.unavailable,
    required this.noResponse,
  });

  final List<CalloutResponseMember> responding;
  final List<CalloutResponseMember> delayed;
  final List<CalloutResponseMember> unavailable;
  final List<CalloutResponseMember> noResponse;

  CalloutResponseSummary get summary => CalloutResponseSummary(
        responding: responding.length,
        delayed: delayed.length,
        unavailable: unavailable.length,
        noResponse: noResponse.length,
      );
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

int? _nullableIntValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
