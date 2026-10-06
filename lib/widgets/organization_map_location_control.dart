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
  Map<String, dynamic>? _location;
  String? _loadError;
  Future<Map<String, dynamic>?>? _pending;
  OrganizationMapLocationService get _service =>
      widget.service ?? OrganizationMapLocationService();
  @override
  void initState() {
    super.initState();
    _pending = _load();
  }

  @override
  void didUpdateWidget(OrganizationMapLocationControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) {
      _location = null;
      _pending = _load();
    }
  }

  Future<Map<String, dynamic>?> _load() async {
    final org = widget.organizationId;
    _loading = true;
    _loadError = null;
    try {
      final value = await _service.load(org);
      if (mounted && widget.organizationId == org) _location = value;
      return value;
    } catch (_) {
      if (mounted && widget.organizationId == org) {
        _loadError = 'Asukohta ei saanud laadida. Vajuta uuesti proovimiseks.';
      }
      return null;
    } finally {
      if (mounted && widget.organizationId == org) {
        setState(() => _loading = false);
      }
    }
  }

  String get _summary {
    if (_loadError != null) return _loadError!;
    if (_location == null) return 'Laadin asukohta…';
    final lat = _location!['latitude'], lon = _location!['longitude'];
    if (lat is! num || lon is! num) {
      return 'Asukoht määramata · lisa koordinaadid';
    }
    final address = (_location!['address'] ?? '').toString().trim();
    final coordinates = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
    final addressIsCoordinates =
        address.replaceAll(' ', '') == coordinates.replaceAll(' ', '');
    return '${address.isEmpty || addressIsCoordinates ? '' : '$address\n'}$coordinates';
  }

  Future<void> _edit() async {
    final organizationId = widget.organizationId;
    final service = _service;
    setState(() {
      _busy = true;
      _loading = true;
    });
    try {
      final location = await (_loadError == null
          ? _pending!
          : (_pending = _load()));
      if (!mounted || widget.organizationId != organizationId) return;
      setState(() => _loading = false);
      if (location == null) return;
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
        _location = {
          ...saved,
          'revision': ((location['revision'] as num?)?.toInt() ?? 0) + 1,
        };
        _pending = Future.value(_location);
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
      subtitle: Text(_summary),
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
