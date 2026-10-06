import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/certificate_model.dart';
import '../models/calendar_date.dart';

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _certificates =>
      _firestore.collection('certificates');

  Stream<List<CertificateModel>> streamOrganizationCertificates({
    required String organizationId,
  }) {
    _requireOrganizationId(organizationId);
    return _certificates
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after certificate migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
          final certificates = snapshot.docs
              .map(CertificateModel.fromFirestore)
              .where((c) => !c.archived)
              .toList();

          certificates.sort((a, b) {
            final userCompare = a.userName.compareTo(b.userName);
            if (userCompare != 0) return userCompare;
            return a.title.compareTo(b.title);
          });

          return certificates;
        });
  }

  Stream<List<CertificateModel>> streamMyCertificates({
    required String organizationId,
    required String userId,
  }) {
    _requireOrganizationId(organizationId);
    return _certificates
        .where('userId', isEqualTo: userId)
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after certificate migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .snapshots()
        .map((snapshot) {
          final certificates = snapshot.docs
              .map(CertificateModel.fromFirestore)
              .where((c) => !c.archived)
              .toList();

          certificates.sort((a, b) => a.title.compareTo(b.title));
          return certificates;
        });
  }

  Future<void> addCertificate({
    required String organizationId,
    required String userId,
    required String userName,
    required String title,
    required String type,
    required String issuer,
    required String issuedAt,
    required String expiresAt,
    required String status,
    required String note,
    required String createdBy,
    String? certificateId,
    String number = '',
    bool noExpiry = false,
  }) async {
    _requireOrganizationId(
      organizationId,
      message: 'Tunnistust ei saa lisada ilma aktiivse ühinguta.',
    );
    if (title.trim().isEmpty) {
      throw Exception('Nimetus on kohustuslik.');
    }

    if (!noExpiry && expiresAt.trim().isEmpty) {
      throw Exception('Aegumiskuupäev on kohustuslik.');
    }

    if (!CertificateType.values.contains(type)) {
      throw Exception('Unsupported certificate type: $type');
    }

    if (!CertificateStatus.values.contains(status)) {
      throw Exception('Unsupported certificate status: $status');
    }

    final issued = parseCalendarDate(issuedAt);
    final parsed = parseCalendarDate(expiresAt);
    if (issued == null ||
        (!noExpiry && (parsed == null || parsed.isBefore(issued)))) {
      throw Exception('Vali kehtivad väljastamise ja aegumise kuupäevad.');
    }
    final doc = certificateId == null
        ? _certificates.doc()
        : _certificates.doc(certificateId);

    final data = <String, dynamic>{
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all certificate reads use organizationId.
      'commandId': organizationId,
      'userId': userId,
      'userName': userName.trim(),
      'title': title.trim(),
      'type': type,
      'issuer': issuer.trim(),
      'issuedAt': calendarDateIso(issued),
      'expiresAt': noExpiry ? '' : calendarDateIso(parsed!),
      'number': number.trim(),
      'noExpiry': noExpiry,
      'status': status,
      'note': note.trim(),
      if (certificateId == null) 'createdBy': createdBy,
      if (certificateId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (certificateId == null) {
      await doc.set(data);
    } else {
      await doc.update(data);
    }
  }

  Future<void> archiveCertificate(String id) => _certificates.doc(id).update({
    'archived': true,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  void _requireOrganizationId(
    String organizationId, {
    String message = 'Selle toimingu jaoks puudub aktiivne organisatsioon',
  }) {
    if (organizationId.trim().isEmpty) {
      throw Exception(message);
    }
  }
}
