import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/certificate_access.dart';
import 'package:respondcrew_app/models/certificate_model.dart';

CertificateModel certificate({
  String owner = 'member',
  String author = 'member',
  String org = 'org',
}) => CertificateModel(
  id: 'certificate',
  organizationId: org,
  commandId: org,
  userId: owner,
  userName: 'Member',
  title: 'Raadioside',
  type: CertificateType.radio,
  issuer: 'Issuer',
  issuedAt: '2026-01-01',
  expiresAt: '2028-01-01',
  status: CertificateStatus.valid,
  note: '',
  createdBy: author,
);

void main() {
  const own = CertificateAccess(
    organizationId: 'org',
    currentUid: 'member',
    targetUid: 'member',
    organizationAdmin: false,
  );
  test('member can add and maintain self-entered certificates', () {
    expect(own.canAdd, isTrue);
    expect(own.canEdit(certificate()), isTrue);
    expect(own.canEdit(certificate(author: 'admin')), isFalse);
  });
  test('ownership alone does not cross organization or profile boundaries', () {
    expect(own.canEdit(certificate(org: 'other-org')), isFalse);
    expect(own.canEdit(certificate(owner: 'peer')), isFalse);
    const peer = CertificateAccess(
      organizationId: 'org',
      currentUid: 'member',
      targetUid: 'peer',
      organizationAdmin: false,
    );
    expect(peer.canAdd, isFalse);
    expect(peer.canEdit(certificate(owner: 'peer')), isFalse);
  });
  test(
    'organization admin can maintain member records only in current scope',
    () {
      const admin = CertificateAccess(
        organizationId: 'org',
        currentUid: 'admin',
        targetUid: 'member',
        organizationAdmin: true,
      );
      expect(admin.canAdd, isTrue);
      expect(admin.canEdit(certificate()), isTrue);
      expect(admin.canEdit(certificate(author: 'admin')), isTrue);
      expect(admin.canEdit(certificate(org: 'other-org')), isFalse);
      expect(admin.canEdit(certificate(owner: 'peer')), isFalse);
    },
  );
  test('missing identity or organization cannot expose a write action', () {
    for (final access in [
      const CertificateAccess(
        organizationId: '',
        currentUid: 'member',
        targetUid: 'member',
        organizationAdmin: false,
      ),
      const CertificateAccess(
        organizationId: 'org',
        currentUid: '',
        targetUid: '',
        organizationAdmin: false,
      ),
      const CertificateAccess(
        organizationId: 'org',
        currentUid: 'admin',
        targetUid: '',
        organizationAdmin: true,
      ),
    ]) {
      expect(access.canAdd, isFalse);
      expect(access.canEdit(certificate()), isFalse);
    }
  });
}
