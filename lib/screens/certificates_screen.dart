import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/certificate_model.dart';
import '../services/certificate_service.dart';
import '../services/membership_service.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageCertificates,
  });

  final String organizationId;
  final String currentUid;
  final bool canManageCertificates;

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final _certificateService = CertificateService();
  final _membershipService = MembershipService();

  @override
  void initState() {
    super.initState();
    if (widget.canManageCertificates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkExpiryNotifications();
      });
    }
  }

  Future<void> _checkExpiryNotifications() async {
    try {
      await _certificateService.checkExpiryNotifications(
        organizationId: widget.organizationId,
        createdBy: widget.currentUid,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sertifikaatide aegumise kontroll ebaõnnestus: $e'),
        ),
      );
    }
  }

  Future<void> _showAddCertificateDialog() async {
    if (widget.organizationId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tunnistust ei saa lisada ilma aktiivse ühinguta.'),
        ),
      );
      return;
    }

    final members = await _loadMemberOptions();
    if (!mounted) return;

    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liikmeid ei leitud')),
      );
      return;
    }

    final titleController = TextEditingController();
    final issuerController = TextEditingController();
    final issuedAtController = TextEditingController();
    final expiresAtController = TextEditingController();
    final noteController = TextEditingController();
    var selectedMember = members.first;
    var selectedType = CertificateType.other;
    var selectedStatus = CertificateStatus.valid;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Lisa kvalifikatsioon'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<_MemberOption>(
                    initialValue: selectedMember,
                    decoration: const InputDecoration(
                      labelText: 'Liige',
                    ),
                    items: members.map((member) {
                      return DropdownMenuItem<_MemberOption>(
                        value: member,
                        child: Text(member.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedMember = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nimetus',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tüüp',
                    ),
                    items: CertificateType.values.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(_certificateTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: issuerController,
                    decoration: const InputDecoration(
                      labelText: 'Väljastaja',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: issuedAtController,
                    decoration: const InputDecoration(
                      labelText: 'Väljastatud',
                      hintText: 'nt 2026-05-20',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: expiresAtController,
                    decoration: const InputDecoration(
                      labelText: 'Kehtib kuni',
                      hintText: 'nt 2027-05-20',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Staatus',
                    ),
                    items: CertificateStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_certificateStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Märkus',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Katkesta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lisa'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true) return;
    if (!mounted) return;

    final title = titleController.text.trim();
    final expiresAt = expiresAtController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nimetus on kohustuslik.')),
      );
      return;
    }

    if (expiresAt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aegumiskuupäev on kohustuslik.')),
      );
      return;
    }

    try {
      await _certificateService.addCertificate(
        organizationId: widget.organizationId,
        userId: selectedMember.uid,
        userName: selectedMember.name,
        title: title,
        type: selectedType,
        issuer: issuerController.text,
        issuedAt: issuedAtController.text,
        expiresAt: expiresAt,
        status: selectedStatus,
        note: noteController.text,
        createdBy: widget.currentUid,
      );
      await _checkExpiryNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tunnistus lisatud.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kvalifikatsiooni lisamine ebaõnnestus: $e')),
      );
    }
  }

  Future<List<_MemberOption>> _loadMemberOptions() async {
    final membershipDocs = await _membershipService
        .loadActiveMembershipsForOrganization(widget.organizationId);
    final members = <_MemberOption>[];

    for (final membershipDoc in membershipDocs) {
      final membership = membershipDoc.data();
      final uid = (membership['userId'] ?? '').toString();
      if (uid.isEmpty) continue;

      final userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userSnapshot.data() ?? <String, dynamic>{};
      final name = (userData['name'] ?? '').toString();
      final email = (userData['email'] ?? '').toString();

      members.add(
        _MemberOption(
          uid: uid,
          name: name.isNotEmpty ? name : (email.isNotEmpty ? email : uid),
        ),
      );
    }

    members.sort((a, b) => a.name.compareTo(b.name));
    return members;
  }

  @override
  Widget build(BuildContext context) {
    final certificateStream = widget.canManageCertificates
        ? _certificateService.streamOrganizationCertificates(
            organizationId: widget.organizationId,
          )
        : _certificateService.streamMyCertificates(
            organizationId: widget.organizationId,
            userId: widget.currentUid,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvalifikatsioonid'),
      ),
      floatingActionButton: widget.canManageCertificates
          ? FloatingActionButton(
              onPressed: _showAddCertificateDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<CertificateModel>>(
        stream: certificateStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Kvalifikatsioonide laadimine ebaõnnestus: '
                '${snapshot.error}',
              ),
            );
          }

          final certificates = snapshot.data ?? const <CertificateModel>[];
          if (certificates.isEmpty) {
            return const Center(child: Text('Kvalifikatsioone ei ole lisatud'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: certificates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final certificate = certificates[index];
              final displayStatus = _certificateDisplayStatus(certificate);
              final subtitleParts = [
                _certificateTypeLabel(certificate.type),
                _certificateStatusLabel(displayStatus),
                if (certificate.issuer.isNotEmpty) certificate.issuer,
                if (certificate.expiresAt.isNotEmpty)
                  'Kehtib kuni ${certificate.expiresAt}',
              ];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(certificate.title),
                subtitle: Text(
                  widget.canManageCertificates
                      ? '${certificate.userName}\n${subtitleParts.join(' - ')}'
                      : subtitleParts.join(' - '),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _certificateTypeLabel(String type) {
    switch (type) {
      case CertificateType.firstAid:
        return 'First aid';
      case CertificateType.seaRescue:
        return 'Sea rescue';
      case CertificateType.radio:
        return 'Radio';
      case CertificateType.navigation:
        return 'Navigation';
      case CertificateType.boatOperator:
        return 'Boat operator';
      case CertificateType.safety:
        return 'Safety';
      default:
        return 'Other';
    }
  }

  String _certificateStatusLabel(String status) {
    switch (status) {
      case CertificateStatus.expiringSoon:
        return 'Aegub varsti';
      case CertificateStatus.expired:
        return 'Aegunud';
      case CertificateStatus.missing:
        return 'Puudub';
      default:
        return 'Kehtiv';
    }
  }

  String _certificateDisplayStatus(CertificateModel certificate) {
    final parsedExpiry = DateTime.tryParse(certificate.expiresAt.trim());
    if (parsedExpiry == null) return certificate.status;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(
      parsedExpiry.year,
      parsedExpiry.month,
      parsedExpiry.day,
    );
    if (expiryDate.isBefore(today)) return CertificateStatus.expired;
    if (!expiryDate.isAfter(today.add(const Duration(days: 30)))) {
      return CertificateStatus.expiringSoon;
    }
    return certificate.status;
  }
}

class _MemberOption {
  const _MemberOption({
    required this.uid,
    required this.name,
  });

  final String uid;
  final String name;
}
