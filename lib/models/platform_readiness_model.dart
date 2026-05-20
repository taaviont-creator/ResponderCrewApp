import 'package:cloud_firestore/cloud_firestore.dart';

class ReadinessStatus {
  static const ready = 'ready';
  static const limited = 'limited';
  static const notReady = 'notReady';
  static const unknown = 'unknown';

  static const values = {
    ready,
    limited,
    notReady,
    unknown,
  };
}

class ReadinessEquipmentStatus {
  static const ok = 'ok';
  static const issues = 'issues';
  static const critical = 'critical';
  static const unknown = 'unknown';

  static const values = {
    ok,
    issues,
    critical,
    unknown,
  };
}

class PlatformReadinessSummary {
  const PlatformReadinessSummary({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.organizationName,
    required this.region,
    required this.contactName,
    required this.contactPhone,
    required this.readinessStatus,
    required this.onDutyCount,
    required this.delayedCount,
    required this.minimumCrewRequired,
    required this.minimumCrewMet,
    required this.primaryVesselStatus,
    required this.equipmentStatus,
    required this.criticalIssues,
    required this.lastUpdatedBy,
    this.lastUpdatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String organizationName;
  final String region;
  final String contactName;
  final String contactPhone;
  final String readinessStatus;
  final int onDutyCount;
  final int delayedCount;
  final int minimumCrewRequired;
  final bool minimumCrewMet;
  final String primaryVesselStatus;
  final String equipmentStatus;
  final String criticalIssues;
  final String lastUpdatedBy;
  final DateTime? lastUpdatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PlatformReadinessSummary.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return PlatformReadinessSummary(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      organizationName: _stringValue(data['organizationName']),
      region: _stringValue(data['region']),
      contactName: _stringValue(data['contactName']),
      contactPhone: _stringValue(data['contactPhone']),
      readinessStatus: _stringValue(
        data['readinessStatus'],
        fallback: ReadinessStatus.unknown,
      ),
      onDutyCount: _intValue(data['onDutyCount']),
      delayedCount: _intValue(data['delayedCount']),
      minimumCrewRequired: _intValue(data['minimumCrewRequired']),
      minimumCrewMet: data['minimumCrewMet'] == true,
      primaryVesselStatus: _stringValue(
        data['primaryVesselStatus'],
        fallback: ReadinessEquipmentStatus.unknown,
      ),
      equipmentStatus: _stringValue(
        data['equipmentStatus'],
        fallback: ReadinessEquipmentStatus.unknown,
      ),
      criticalIssues: _stringValue(data['criticalIssues']),
      lastUpdatedBy: _stringValue(data['lastUpdatedBy']),
      lastUpdatedAt: _dateTimeValue(data['lastUpdatedAt']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'commandId': commandId,
      'organizationName': organizationName,
      'region': region,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'readinessStatus': readinessStatus,
      'onDutyCount': onDutyCount,
      'delayedCount': delayedCount,
      'minimumCrewRequired': minimumCrewRequired,
      'minimumCrewMet': minimumCrewMet,
      'primaryVesselStatus': primaryVesselStatus,
      'equipmentStatus': equipmentStatus,
      'criticalIssues': criticalIssues,
      'lastUpdatedBy': lastUpdatedBy,
      'lastUpdatedAt':
          lastUpdatedAt == null ? null : Timestamp.fromDate(lastUpdatedAt!),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
