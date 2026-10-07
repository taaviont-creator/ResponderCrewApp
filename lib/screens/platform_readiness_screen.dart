import '../widgets/app_layout.dart';
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

  Future<void> _showSettingsDialog({PlatformReadinessSummary? summary}) async {
    final organizationId = widget.activeOrganizationId;
    if (organizationId == null || organizationId.isEmpty) return;

    final regionController = TextEditingController(text: summary?.region ?? '');
    final contactNameController = TextEditingController(
      text: summary?.contactName ?? '',
    );
    final contactPhoneController = TextEditingController(
      text: summary?.contactPhone ?? '',
    );
    final minimumCrewController = TextEditingController(
      text: (summary?.minimumCrewRequired ?? 0).toString(),
    );
    final criticalIssuesController = TextEditingController(
      text: summary?.criticalIssues ?? '',
    );

    var primaryVesselStatus =
        summary?.primaryVesselStatus ?? ReadinessEquipmentStatus.unknown;
    var equipmentStatus =
        summary?.equipmentStatus ?? ReadinessEquipmentStatus.unknown;
    String? minimumCrewError;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Ühingu valmiduse seaded'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Reageerimisvalmidus arvutatakse automaatselt liikmete '
                    'tegeliku valvesoleku ja II astme olemasolu põhjal.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minimumCrewController,
                    decoration: InputDecoration(
                      labelText: 'Minimaalne meeskond',
                      errorText: minimumCrewError,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    itemHeight: null,
                    initialValue: primaryVesselStatus,
                    decoration: const InputDecoration(
                      labelText: 'Põhialuse staatus',
                    ),
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
                    isExpanded: true,
                    itemHeight: null,
                    initialValue: equipmentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Varustuse staatus',
                    ),
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
                    controller: regionController,
                    decoration: const InputDecoration(labelText: 'Piirkond'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contactNameController,
                    decoration: const InputDecoration(labelText: 'Kontaktisik'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contactPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Kontakttelefon',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: criticalIssuesController,
                    decoration: const InputDecoration(
                      labelText: 'Olulised probleemid',
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
                onPressed: () {
                  final minimumCrew = int.tryParse(
                    minimumCrewController.text.trim(),
                  );
                  if (minimumCrew == null || minimumCrew < 0) {
                    setDialogState(
                      () => minimumCrewError = 'Sisesta korrektne arv.',
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Salvesta'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldSave != true) return;

    try {
      final minimumCrewRequired = int.parse(minimumCrewController.text.trim());

      await _platformReadinessService.saveOrganizationSettings(
        organizationId: organizationId,
        organizationName: widget.activeOrganizationName ?? organizationId,
        region: regionController.text,
        contactName: contactNameController.text,
        contactPhone: contactPhoneController.text,
        minimumCrewRequired: minimumCrewRequired,
        primaryVesselStatus: primaryVesselStatus,
        equipmentStatus: equipmentStatus,
        criticalIssues: criticalIssuesController.text,
        lastUpdatedBy: widget.currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ühingu valmiduse seaded salvestatud')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvestamine ebaõnnestus.')),
      );
    } finally {
      regionController.dispose();
      contactNameController.dispose();
      contactPhoneController.dispose();
      minimumCrewController.dispose();
      criticalIssuesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlatformAdmin && !widget.canManageOwnSummary) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Ühingu valmiduse seaded')),
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

    return AppScaffold(
      appBar: AppBar(
        title: Text(
          widget.isPlatformAdmin
              ? 'Ühingute valmisoleku seaded'
              : 'Ühingu valmiduse seaded',
        ),
      ),
      floatingActionButton:
          widget.canManageOwnSummary &&
              activeOrganizationId != null &&
              activeOrganizationId.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showSettingsDialog(),
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
            return const Center(
              child: Text('Ühingu valmiduse seadete laadimine ebaõnnestus.'),
            );
          }

          final summaries = snapshot.data ?? const <PlatformReadinessSummary>[];
          if (summaries.isEmpty) {
            return const Center(
              child: Text('Ühingu valmiduse seadeid ei ole lisatud'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: summaries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final summary = summaries[index];
              final canEdit =
                  widget.canManageOwnSummary &&
                  summary.organizationId == widget.activeOrganizationId;
              final details = <String>[
                summary.minimumCrewRequired > 0
                    ? 'Miinimumkoosseis: ${summary.minimumCrewRequired}'
                    : 'Miinimumkoosseis seadistamata',
                if (summary.primaryVesselStatus !=
                    ReadinessEquipmentStatus.unknown)
                  'Põhialus: '
                      '${_equipmentStatusLabel(summary.primaryVesselStatus)}',
                if (summary.equipmentStatus != ReadinessEquipmentStatus.unknown)
                  'Varustus: ${_equipmentStatusLabel(summary.equipmentStatus)}',
                if (summary.region.isNotEmpty) summary.region,
                if (summary.contactName.isNotEmpty ||
                    summary.contactPhone.isNotEmpty)
                  'Kontakt: ${[if (summary.contactName.isNotEmpty) summary.contactName, if (summary.contactPhone.isNotEmpty) summary.contactPhone].join(' · ')}',
                if (summary.criticalIssues.isNotEmpty)
                  'Probleemid: ${summary.criticalIssues}',
              ];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  summary.organizationName.isEmpty
                      ? summary.organizationId
                      : summary.organizationName,
                ),
                subtitle: Text(details.join('\n')),
                trailing: canEdit
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showSettingsDialog(summary: summary),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
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
        return 'Määramata';
    }
  }
}
