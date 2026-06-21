import 'package:flutter/material.dart';

import '../models/platform_readiness_model.dart';
import '../services/platform_readiness_service.dart';

class PlatformReadinessScreen extends StatefulWidget {
  const PlatformReadinessScreen({
    super.key,
    required this.currentUid,
    required this.activeOrganizationId,
    required this.activeOrganizationName,
    required this.canManageOwnSummary,
    required this.isPlatformAdmin,
  });

  final String currentUid;
  final String? activeOrganizationId;
  final String? activeOrganizationName;
  final bool canManageOwnSummary;
  final bool isPlatformAdmin;

  @override
  State<PlatformReadinessScreen> createState() =>
      _PlatformReadinessScreenState();
}

class _PlatformReadinessScreenState extends State<PlatformReadinessScreen> {
  final _platformReadinessService = PlatformReadinessService();

  Future<void> _showSummaryDialog({
    PlatformReadinessSummary? summary,
  }) async {
    final organizationId = widget.activeOrganizationId;
    if (organizationId == null || organizationId.isEmpty) return;

    final regionController = TextEditingController(text: summary?.region ?? '');
    final contactNameController =
        TextEditingController(text: summary?.contactName ?? '');
    final contactPhoneController =
        TextEditingController(text: summary?.contactPhone ?? '');
    final onDutyController = TextEditingController(
      text: (summary?.onDutyCount ?? 0).toString(),
    );
    final delayedController = TextEditingController(
      text: (summary?.delayedCount ?? 0).toString(),
    );
    final minimumCrewController = TextEditingController(
      text: (summary?.minimumCrewRequired ?? 0).toString(),
    );
    final criticalIssuesController =
        TextEditingController(text: summary?.criticalIssues ?? '');

    var readinessStatus = summary?.readinessStatus ?? ReadinessStatus.unknown;
    var primaryVesselStatus =
        summary?.primaryVesselStatus ?? ReadinessEquipmentStatus.unknown;
    var equipmentStatus =
        summary?.equipmentStatus ?? ReadinessEquipmentStatus.unknown;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Valmiduse kokkuvote'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: regionController,
                    decoration: const InputDecoration(labelText: 'Piirkond'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contactNameController,
                    decoration:
                        const InputDecoration(labelText: 'Kontaktisik'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contactPhoneController,
                    decoration:
                        const InputDecoration(labelText: 'Kontakttelefon'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: readinessStatus,
                    decoration:
                        const InputDecoration(labelText: 'Valmiduse staatus'),
                    items: ReadinessStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_readinessStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => readinessStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: onDutyController,
                    decoration:
                        const InputDecoration(labelText: 'On duty arv'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: delayedController,
                    decoration:
                        const InputDecoration(labelText: 'Delayed arv'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: minimumCrewController,
                    decoration: const InputDecoration(
                      labelText: 'Minimaalne meeskond',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Miinimumkoosseisu täituvus arvutatakse valves liikmete arvu põhjal.',
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: primaryVesselStatus,
                    decoration:
                        const InputDecoration(labelText: 'Pohialuse staatus'),
                    items: ReadinessEquipmentStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_equipmentStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => primaryVesselStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: equipmentStatus,
                    decoration:
                        const InputDecoration(labelText: 'Varustuse staatus'),
                    items: ReadinessEquipmentStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_equipmentStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => equipmentStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: criticalIssuesController,
                    decoration: const InputDecoration(
                      labelText: 'Kriitilised probleemid',
                    ),
                    maxLines: 3,
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
                child: const Text('Salvesta'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldSave != true) return;

    try {
      final onDutyCount = int.tryParse(onDutyController.text) ?? 0;
      final delayedCount = int.tryParse(delayedController.text) ?? 0;
      final minimumCrewRequired =
          int.tryParse(minimumCrewController.text) ?? 0;
      final minimumCrewMet =
          minimumCrewRequired > 0 && onDutyCount >= minimumCrewRequired;

      await _platformReadinessService.saveOrganizationSummary(
        organizationId: organizationId,
        organizationName: widget.activeOrganizationName ?? organizationId,
        region: regionController.text,
        contactName: contactNameController.text,
        contactPhone: contactPhoneController.text,
        readinessStatus: readinessStatus,
        onDutyCount: onDutyCount,
        delayedCount: delayedCount,
        minimumCrewRequired: minimumCrewRequired,
        minimumCrewMet: minimumCrewMet,
        primaryVesselStatus: primaryVesselStatus,
        equipmentStatus: equipmentStatus,
        criticalIssues: criticalIssuesController.text,
        lastUpdatedBy: widget.currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valmiduse kokkuvote salvestatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvestamine ebaonnestus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlatformAdmin && !widget.canManageOwnSummary) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Platvormi valmidus'),
        ),
        body: const Center(
          child: Text('See vaade on ainult administraatorile'),
        ),
      );
    }

    final activeOrganizationId = widget.activeOrganizationId;
    final summariesStream = widget.isPlatformAdmin
        ? _platformReadinessService.streamAllSummaries()
        : activeOrganizationId == null || activeOrganizationId.isEmpty
            ? Stream<List<PlatformReadinessSummary>>.value(
                const <PlatformReadinessSummary>[],
              )
            : _platformReadinessService.streamOrganizationSummary(
                organizationId: activeOrganizationId,
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platvormi valmidus'),
      ),
      floatingActionButton: widget.canManageOwnSummary &&
              activeOrganizationId != null &&
              activeOrganizationId.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showSummaryDialog(),
              child: const Icon(Icons.edit),
            )
          : null,
      body: StreamBuilder<List<PlatformReadinessSummary>>(
        stream: summariesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Valmiduse laadimine ebaonnestus: ${snapshot.error}'),
            );
          }

          final summaries = snapshot.data ?? const <PlatformReadinessSummary>[];
          if (summaries.isEmpty) {
            return const Center(
              child: Text('Valmiduse kokkuvotteid ei ole lisatud'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: summaries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final summary = summaries[index];
              final canEdit = widget.canManageOwnSummary &&
                  summary.organizationId == widget.activeOrganizationId;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  summary.organizationName.isEmpty
                      ? summary.organizationId
                      : summary.organizationName,
                ),
                subtitle: Text(
                  [
                    _readinessStatusLabel(summary.readinessStatus),
                    'On duty: ${summary.onDutyCount}',
                    'Delayed: ${summary.delayedCount}',
                    'Min: ${summary.minimumCrewRequired}',
                    summary.minimumCrewMet
                        ? 'Miinimum koos'
                        : 'Miinimum puudu',
                    'Varustus: ${_equipmentStatusLabel(summary.equipmentStatus)}',
                    if (summary.region.isNotEmpty) summary.region,
                    if (summary.criticalIssues.isNotEmpty)
                      'Probleemid: ${summary.criticalIssues}',
                  ].join('\n'),
                ),
                trailing: canEdit
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showSummaryDialog(summary: summary),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _readinessStatusLabel(String status) {
    switch (status) {
      case ReadinessStatus.ready:
        return 'Valmis';
      case ReadinessStatus.limited:
        return 'Piiratud';
      case ReadinessStatus.notReady:
        return 'Ei ole valmis';
      default:
        return 'Teadmata';
    }
  }

  String _equipmentStatusLabel(String status) {
    switch (status) {
      case ReadinessEquipmentStatus.ok:
        return 'OK';
      case ReadinessEquipmentStatus.issues:
        return 'Probleemid';
      case ReadinessEquipmentStatus.critical:
        return 'Kriitiline';
      default:
        return 'Teadmata';
    }
  }
}
