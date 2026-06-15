import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentStatus {
  static const ok = 'ok';
  static const needsMaintenance = 'needsMaintenance';
  static const broken = 'broken';
  static const outOfService = 'outOfService';

  static const values = {
    ok,
    needsMaintenance,
    broken,
    outOfService,
  };
}

class EquipmentCategory {
  static const vessel = 'vessel';
  static const engine = 'engine';
  static const rescue = 'rescue';
  static const medical = 'medical';
  static const radio = 'radio';
  static const safety = 'safety';
  static const other = 'other';

  static const values = {
    vessel,
    engine,
    rescue,
    medical,
    radio,
    safety,
    other,
  };
}

class EquipmentScope {
  static const organization = 'organization';
  static const personal = 'personal';

  static const values = {
    organization,
    personal,
  };
}

class EquipmentModel {
  const EquipmentModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.scope,
    required this.ownerUserId,
    required this.name,
    required this.category,
    required this.status,
    required this.location,
    required this.nextMaintenanceDate,
    required this.note,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String scope;
  final String ownerUserId;
  final String name;
  final String category;
  final String status;
  final String location;
  final String nextMaintenanceDate;
  final String note;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory EquipmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return EquipmentModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      scope: _stringValue(
        data['scope'],
        fallback: EquipmentScope.organization,
      ),
      ownerUserId: _stringValue(data['ownerUserId']),
      name: _stringValue(data['name']),
      category: _stringValue(
        data['category'],
        fallback: EquipmentCategory.other,
      ),
      status: _stringValue(
        data['status'],
        fallback: EquipmentStatus.ok,
      ),
      location: _stringValue(data['location']),
      nextMaintenanceDate: _stringValue(data['nextMaintenanceDate']),
      note: _stringValue(data['note']),
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
      'scope': scope,
      'ownerUserId': ownerUserId,
      'name': name,
      'category': category,
      'status': status,
      'location': location,
      'nextMaintenanceDate': nextMaintenanceDate,
      'note': note,
      'createdBy': createdBy,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  bool get isPersonal => scope == EquipmentScope.personal;
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
