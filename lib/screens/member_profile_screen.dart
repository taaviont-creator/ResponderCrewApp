import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/membership_model.dart';
import '../services/membership_service.dart';

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
  final _membershipService = MembershipService();
  late String _seaRescueLevel;

  @override
  void initState() {
    super.initState();
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
    if (role is! String || role.trim().isEmpty) {
      return 'Roll puudub';
    }

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

  bool get _canManageProfileMembership {
    if (!widget.canManageRoles) return false;
    if (widget.currentUid.trim().isEmpty) return false;

    final targetUid = _stringValue(widget.membershipData['userId'], '');
    if (targetUid.isEmpty) return false;

    final membershipOrganizationId =
        _membershipService.organizationIdFromMembership(widget.membershipData);
    return membershipOrganizationId == widget.organizationId;
  }

  Future<String?> _showSeaRescueLevelDialog() {
    final selectedLevel = SeaRescueLevel.normalize(_seaRescueLevel);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Merepääste aste'),
          children: [
            _SeaRescueLevelOption(
              level: SeaRescueLevel.none,
              label: _seaRescueLevelLabel(SeaRescueLevel.none),
              selectedLevel: selectedLevel,
            ),
            _SeaRescueLevelOption(
              level: SeaRescueLevel.level1,
              label: _seaRescueLevelLabel(SeaRescueLevel.level1),
              selectedLevel: selectedLevel,
            ),
            _SeaRescueLevelOption(
              level: SeaRescueLevel.level2,
              label: _seaRescueLevelLabel(SeaRescueLevel.level2),
              selectedLevel: selectedLevel,
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeSeaRescueLevel() async {
    final targetUid = _stringValue(widget.membershipData['userId'], '');
    if (targetUid.isEmpty) return;

    final level = await _showSeaRescueLevelDialog();
    if (level == null) return;

    try {
      await _membershipService.updateSeaRescueLevel(
        membershipId: widget.membershipId,
        targetUserId: targetUid,
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

  @override
  Widget build(BuildContext context) {
    final name = _stringValue(widget.userData['name'], 'Nimi puudub');
    final email = _stringValue(widget.userData['email'], 'E-post puudub');
    final phone = _optionalString(widget.userData['phone']);
    final role = _roleLabel(widget.membershipData['role']);
    final seaRescueLevel = _seaRescueLevelLabel(_seaRescueLevel);
    final status = _membershipStatusLabel(widget.membershipData);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liikme profiil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileRow(label: 'Nimi', value: name),
          _ProfileRow(label: 'E-post', value: email),
          _ProfileRow(
            label: 'Telefon',
            value: phone ?? 'Telefoni pole lisatud.',
          ),
          if (phone != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                onPressed: () => _openPhoneDialer(context, phone),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Helista'),
              ),
            ),
          _ProfileRow(label: 'Organisatsiooni roll', value: role),
          _ProfileRow(label: 'Merepääste aste', value: seaRescueLevel),
          _ProfileRow(label: 'Liikmelisuse staatus', value: status),
          if (_canManageProfileMembership) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Halda liiget'),
                subtitle: const Text('Muuda merepääste astet'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changeSeaRescueLevel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeaRescueLevelOption extends StatelessWidget {
  const _SeaRescueLevelOption({
    required this.level,
    required this.label,
    required this.selectedLevel,
  });

  final String level;
  final String label;
  final String selectedLevel;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: level,
      groupValue: selectedLevel,
      title: Text(label),
      onChanged: (value) => Navigator.of(context).pop(value),
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
