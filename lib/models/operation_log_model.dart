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
  static const open = 'open';
  static const enRoute = 'enRoute';
  static const onScene = 'onScene';
  static const inProgress = 'inProgress';
  static const completed = 'completed';
  static const returnedToBase = 'returnedToBase';

  static const created = 'created';
  static const departed = 'departed';
  static const arrived = 'arrived';

  static const values = {
    open,
    enRoute,
    onScene,
    inProgress,
    completed,
    returnedToBase,
  };

  static const legacyValues = {
    created,
    departed,
    arrived,
  };

  static String normalize(Object? value) {
    switch (value) {
      case created:
        return open;
      case departed:
        return enRoute;
      case arrived:
        return onScene;
    }
    return value is String && values.contains(value) ? value : open;
  }
}

class OperationLogEventType {
  static const statusChange = 'statusChange';
  static const manualNote = 'manualNote';
  static const quickAction = 'quickAction';
  static const summarySaved = 'summarySaved';

  static const values = {
    statusChange,
    manualNote,
    quickAction,
    summarySaved,
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
    required this.summary,
    required this.outcome,
    required this.completedBy,
    this.calloutId,
    this.timestamp,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
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
  final String summary;
  final String outcome;
  final String completedBy;
  final String? calloutId;
  final DateTime? timestamp;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

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
      status: OperationLogStatus.normalize(data['status']),
      summary: _stringValue(data['summary']),
      outcome: _stringValue(data['outcome']),
      completedBy: _stringValue(data['completedBy']),
      calloutId: _nullableStringValue(data['calloutId']),
      timestamp: _dateTimeValue(data['timestamp']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
      completedAt: _dateTimeValue(data['completedAt']),
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
      'summary': summary,
      'outcome': outcome,
      'completedBy': completedBy,
      if (calloutId != null && calloutId!.isNotEmpty) 'calloutId': calloutId,
      'timestamp': timestamp == null ? null : Timestamp.fromDate(timestamp!),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'completedAt':
          completedAt == null ? null : Timestamp.fromDate(completedAt!),
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
    required this.text,
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
  final String text;
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
      status: OperationLogStatus.normalize(data['status']),
      title: _stringValue(data['title']),
      text: _stringValue(data['text'], fallback: _stringValue(data['title'])),
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
