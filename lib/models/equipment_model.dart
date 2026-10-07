import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentStatus {
  static const ok = 'ok';
  static const needsMaintenance = 'needsMaintenance';
  static const broken = 'broken';
  static const outOfService = 'outOfService';

  static const values = {ok, needsMaintenance, broken, outOfService};
  static String label(String status) => switch (status) {
    ok => 'Korras',
    needsMaintenance => 'Vajab hooldust',
    broken => 'Katki / vajab remonti',
    outOfService => 'Hoolduses / kasutusest väljas',
    _ => 'Olek teadmata',
  };
}

class EquipmentCategory {
  static const vessel = 'vessel',
      engine = 'engine',
      trailer = 'trailer',
      vehicle = 'vehicle',
      machinery = 'machinery';
  static const rescue = 'rescue',
      medical = 'medical',
      radio = 'radio',
      safety = 'safety',
      other = 'other';
  static const values = {
    vessel,
    engine,
    trailer,
    vehicle,
    machinery,
    rescue,
    safety,
    medical,
    radio,
    other,
  };
  static String normalize(Object? value) =>
      values.contains(value) ? value as String : other;
  // Operational reports keep their existing technique grouping. Inventory also
  // treats shared communications equipment as technique.
  static bool isInventoryTechnique(Object? value) =>
      isTechnique(value) || value == radio;
  static bool isTechnique(Object? value) =>
      {vessel, engine, trailer, vehicle, machinery}.contains(value);
  static String label(String value) => switch (normalize(value)) {
    vessel => 'Alus',
    engine => 'Mootor',
    trailer => 'Haagis',
    vehicle => 'Sõiduk',
    machinery => 'Muu tehnika',
    rescue => 'Päästevarustus',
    safety => 'Isikukaitsevarustus',
    medical => 'Meditsiinivarustus',
    radio => 'Side- ja navigatsioonivarustus',
    _ => 'Muu',
  };
  static String group(Object? value) => switch (normalize(value)) {
    vessel ||
    engine ||
    trailer ||
    vehicle ||
    machinery => 'Kasutatud alused ja tehnika',
    rescue => 'Päästevarustus',
    safety => 'Isikukaitsevarustus',
    medical => 'Meditsiinivarustus',
    radio => 'Side- ja navigatsioonivarustus',
    _ => 'Muu varustus',
  };
  static Map<String, List<Map<String, dynamic>>> groupEquipment(
    Iterable<Map<String, dynamic>> items,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final category in values) {
      final title = group(category);
      final rows = items
          .where((item) => group(item['category']) == title)
          .toList();
      if (rows.isNotEmpty) groups[title] = rows;
    }
    return groups;
  }
}

class EquipmentScope {
  static const organization = 'organization';
  static const personal = 'personal';

  static const values = {organization, personal};
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
    this.storage = 'shared',
    this.assignedToUserId = '',
    this.assignedToName = '',
    this.issuedAt,
    this.issuedBy = '',
    this.returnedAt,
    this.returnedBy = '',
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
  final String storage;
  final String assignedToUserId;
  final String assignedToName;
  final DateTime? issuedAt;
  final String issuedBy;
  final DateTime? returnedAt;
  final String returnedBy;
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
      scope: _stringValue(data['scope'], fallback: EquipmentScope.organization),
      ownerUserId: _stringValue(data['ownerUserId']),
      name: _stringValue(data['name']),
      category: EquipmentCategory.normalize(data['category']),
      status: _stringValue(data['status'], fallback: EquipmentStatus.ok),
      location: _stringValue(data['location']),
      nextMaintenanceDate: _stringValue(data['nextMaintenanceDate']),
      note: _stringValue(data['note']),
      createdBy: _stringValue(data['createdBy']),
      storage: _stringValue(data['storage'], fallback: 'shared'),
      assignedToUserId: _stringValue(data['assignedToUserId']),
      assignedToName: _stringValue(data['assignedToName']),
      issuedAt: _dateTimeValue(data['issuedAt']),
      issuedBy: _stringValue(data['issuedBy']),
      returnedAt: _dateTimeValue(data['returnedAt']),
      returnedBy: _stringValue(data['returnedBy']),
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
      'storage': storage,
      'assignedToUserId': assignedToUserId,
      'assignedToName': assignedToName,
      'issuedAt': issuedAt == null ? null : Timestamp.fromDate(issuedAt!),
      'issuedBy': issuedBy,
      'returnedAt': returnedAt == null ? null : Timestamp.fromDate(returnedAt!),
      'returnedBy': returnedBy,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  bool appearsIn(String view, String uid) => switch (view) {
    'technique' =>
      !isPersonal &&
          !isAssigned &&
          storage != 'warehouse' &&
          EquipmentCategory.isInventoryTechnique(category),
    'supplies' =>
      !isPersonal &&
          !isAssigned &&
          storage != 'warehouse' &&
          !EquipmentCategory.isInventoryTechnique(category),
    'warehouse' => !isPersonal && !isAssigned && storage == 'warehouse',
    'mine' => assignedToUserId == uid || (isPersonal && ownerUserId == uid),
    'members' => !isPersonal && isAssigned,
    _ => !isPersonal && !isAssigned && storage != 'warehouse',
  };

  bool get isPersonal => scope == EquipmentScope.personal;

  bool get isAssigned => assignedToUserId.isNotEmpty;
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
