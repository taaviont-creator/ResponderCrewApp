import 'package:cloud_firestore/cloud_firestore.dart';

class OperationLogType {
  static const departure = 'departure';
  static const arrivalOnScene = 'arrivalOnScene';
  static const searchStarted = 'searchStarted';
  static const searchEnded = 'searchEnded';
  static const patientRecovered = 'patientRecovered';
  static const towingStarted = 'towingStarted';
  static const towingEnded = 'towingEnded';
  static const returnedToBase = 'returnedToBase';
  static const note = 'note';
  static const other = 'other';

  static const values = {
    departure,
    arrivalOnScene,
    searchStarted,
    searchEnded,
    patientRecovered,
    towingStarted,
    towingEnded,
    returnedToBase,
    note,
    other,
  };
}

class OperationLogStatus {
  static const created = 'created';
  static const departed = 'departed';
  static const arrived = 'arrived';
  static const inProgress = 'inProgress';
  static const completed = 'completed';
  static const returnedToBase = 'returnedToBase';

  static const values = {
    created,
    departed,
    arrived,
    inProgress,
    completed,
    returnedToBase,
  };
}

class OperationLogEventType {
  static const statusChange = 'statusChange';
  static const manualNote = 'manualNote';
  static const quickAction = 'quickAction';

  static const values = {
    statusChange,
    manualNote,
    quickAction,
  };
}

class OperationLogModel {
  const OperationLogModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.createdBy,
    required this.createdByName,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    this.calloutId,
    this.timestamp,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String createdBy;
  final String createdByName;
  final String type;
  final String title;
  final String description;
  final String status;
  final String? calloutId;
  final DateTime? timestamp;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OperationLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return OperationLogModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      createdBy: _stringValue(data['createdBy']),
      createdByName: _stringValue(data['createdByName']),
      type: _stringValue(
        data['type'],
        fallback: OperationLogType.note,
      ),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      status: _stringValue(
        data['status'],
        fallback: OperationLogStatus.created,
      ),
      calloutId: _nullableStringValue(data['calloutId']),
      timestamp: _dateTimeValue(data['timestamp']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'commandId': commandId,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'type': type,
      'title': title,
      'description': description,
      'status': status,
      if (calloutId != null && calloutId!.isNotEmpty) 'calloutId': calloutId,
      'timestamp': timestamp == null ? null : Timestamp.fromDate(timestamp!),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

class OperationLogEventModel {
  const OperationLogEventModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.operationLogId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.createdBy,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String operationLogId;
  final String type;
  final String status;
  final String title;
  final String description;
  final String createdBy;
  final DateTime? createdAt;

  factory OperationLogEventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return OperationLogEventModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      operationLogId: _stringValue(data['operationLogId']),
      type: _stringValue(
        data['type'],
        fallback: OperationLogEventType.statusChange,
      ),
      status: _stringValue(
        data['status'],
        fallback: OperationLogStatus.created,
      ),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      createdBy: _stringValue(data['createdBy']),
      createdAt: _dateTimeValue(data['createdAt']),
    );
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
