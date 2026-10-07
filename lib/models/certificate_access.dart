import 'certificate_model.dart';

/// Presentation policy; Firestore independently enforces the same scope.
class CertificateAccess {
  const CertificateAccess({
    required this.organizationId,
    required this.currentUid,
    required this.targetUid,
    required this.organizationAdmin,
  });

  final String organizationId, currentUid, targetUid;
  final bool organizationAdmin;

  bool get canAdd =>
      organizationId.isNotEmpty &&
      currentUid.isNotEmpty &&
      targetUid.isNotEmpty &&
      (organizationAdmin || currentUid == targetUid);

  bool canEdit(CertificateModel certificate) =>
      canAdd &&
      certificate.organizationId == organizationId &&
      certificate.userId == targetUid &&
      (organizationAdmin || certificate.createdBy == currentUid);
}
