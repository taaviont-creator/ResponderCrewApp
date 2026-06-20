import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/membership_model.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({
    super.key,
    required this.userData,
    required this.membershipData,
  });

  final Map<String, dynamic> userData;
  final Map<String, dynamic> membershipData;

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

  @override
  Widget build(BuildContext context) {
    final name = _stringValue(userData['name'], 'Nimi puudub');
    final email = _stringValue(userData['email'], 'E-post puudub');
    final phone = _optionalString(userData['phone']);
    final role = _roleLabel(membershipData['role']);
    final status = _membershipStatusLabel(membershipData);

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
          _ProfileRow(label: 'Liikmelisuse staatus', value: status),
        ],
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
