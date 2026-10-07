import '../widgets/certificate_editor.dart';
import '../widgets/app_date_field.dart';
import '../widgets/app_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/certificate_model.dart';
import '../models/certificate_access.dart';
import '../services/certificate_service.dart';
import '../services/membership_service.dart';

const _unknownCertificateExpiryStatus = 'unknownExpiry';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageCertificates,
    this.targetUserId,
  });

  final String organizationId;
  final String currentUid;
  final bool canManageCertificates;
  final String? targetUserId;

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final _certificateService = CertificateService();
  final _membershipService = MembershipService();

  CertificateAccess get _access => CertificateAccess(
    organizationId: widget.organizationId,
    currentUid: widget.currentUid,
    targetUid: widget.targetUserId ?? widget.currentUid,
    organizationAdmin: widget.canManageCertificates,
  );

  Future<void> _showAddCertificateDialog([CertificateModel? existing]) async {
    if (!_access.canAdd || (existing != null && !_access.canEdit(existing))) {
      return;
    }
    if (widget.organizationId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tunnistust ei saa lisada ilma aktiivse ühinguta.'),
        ),
      );
      return;
    }

    List<_MemberOption> members;
    try {
      members = await _loadMemberOptions();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Liikme andmeid ei saanud laadida. Proovi uuesti.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    if (members.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Liikmeid ei leitud.')));
      return;
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CertificateEditor(
        existing: existing,
        save: (draft) => _certificateService.addCertificate(
          certificateId: existing?.id,
          organizationId: widget.organizationId,
          userId: existing?.userId ?? members.first.uid,
          userName: existing?.userName ?? members.first.name,
          title: draft.title,
          type: draft.type,
          issuer: draft.issuer,
          issuedAt: draft.issuedAt,
          expiresAt: draft.expiresAt,
          status: draft.status,
          note: draft.note,
          number: draft.number,
          noExpiry: draft.noExpiry,
          createdBy: widget.currentUid,
        ),
      ),
    );
  }

  Future<List<_MemberOption>> _loadMemberOptions() async {
    final uid = widget.targetUserId ?? widget.currentUid;
    final membership =
        (await FirebaseFirestore.instance
                .collection('memberships')
                .doc('${uid}_${widget.organizationId}')
                .get())
            .data();
    if (membership == null ||
        !_membershipService.isActiveMembership(membership) ||
        _membershipService.organizationIdFromMembership(membership) !=
            widget.organizationId) {
      return [];
    }
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userSnapshot.data() ?? <String, dynamic>{};
    final name = (userData['name'] ?? '').toString();
    final email = (userData['email'] ?? '').toString();

    return [
      _MemberOption(
        uid: uid,
        name: name.isNotEmpty ? name : (email.isNotEmpty ? email : uid),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final certificateStream = _certificateService.streamMyCertificates(
      organizationId: widget.organizationId,
      userId: widget.targetUserId ?? widget.currentUid,
    );

    return AppScaffold(
      appBar: AppBar(title: const Text('Tunnistused')),
      floatingActionButton: _access.canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _showAddCertificateDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Lisa tunnistus'),
            )
          : null,
      body: StreamBuilder<List<CertificateModel>>(
        stream: certificateStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Tunnistuste laadimine ebaõnnestus.'),
            );
          }

          final certificates = snapshot.data ?? const <CertificateModel>[];
          if (certificates.isEmpty) {
            return const Center(child: Text('Tunnistusi ei ole lisatud.'));
          }

          final attentionCertificates = certificates
              .where(_certificateNeedsAttention)
              .toList(growable: false);
          // Show each certificate once, with actionable expiries first.
          final ordered = [
            ...attentionCertificates,
            ...certificates.where((c) => !_certificateNeedsAttention(c)),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.canManageCertificates)
                Text(
                  'Merepäästja aste määratakse liikme profiilis eraldi.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              Text(
                attentionCertificates.isEmpty
                    ? '${certificates.length} tunnistust'
                    : '${attentionCertificates.length} tunnistust vajab tähelepanu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < ordered.length; index++) ...[
                _buildCertificateTile(ordered[index]),
                if (index < ordered.length - 1) const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCertificateTile(CertificateModel certificate) {
    final displayStatus = _certificateDisplayStatus(certificate);
    final subtitleParts = [
      _certificateTypeLabel(certificate.type),
      _certificateStatusLabel(displayStatus),
      if (certificate.issuer.isNotEmpty) certificate.issuer,
      if (displayStatus != _unknownCertificateExpiryStatus)
        _certificateExpiryText(certificate),
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(certificate.title),
      trailing: _access.canEdit(certificate)
          ? IconButton(
              tooltip: 'Muuda tunnistust',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showAddCertificateDialog(certificate),
            )
          : null,
      subtitle: Text(
        widget.canManageCertificates
            ? '${certificate.userName}\n${subtitleParts.join(' - ')}'
            : subtitleParts.join(' - '),
      ),
    );
  }

  String _certificateTypeLabel(String type) {
    switch (type) {
      case CertificateType.firstAid:
        return 'Esmaabi';
      case CertificateType.seaRescue:
        return 'Merepääste';
      case CertificateType.radio:
        return 'Raadioside';
      case CertificateType.navigation:
        return 'Navigatsioon';
      case CertificateType.boatOperator:
        return 'Väikelaevajuht';
      case CertificateType.safety:
        return 'Ohutus';
      case 'medical':
        return 'Meditsiin';
      default:
        return 'Muu';
    }
  }

  String _certificateStatusLabel(String status) {
    switch (status) {
      case CertificateStatus.expiringSoon:
        return 'Aegumas';
      case CertificateStatus.expired:
        return 'Aegunud';
      case _unknownCertificateExpiryStatus:
        return 'Aegumiskuupäev teadmata';
      case CertificateStatus.missing:
        return 'Puudub';
      default:
        return 'Kehtiv';
    }
  }

  bool _certificateNeedsAttention(CertificateModel certificate) {
    final displayStatus = _certificateDisplayStatus(certificate);
    return displayStatus == CertificateStatus.expired ||
        displayStatus == CertificateStatus.expiringSoon ||
        displayStatus == _unknownCertificateExpiryStatus;
  }

  String _certificateExpiryText(CertificateModel certificate) {
    if (certificate.noExpiry) return 'Tähtajatu';
    final expiresAt = certificate.expiresAt.trim();
    final parsedExpiry = parseCalendarDate(expiresAt);
    if (expiresAt.isEmpty || parsedExpiry == null) {
      return 'Aegumiskuupäev teadmata';
    }

    return 'Kehtib kuni ${calendarDateLabel(parsedExpiry)}';
  }

  String _certificateDisplayStatus(CertificateModel certificate) =>
      certificate.displayStatusAt(DateTime.now());
}

class _MemberOption {
  const _MemberOption({required this.uid, required this.name});

  final String uid;
  final String name;
}
