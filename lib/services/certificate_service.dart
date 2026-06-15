import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/certificate_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

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
    _requireOrganizationId(organizationId);
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

  Future<void> checkExpiryNotifications({
    required String organizationId,
    required String createdBy,
  }) async {
    _requireOrganizationId(organizationId);
    final snapshot = await _certificates
        .where(
          Filter.or(
            Filter('organizationId', isEqualTo: organizationId),
            // TODO: Remove commandId fallback after certificate migration.
            Filter('commandId', isEqualTo: organizationId),
          ),
        )
        .get();
    final today = _dateOnly(DateTime.now());
    final warningLimit = today.add(const Duration(days: 30));

    for (final document in snapshot.docs) {
      final certificate = CertificateModel.fromFirestore(document);
      final certificateOrganizationId = certificate.organizationId.isNotEmpty
          ? certificate.organizationId
          : certificate.commandId;
      if (certificateOrganizationId != organizationId) continue;

      final parsedExpiry = DateTime.tryParse(certificate.expiresAt.trim());
      if (parsedExpiry == null) continue;

      final expiryDate = _dateOnly(parsedExpiry);
      final isExpired = expiryDate.isBefore(today);
      final isExpiringSoon =
          !isExpired && !expiryDate.isAfter(warningLimit);
      if (!isExpired && !isExpiringSoon) continue;

      final memberName =
          certificate.userName.trim().isEmpty ? 'Liige' : certificate.userName;
      final certificateTitle = certificate.title.trim().isEmpty
          ? 'sertifikaat'
          : certificate.title;
      final expiryState = isExpired ? 'expired' : 'expiringSoon';

      await _notificationService.addNotification(
        organizationId: organizationId,
        title: isExpired ? 'Sertifikaat aegunud' : 'Sertifikaat aegub',
        message: isExpired
            ? '$memberName sertifikaat „$certificateTitle” on aegunud.'
            : '$memberName sertifikaat „$certificateTitle” aegub varsti.',
        type: NotificationType.certificate,
        priority: isExpired
            ? NotificationPriority.high
            : NotificationPriority.normal,
        createdBy: createdBy,
        relatedType: NotificationType.certificate,
        relatedId: certificate.id,
        notificationId: 'certificate_${certificate.id}_$expiryState',
        createOnlyIfMissing: true,
      );
    }
  }

  void _requireOrganizationId(String organizationId) {
    if (organizationId.trim().isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
    }
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
