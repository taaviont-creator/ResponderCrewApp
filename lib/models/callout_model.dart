import 'package:cloud_firestore/cloud_firestore.dart';

class CalloutType {
  static const sar = 'sar';
  static const tross = 'tross';
  static const values = {sar, tross};
  static String label(String type) => type == tross ? 'TROSSI mereabi' : 'SAR sündmus';
  static const sarChoices = ['Inimene vees.', 'Punane rakett.', 'Uppumisohus alus.', 'Alus madalikul kinni.', 'Eksinud alus.', 'Terviserikkega inimene alusel.', 'Muu sündmus.'];
  static const trossChoices = ['Tehniline rike.', 'Mootoririke.', 'Vajab pukseerimist.', 'Kütus otsas.', 'Käivitusabi.', 'Muu mereabi.'];
  static List<String> choices(String type) => type == tross ? trossChoices : sarChoices;
  static bool validTarget(String type, int? minutes) =>
      values.contains(type) && (type == tross
          ? minutes != null && minutes >= 1 && minutes <= 60
          : minutes == null);
}

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
    this.calloutType = CalloutType.sar,
    this.responseTargetMinutes,
    this.startedAt,
    this.endedAt,
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
  final String calloutType;
  final int? responseTargetMinutes;
  final DateTime? startedAt;
  final DateTime? endedAt;
  DateTime? get effectiveStartedAt => startedAt ?? createdAt;
  DateTime? get effectiveEndedAt => endedAt ?? closedAt;

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
      calloutType: _stringValue(data['calloutType'], fallback: CalloutType.sar),
      responseTargetMinutes: _nullableIntValue(data['responseTargetMinutes']),
      startedAt: _dateTimeValue(data['startedAt']),
      endedAt: _dateTimeValue(data['endedAt']),
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
      'calloutType': calloutType,
      'responseTargetMinutes': responseTargetMinutes,
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
    this.isSeaRescueLevel2 = false,
    this.seaRescueLevel = 'none',
    this.responseMinutes,
    this.respondedAt,
  });

  final String userId;
  final String displayName;
  final String response;
  final bool isSeaRescueLevel2;
  final String seaRescueLevel;
  final int? responseMinutes;
  final DateTime? respondedAt;
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
