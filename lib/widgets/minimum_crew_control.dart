import 'package:flutter/material.dart';
import '../models/platform_readiness_model.dart';
import '../services/platform_readiness_service.dart';
import 'minimum_crew_dialog.dart';

class MinimumCrewControl extends StatefulWidget {
  const MinimumCrewControl({
    super.key,
    required this.organizationId,
    required this.currentUid,
    this.organizationName,
  });
  final String organizationId, currentUid;
  final String? organizationName;
  @override
  State<MinimumCrewControl> createState() => _MinimumCrewControlState();
}

class _MinimumCrewControlState extends State<MinimumCrewControl> {
  final _service = PlatformReadinessService();
  late final _stream = _service.streamOrganizationSummary(
    organizationId: widget.organizationId,
  );
  bool _saving = false;
  Future<void> _edit(int current) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => MinimumCrewDialog(initialValue: current),
    );
    if (value == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.saveMinimumCrewRequired(
        organizationId: widget.organizationId,
        organizationName: widget.organizationName ?? '',
        minimumCrewRequired: value,
        lastUpdatedBy: widget.currentUid,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Miinimumkoosseisu ei saanud salvestada.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<PlatformReadinessSummary>>(
        stream: _stream,
        builder: (context, snapshot) {
          final count = snapshot.data?.isNotEmpty == true
              ? snapshot.data!.first.minimumCrewRequired
              : 0;
          return Card(
            child: ListTile(
              title: const Text('Ühingu miinimumkoosseis'),
              subtitle: Text(
                snapshot.hasError
                    ? 'Andmete laadimine ebaõnnestus.'
                    : 'Vähemalt $count valves liiget',
              ),
              trailing: _saving
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.edit_outlined),
              onTap: _saving || !snapshot.hasData || snapshot.hasError
                  ? null
                  : () => _edit(count),
            ),
          );
        },
      );
}
