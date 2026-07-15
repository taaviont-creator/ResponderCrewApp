import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/availability_model.dart';
import '../models/certificate_model.dart';
import '../models/equipment_model.dart';
import '../models/membership_model.dart';
import '../services/availability_service.dart';
import '../services/certificate_service.dart';
import '../services/equipment_service.dart';
import '../services/membership_service.dart';
import '../services/user_service.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.userData,
    required this.membershipData,
    required this.membershipId,
    required this.organizationId,
    required this.currentUid,
    required this.canManageRoles,
  });

  final Map<String, dynamic> userData;
  final Map<String, dynamic> membershipData;
  final String membershipId;
  final String organizationId;
  final String currentUid;
  final bool canManageRoles;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final _availabilityService = AvailabilityService();
  final _certificateService = CertificateService();
  final _equipmentService = EquipmentService();
  final _membershipService = MembershipService();
  final _userService = UserService();

  late String _name;
  late String? _phone;
  late String _membershipRole;
  late String _seaRescueLevel;

  @override
  void initState() {
    super.initState();
    _name = _stringValue(widget.userData['name'], 'Nimi puudub');
    _phone = _optionalString(widget.userData['phone']);
    _membershipRole = MembershipRole.normalize(widget.membershipData['role']);
    _seaRescueLevel = SeaRescueLevel.normalize(
      widget.membershipData['seaRescueLevel'],
    );
  }

  String _stringValue(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String get _targetUid => _stringValue(widget.membershipData['userId'], '');

  bool get _isOwnProfile =>
      _targetUid.isNotEmpty && _targetUid == widget.currentUid;

  bool get _canManageProfileMembership {
    if (!widget.canManageRoles) return false;
    if (widget.currentUid.trim().isEmpty) return false;
    if (_targetUid.isEmpty) return false;

    final membershipOrganizationId =
        _membershipService.organizationIdFromMembership(widget.membershipData);
    return membershipOrganizationId == widget.organizationId;
  }

  bool get _canEditRole => _canManageProfileMembership && !_isOwnProfile;

  Future<void> _openPhoneDialer(BuildContext context, String phone) async {
    final phoneUri = Uri(scheme: 'tel', path: phone);
    final messenger = ScaffoldMessenger.of(context);

    if (!await canLaunchUrl(phoneUri)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Helistamist ei saanud avada.')),
      );
      return;
    }

    final opened = await launchUrl(
      phoneUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Helistamist ei saanud avada.')),
      );
    }
  }

  String _roleLabel(Object? role) {
    if (MembershipRole.isOrgAdmin(role)) {
      return 'Organisatsiooni administraator';
    }
    if (MembershipRole.isMember(role)) {
      return 'Liige';
    }
    return 'Roll puudub';
  }

  String _seaRescueLevelLabel(Object? level) {
    switch (SeaRescueLevel.normalize(level)) {
      case SeaRescueLevel.level1:
        return 'I aste';
      case SeaRescueLevel.level2:
        return 'II aste';
      default:
        return 'Määramata';
    }
  }

  String _membershipStatusLabel(Map<String, dynamic> membership) {
    final status = _stringValue(membership['status'], '');
    if (status == 'active') return 'Aktiivne';
    if (status == 'pending') return 'Ootel';
    if (status == 'removed') return 'Eemaldatud';
    if (status == 'rejected') return 'Tagasi lükatud';
    if (status.isNotEmpty) return status;

    if (membership['isActive'] == true) {
      return 'Aktiivne';
    }
    if (membership['isActive'] == false) {
      return 'Mitteaktiivne';
    }
    return 'Staatus puudub';
  }

  String _availabilityStatusLabel(Object? status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return 'Valves';
      case AvailabilityStatus.delayed:
        return 'Hilinen';
      case AvailabilityStatus.offDuty:
        return 'Valvest väljas';
      default:
        return 'Valmisolek märkimata';
    }
  }

  Widget _buildAvailabilitySection() {
    if (_targetUid.isEmpty || widget.organizationId.trim().isEmpty) {
      return const _ProfileRow(
        label: 'Valmisolek',
        value: 'Valmisolek märkimata',
      );
    }

    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: _targetUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final availability = snapshot.data;
        if (availability == null) {
          return const _ProfileRow(
            label: 'Valmisolek',
            value: 'Valmisolek märkimata',
          );
        }

        final lines = <String>[
          _availabilityStatusLabel(availability.status),
        ];
        final responseMinutes = availability.responseMinutes;
        if (responseMinutes != null && responseMinutes > 0) {
          lines.add('Hilinemine: $responseMinutes min');
        }

        return _ProfileRow(
          label: 'Valmisolek',
          value: lines.join('\n'),
        );
      },
    );
  }

  bool get _canViewTargetPersonalEquipment =>
      _isOwnProfile || _canManageProfileMembership;

  String _equipmentCategoryLabel(String category) {
    switch (category) {
      case EquipmentCategory.vessel:
        return 'Alus';
      case EquipmentCategory.engine:
        return 'Mootor';
      case EquipmentCategory.rescue:
        return 'Päästevarustus';
      case EquipmentCategory.medical:
        return 'Meditsiin';
      case EquipmentCategory.radio:
        return 'Raadio';
      case EquipmentCategory.safety:
        return 'Ohutus';
      default:
        return 'Muu';
    }
  }

  String _equipmentStatusLabel(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return 'Vajab hooldust';
      case EquipmentStatus.broken:
        return 'Katki';
      case EquipmentStatus.outOfService:
        return 'Kasutusest väljas';
      default:
        return 'Korras';
    }
  }

  Widget _buildEquipmentSection() {
    if (_targetUid.isEmpty ||
        widget.organizationId.trim().isEmpty ||
        widget.currentUid.trim().isEmpty) {
      return const _ProfileRow(
        label: 'Varustus',
        value: 'Varustust ei ole.',
      );
    }

    return StreamBuilder<List<EquipmentModel>>(
      stream: _equipmentService.streamVisibleEquipment(
        organizationId: widget.organizationId,
        currentUserId: widget.currentUid,
        canViewMemberPersonalEquipment: _canManageProfileMembership,
      ),
      builder: (context, snapshot) {
        final equipment = snapshot.data ?? const <EquipmentModel>[];
        final issuedEquipment = equipment
            .where(
              (item) =>
                  item.scope == EquipmentScope.organization &&
                  item.assignedToUserId == _targetUid,
            )
            .toList(growable: false);
        final personalEquipment = _canViewTargetPersonalEquipment
            ? equipment
                .where(
                  (item) =>
                      item.scope == EquipmentScope.personal &&
                      item.ownerUserId == _targetUid,
                )
                .toList(growable: false)
            : const <EquipmentModel>[];

        if (issuedEquipment.isEmpty && personalEquipment.isEmpty) {
          return const _ProfileRow(
            label: 'Varustus',
            value: 'Varustust ei ole.',
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Varustus',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (issuedEquipment.isNotEmpty)
                  _EquipmentGroup(
                    title: 'Väljastatud varustus',
                    equipment: issuedEquipment,
                    categoryLabel: _equipmentCategoryLabel,
                    statusLabel: _equipmentStatusLabel,
                    showIssuedLabel: true,
                  ),
                if (personalEquipment.isNotEmpty)
                  _EquipmentGroup(
                    title: 'Isiklik varustus',
                    equipment: personalEquipment,
                    categoryLabel: _equipmentCategoryLabel,
                    statusLabel: _equipmentStatusLabel,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _canViewTargetCertificates =>
      _isOwnProfile || _canManageProfileMembership;

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
      case CertificateStatus.missing:
        return 'Puudub';
      default:
        return 'Kehtiv';
    }
  }

  String _certificateDisplayStatus(CertificateModel certificate) {
    final expiresAt = certificate.expiresAt.trim();
    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (expiresAt.isEmpty || parsedExpiry == null) {
      return certificate.status;
    }

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

  Widget _buildCertificatesSection() {
    if (!_canViewTargetCertificates) {
      return const SizedBox.shrink();
    }
    if (_targetUid.isEmpty || widget.organizationId.trim().isEmpty) {
      return const _ProfileRow(
        label: 'Tunnistused',
        value: 'Tunnistusi ei ole.',
      );
    }

    return StreamBuilder<List<CertificateModel>>(
      stream: _certificateService.streamMyCertificates(
        organizationId: widget.organizationId,
        userId: _targetUid,
      ),
      builder: (context, snapshot) {
        final certificates = snapshot.data ?? const <CertificateModel>[];
        if (certificates.isEmpty) {
          return const _ProfileRow(
            label: 'Tunnistused',
            value: 'Tunnistusi ei ole.',
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Tunnistused',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...certificates.map(
                  (certificate) => _CertificateTile(
                    certificate: certificate,
                    typeLabel: _certificateTypeLabel(certificate.type),
                    statusLabel: _certificateStatusLabel(
                      _certificateDisplayStatus(certificate),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editOwnProfile() async {
    if (!_isOwnProfile) return;

    final nameController = TextEditingController(text: _name);
    final phoneController = TextEditingController(text: _phone ?? '');

    final result = await showDialog<_OwnProfileEditResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Muuda kontaktandmeid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nimi'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Katkesta'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _OwnProfileEditResult(
                    name: nameController.text,
                    phone: phoneController.text,
                  ),
                );
              },
              child: const Text('Salvesta'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();

    if (result == null) return;

    try {
      await _userService.updateOwnBasicProfile(
        uid: widget.currentUid,
        name: result.name,
        phone: result.phone,
      );

      if (!mounted) return;
      setState(() {
        _name = result.name.trim();
        _phone = _optionalString(result.phone);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Andmed salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Andmeid ei saanud salvestada.')),
      );
    }
  }

  Future<String?> _showSeaRescueLevelDialog() {
    final selectedLevel = SeaRescueLevel.normalize(_seaRescueLevel);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Merepääste aste'),
          children: [
            RadioGroup<String>(
              groupValue: selectedLevel,
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SeaRescueLevelOption(
                    level: SeaRescueLevel.none,
                    label: _seaRescueLevelLabel(SeaRescueLevel.none),
                  ),
                  _SeaRescueLevelOption(
                    level: SeaRescueLevel.level1,
                    label: _seaRescueLevelLabel(SeaRescueLevel.level1),
                  ),
                  _SeaRescueLevelOption(
                    level: SeaRescueLevel.level2,
                    label: _seaRescueLevelLabel(SeaRescueLevel.level2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeSeaRescueLevel() async {
    if (_targetUid.isEmpty) return;

    final level = await _showSeaRescueLevelDialog();
    if (level == null) return;

    try {
      await _membershipService.updateSeaRescueLevel(
        membershipId: widget.membershipId,
        targetUserId: _targetUid,
        organizationId: widget.organizationId,
        seaRescueLevel: level,
      );

      if (!mounted) return;
      setState(() => _seaRescueLevel = level);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merepääste aste salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merepääste astet ei saanud salvestada.'),
        ),
      );
    }
  }

  Future<String?> _showRoleDialog() {
    final selectedRole = MembershipRole.normalize(_membershipRole);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Muuda rolli'),
          children: [
            RadioGroup<String>(
              groupValue: selectedRole,
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoleOption(
                    role: MembershipRole.member,
                    label: _roleLabel(MembershipRole.member),
                  ),
                  _RoleOption(
                    role: MembershipRole.orgAdmin,
                    label: _roleLabel(MembershipRole.orgAdmin),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeRole() async {
    if (!_canEditRole || _targetUid.isEmpty) return;

    final role = await _showRoleDialog();
    if (role == null) return;

    try {
      await _membershipService.updateMembershipRole(
        membershipId: widget.membershipId,
        targetUserId: _targetUid,
        organizationId: widget.organizationId,
        role: role,
      );

      if (!mounted) return;
      setState(() => _membershipRole = role);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Roll salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rolli ei saanud salvestada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _stringValue(widget.userData['email'], 'E-post puudub');
    final role = _roleLabel(_membershipRole);
    final seaRescueLevel = _seaRescueLevelLabel(_seaRescueLevel);
    final status = _membershipStatusLabel(widget.membershipData);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liikme profiil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileRow(label: 'Nimi', value: _name),
          _ProfileRow(label: 'E-post', value: email),
          _ProfileRow(
            label: 'Telefon',
            value: _phone ?? 'Telefoni pole lisatud.',
          ),
          if (_phone != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                onPressed: () => _openPhoneDialer(context, _phone!),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Helista'),
              ),
            ),
          _ProfileRow(label: 'Organisatsiooni roll', value: role),
          _ProfileRow(label: 'Merepääste aste', value: seaRescueLevel),
          _ProfileRow(label: 'Liikmelisuse staatus', value: status),
          _buildAvailabilitySection(),
          _buildEquipmentSection(),
          _buildCertificatesSection(),
          if (_isOwnProfile) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Muuda minu andmeid'),
                subtitle: const Text('Muuda kontaktandmeid'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editOwnProfile,
              ),
            ),
          ],
          if (_canManageProfileMembership) ...[
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('Halda liiget'),
                  ),
                  ListTile(
                    title: const Text('Muuda merepääste astet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changeSeaRescueLevel,
                  ),
                  if (_canEditRole)
                    ListTile(
                      title: const Text('Muuda rolli'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changeRole,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnProfileEditResult {
  const _OwnProfileEditResult({
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;
}

class _SeaRescueLevelOption extends StatelessWidget {
  const _SeaRescueLevelOption({
    required this.level,
    required this.label,
  });

  final String level;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: level,
      title: Text(label),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.label,
  });

  final String role;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: role,
      title: Text(label),
    );
  }
}

class _EquipmentGroup extends StatelessWidget {
  const _EquipmentGroup({
    required this.title,
    required this.equipment,
    required this.categoryLabel,
    required this.statusLabel,
    this.showIssuedLabel = false,
  });

  final String title;
  final List<EquipmentModel> equipment;
  final String Function(String category) categoryLabel;
  final String Function(String status) statusLabel;
  final bool showIssuedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        ...equipment.map(
          (item) => ListTile(
            dense: true,
            title: Text(item.name.isEmpty ? 'Varustus' : item.name),
            subtitle: Text(
              [
                'Kategooria: ${categoryLabel(item.category)}',
                'Staatus: ${statusLabel(item.status)}',
                if (showIssuedLabel) 'Väljastatud liikmele',
              ].join('\n'),
            ),
          ),
        ),
      ],
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({
    required this.certificate,
    required this.typeLabel,
    required this.statusLabel,
  });

  final CertificateModel certificate;
  final String typeLabel;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final title = certificate.title.trim().isEmpty
        ? typeLabel
        : certificate.title.trim();
    final expiresAt = certificate.expiresAt.trim();

    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(
        [
          if (certificate.title.trim().isNotEmpty) typeLabel,
          if (expiresAt.isNotEmpty) 'Kehtib kuni: $expiresAt',
          'Staatus: $statusLabel',
        ].join('\n'),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
