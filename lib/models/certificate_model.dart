import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_date.dart';

class CertificateType {
  static const firstAid = 'firstAid';
  static const seaRescue = 'seaRescue';
  static const radio = 'radio';
  static const navigation = 'navigation';
  static const boatOperator = 'boatOperator';
  static const safety = 'safety';
  static const other = 'other';

  static const values = {
    firstAid,
    seaRescue,
    radio,
    navigation,
    boatOperator,
    safety,
    other,
  };
}

class CertificateStatus {
  static const valid = 'valid';
  static const expiringSoon = 'expiringSoon';
  static const expired = 'expired';
  static const missing = 'missing';

  static const values = {valid, expiringSoon, expired, missing};
}

class CertificateModel {
  const CertificateModel({
    required this.id,
    required this.organizationId,
    required this.commandId,
    required this.userId,
    required this.userName,
    required this.title,
    required this.type,
    required this.issuer,
    required this.issuedAt,
    required this.expiresAt,
    required this.status,
    required this.note,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.number = '',
    this.noExpiry = false,
    this.archived = false,
  });

  final String id;
  final String organizationId;
  final String commandId;
  final String userId;
  final String userName;
  final String title;
  final String type;
  final String issuer;
  final String issuedAt;
  final String expiresAt;
  final String status;
  final String note;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String number;
  final bool noExpiry, archived;

  String displayStatusAt(DateTime now) {
    if (status == CertificateStatus.missing) return status;
    if (noExpiry) return CertificateStatus.valid;
    final expiry = parseCalendarDate(expiresAt);
    if (expiry == null) return 'unknownExpiry';
    final today = DateTime(now.year, now.month, now.day);
    if (expiry.isBefore(today)) return CertificateStatus.expired;
    if (!expiry.isAfter(DateTime(today.year, today.month, today.day + 30))) {
      return CertificateStatus.expiringSoon;
    }
    return CertificateStatus.valid;
  }

  String get validityLabel => switch (displayStatusAt(DateTime.now())) {
    CertificateStatus.missing => 'Puudub',
    CertificateStatus.expired => 'Aegunud',
    CertificateStatus.expiringSoon => 'Aegumas',
    'unknownExpiry' => 'Kehtivusaeg teadmata',
    _ => noExpiry ? 'Tähtajatu' : 'Kehtiv',
  };

  factory CertificateModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return CertificateModel(
      id: document.id,
      organizationId: _stringValue(data['organizationId']),
      commandId: _stringValue(data['commandId']),
      userId: _stringValue(data['userId']),
      userName: _stringValue(data['userName']),
      title: _stringValue(data['title']),
      type: _stringValue(data['type'], fallback: CertificateType.other),
      issuer: _stringValue(data['issuer']),
      issuedAt: _stringValue(data['issuedAt']),
      expiresAt: _stringValue(data['expiresAt']),
      status: _stringValue(data['status'], fallback: CertificateStatus.valid),
      note: _stringValue(data['note']),
      createdBy: _stringValue(data['createdBy']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
      number: _stringValue(data['number']),
      noExpiry: data['noExpiry'] == true,
      archived: data['archived'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'commandId': commandId,
      'userId': userId,
      'userName': userName,
      'title': title,
      'type': type,
      'issuer': issuer,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'status': status,
      'note': note,
      'number': number,
      'noExpiry': noExpiry,
      'archived': archived,
      'createdBy': createdBy,
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
