import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/certificate_model.dart';

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _certificates =>
      _firestore.collection('certificates');

  Stream<List<CertificateModel>> streamOrganizationCertificates({
    required String organizationId,
  }) {
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
      final certificates =
          snapshot.docs.map(CertificateModel.fromFirestore).toList();

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
      final certificates =
          snapshot.docs.map(CertificateModel.fromFirestore).toList();

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
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('Certificate title is required');
    }

    if (!CertificateType.values.contains(type)) {
      throw Exception('Unsupported certificate type: $type');
    }

    if (!CertificateStatus.values.contains(status)) {
      throw Exception('Unsupported certificate status: $status');
    }

    final doc = _certificates.doc();

    await doc.set({
      'id': doc.id,
      'organizationId': organizationId,
      // TODO: Remove commandId after all certificate reads use organizationId.
      'commandId': organizationId,
      'userId': userId,
      'userName': userName.trim(),
      'title': title.trim(),
      'type': type,
      'issuer': issuer.trim(),
      'issuedAt': issuedAt.trim(),
      'expiresAt': expiresAt.trim(),
      'status': status,
      'note': note.trim(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
