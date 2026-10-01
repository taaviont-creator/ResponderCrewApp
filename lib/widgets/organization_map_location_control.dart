import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/organization_map_location_service.dart';
import 'rescue_base_dialog.dart';

/// Shown only in organization admin settings. The server independently checks membership.
class OrganizationMapLocationControl extends StatefulWidget {
  const OrganizationMapLocationControl({
    super.key,
    this.onSaved,
    required this.organizationId,
    this.service,
  });
  final String organizationId;
  final OrganizationMapLocationService? service;
  final VoidCallback? onSaved;
  @override
  State<OrganizationMapLocationControl> createState() =>
      _OrganizationMapLocationControlState();
}

class _OrganizationMapLocationControlState
    extends State<OrganizationMapLocationControl> {
  bool _busy = false;
  bool _loading = false;
  Future<void> _edit() async {
    final organizationId = widget.organizationId;
    final service = widget.service ?? OrganizationMapLocationService();
    setState(() {
      _busy = true;
      _loading = true;
    });
    try {
      final location = await service.load(organizationId);
      if (!mounted || widget.organizationId != organizationId) return;
      setState(() => _loading = false);
      final saved = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RescueBaseDialog(
          initial: location,
          organizationLocation: true,
          onSave: (value) => service.save(
            organizationId,
            (location['revision'] as num?)?.toInt() ?? 0,
            value,
          ),
        ),
      );
      if (saved != null && mounted && widget.organizationId == organizationId) {
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ühingu asukoht salvestatud.')),
        );
      }
    } catch (error) {
      if (!mounted || widget.organizationId != organizationId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FirebaseFunctionsException
                ? error.message ??
                      'Asukoha laadimine ebaõnnestus. Proovi uuesti.'
                : 'Asukoha laadimine ebaõnnestus. Proovi uuesti.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.location_on_outlined),
      title: const Text('Ühingu asukoht kaardil'),
      subtitle: const Text('Päästebaasi tegelikud koordinaadid'),
      trailing: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.edit_outlined),
      onTap: _busy ? null : _edit,
    ),
  );
}
