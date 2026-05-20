import 'package:cloud_firestore/cloud_firestore.dart';

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

  static const values = {
    valid,
    expiringSoon,
    expired,
    missing,
  };
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
