import 'package:flutter/material.dart';

import '../models/equipment_model.dart';
import '../services/equipment_service.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageEquipment,
    this.openOrganizationCreateOnLoad = false,
  });

  final String organizationId;
  final String currentUid;
  final bool canManageEquipment;
  final bool openOrganizationCreateOnLoad;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final _equipmentService = EquipmentService();

  @override
  void initState() {
    super.initState();
    if (widget.canManageEquipment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkMaintenanceDueNotifications();
        if (widget.openOrganizationCreateOnLoad) {
          _showAddEquipmentDialog(scope: EquipmentScope.organization);
        }
      });
    }
  }

  Future<void> _checkMaintenanceDueNotifications() async {
    try {
      await _equipmentService.checkMaintenanceDueNotifications(
        organizationId: widget.organizationId,
        createdBy: widget.currentUid,
        canManageOrganizationEquipment: widget.canManageEquipment,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Varustuse hooldustähtaegade kontroll ebaõnnestus: $e'),
        ),
      );
    }
  }

  Future<void> _showAddEquipmentDialog({
    required String scope,
  }) async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final nextMaintenanceDateController = TextEditingController();
    final noteController = TextEditingController();
    var selectedCategory = EquipmentCategory.other;
    var selectedStatus = EquipmentStatus.ok;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              scope == EquipmentScope.personal
                  ? 'Lisa minu varustus'
                  : 'Lisa ühingu varustus',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nimi'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategooria'),
                    items: EquipmentCategory.values.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(_equipmentCategoryLabel(category)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Staatus'),
                    items: EquipmentStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_equipmentStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Asukoht'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nextMaintenanceDateController,
                    decoration: const InputDecoration(
                      labelText: 'Järgmine hooldus või kontroll',
                      hintText: 'nt 2026-07-15',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Markus'),
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

    try {
      await _equipmentService.addEquipment(
        organizationId: widget.organizationId,
        scope: scope,
        ownerUserId: scope == EquipmentScope.personal
            ? widget.currentUid
            : '',
        name: nameController.text,
        category: selectedCategory,
        status: selectedStatus,
        location: locationController.text,
        nextMaintenanceDate: nextMaintenanceDateController.text,
        note: noteController.text,
        createdBy: widget.currentUid,
        canManageOrganizationEquipment: widget.canManageEquipment,
      );
      if (scope == EquipmentScope.organization) {
        await _checkMaintenanceDueNotifications();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustus lisatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Varustuse lisamine ebaonnestus: $e')),
      );
    }
  }

  Future<void> _showEditEquipmentDialog(EquipmentModel item) async {
    final nameController = TextEditingController(text: item.name);
    final locationController = TextEditingController(text: item.location);
    final nextMaintenanceDateController = TextEditingController(
      text: item.nextMaintenanceDate,
    );
    final noteController = TextEditingController(text: item.note);
    var selectedCategory = item.category;
    var selectedStatus = item.status;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Muuda varustust'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nimi'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategooria'),
                    items: EquipmentCategory.values.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(_equipmentCategoryLabel(category)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Staatus'),
                    items: EquipmentStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_equipmentStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Asukoht'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nextMaintenanceDateController,
                    decoration: const InputDecoration(
                      labelText: 'Järgmine hooldus või kontroll',
                      hintText: 'nt 2026-07-15',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Markus'),
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
                child: const Text('Salvesta'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldUpdate != true) return;

    try {
      await _equipmentService.updateEquipment(
        equipmentId: item.id,
        organizationId: widget.organizationId,
        name: nameController.text,
        category: selectedCategory,
        status: selectedStatus,
        location: locationController.text,
        nextMaintenanceDate: nextMaintenanceDateController.text,
        note: noteController.text,
        updatedBy: widget.currentUid,
        canManageOrganizationEquipment: widget.canManageEquipment,
      );
      if (item.scope == EquipmentScope.organization) {
        await _checkMaintenanceDueNotifications();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustus uuendatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Varustuse uuendamine ebaonnestus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Varustus'),
      ),
      body: StreamBuilder<List<EquipmentModel>>(
        stream: _equipmentService.streamOrganizationEquipment(
          organizationId: widget.organizationId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Varustuse laadimine ebaonnestus: ${snapshot.error}'),
            );
          }

          final equipment = snapshot.data ?? const <EquipmentModel>[];
          final personalEquipment = equipment
              .where(
                (item) =>
                    item.isPersonal &&
                    item.ownerUserId == widget.currentUid,
              )
              .toList(growable: false);
          final organizationEquipment = equipment
              .where((item) => !item.isPersonal)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildEquipmentSection(
                title: 'Minu varustus',
                equipment: personalEquipment,
                emptyText: 'Isiklikku varustust ei ole lisatud',
                addLabel: 'Lisa minu varustus',
                onAdd: () => _showAddEquipmentDialog(
                  scope: EquipmentScope.personal,
                ),
              ),
              const SizedBox(height: 24),
              _buildEquipmentSection(
                  title: 'Ühingu varustus',
                equipment: organizationEquipment,
                  emptyText: 'Ühingu varustust ei ole lisatud',
                  addLabel: 'Lisa ühingu varustus',
                onAdd: widget.canManageEquipment
                    ? () => _showAddEquipmentDialog(
                          scope: EquipmentScope.organization,
                        )
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEquipmentSection({
    required String title,
    required List<EquipmentModel> equipment,
    required String emptyText,
    required String addLabel,
    required VoidCallback? onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(addLabel),
              ),
          ],
        ),
        if (equipment.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyText),
          )
        else
          ...equipment.map(_buildEquipmentTile),
      ],
    );
  }

  Widget _buildEquipmentTile(EquipmentModel item) {
    final maintenanceStatus = _maintenanceStatusLabel(item);
    final subtitleParts = [
      _equipmentCategoryLabel(item.category),
      _equipmentStatusLabel(item.status),
      if (item.location.isNotEmpty) item.location,
      if (item.nextMaintenanceDate.isNotEmpty)
        'Hooldus ${item.nextMaintenanceDate}',
      ?maintenanceStatus,
      if (item.note.isNotEmpty) item.note,
    ];

    return Column(
      children: [
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.name),
          subtitle: Text(subtitleParts.join(' - ')),
          trailing: _canEditEquipment(item)
              ? IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Muuda varustust',
                  onPressed: () => _showEditEquipmentDialog(item),
                )
              : null,
        ),
      ],
    );
  }

  String _equipmentCategoryLabel(String category) {
    switch (category) {
      case EquipmentCategory.vessel:
        return 'Vessel';
      case EquipmentCategory.engine:
        return 'Engine';
      case EquipmentCategory.rescue:
        return 'Rescue';
      case EquipmentCategory.medical:
        return 'Medical';
      case EquipmentCategory.radio:
        return 'Radio';
      case EquipmentCategory.safety:
        return 'Safety';
      default:
        return 'Other';
    }
  }

  bool _canEditEquipment(EquipmentModel item) {
    if (item.isPersonal) {
      return item.ownerUserId == widget.currentUid;
    }
    return widget.canManageEquipment;
  }

  String _equipmentStatusLabel(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return 'Needs maintenance';
      case EquipmentStatus.broken:
        return 'Broken';
      case EquipmentStatus.outOfService:
        return 'Out of service';
      default:
        return 'OK';
    }
  }

  String? _maintenanceStatusLabel(EquipmentModel item) {
    final parsedDueDate =
        DateTime.tryParse(item.nextMaintenanceDate.trim());
    if (parsedDueDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      parsedDueDate.year,
      parsedDueDate.month,
      parsedDueDate.day,
    );
    if (dueDate.isBefore(today)) return 'Hooldus üle tähtaja';
    if (!dueDate.isAfter(today.add(const Duration(days: 30)))) {
      return 'Hooldus läheneb';
    }
    return null;
  }
}
