import 'package:flutter/material.dart';

import '../models/equipment_model.dart';
import '../services/equipment_service.dart';
import '../widgets/status_badge.dart';

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
        const SnackBar(
          content: Text('Varustuse hooldustähtaegade kontroll ebaõnnestus.'),
        ),
      );
    }
  }

  Future<void> _showAddEquipmentDialog({
    required String scope,
  }) async {
    if (widget.organizationId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Varustust ei saa salvestada ilma aktiivse ühinguta.'),
        ),
      );
      return;
    }

    if (scope == EquipmentScope.organization && !widget.canManageEquipment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sul puudub õigus ühingu varustust muuta.'),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final nextMaintenanceDateController = TextEditingController();
    final noteController = TextEditingController();
    var selectedCategory = EquipmentCategory.other;
    var selectedStatus = EquipmentStatus.ok;
    String? nameError;

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
                    onChanged: (value) {
                      if (nameError != null && value.trim().isNotEmpty) {
                        setDialogState(() => nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Varustuse nimi',
                      errorText: nameError,
                    ),
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
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    setDialogState(() {
                      nameError = 'Varustuse nimi on kohustuslik.';
                    });
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Lisa'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true) return;

    final organizationId = widget.organizationId.trim();
    final currentUid = widget.currentUid.trim();
    final name = nameController.text.trim();
    final location = locationController.text.trim();
    final nextMaintenanceDate = nextMaintenanceDateController.text.trim();
    final note = noteController.text.trim();

    try {
      await _equipmentService.addEquipment(
        organizationId: organizationId,
        scope: scope,
        ownerUserId: scope == EquipmentScope.personal
            ? currentUid
            : '',
        name: name,
        category: selectedCategory,
        status: selectedStatus,
        location: location,
        nextMaintenanceDate: nextMaintenanceDate,
        note: note,
        createdBy: currentUid,
        canManageOrganizationEquipment: widget.canManageEquipment,
      );
      if (scope == EquipmentScope.organization) {
        await _checkMaintenanceDueNotifications();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustus salvestatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Varustuse lisamine ebaonnestus: $e')),
      );
    }
  }

  Future<void> _showEditEquipmentDialog(EquipmentModel item) async {
    if (widget.organizationId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Varustust ei saa salvestada ilma aktiivse ühinguta.'),
        ),
      );
      return;
    }

    if (!_canEditEquipment(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_equipmentPermissionMessage(item))),
      );
      return;
    }

    final nameController = TextEditingController(text: item.name);
    final locationController = TextEditingController(text: item.location);
    final nextMaintenanceDateController = TextEditingController(
      text: item.nextMaintenanceDate,
    );
    final noteController = TextEditingController(text: item.note);
    var selectedCategory = item.category;
    var selectedStatus = EquipmentStatus.values.contains(item.status)
        ? item.status
        : EquipmentStatus.ok;
    String? nameError;

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
                    onChanged: (value) {
                      if (nameError != null && value.trim().isNotEmpty) {
                        setDialogState(() => nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Varustuse nimi',
                      errorText: nameError,
                    ),
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
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    setDialogState(() {
                      nameError = 'Varustuse nimi on kohustuslik.';
                    });
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

    if (shouldUpdate != true) return;

    final organizationId = widget.organizationId.trim();
    final currentUid = widget.currentUid.trim();
    final name = nameController.text.trim();
    final location = locationController.text.trim();
    final nextMaintenanceDate = nextMaintenanceDateController.text.trim();
    final note = noteController.text.trim();

    try {
      await _equipmentService.updateEquipment(
        equipmentId: item.id,
        organizationId: organizationId,
        name: name,
        category: selectedCategory,
        status: selectedStatus,
        location: location,
        nextMaintenanceDate: nextMaintenanceDate,
        note: note,
        updatedBy: currentUid,
        canManageOrganizationEquipment: widget.canManageEquipment,
      );
      if (item.scope == EquipmentScope.organization) {
        await _checkMaintenanceDueNotifications();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustus salvestatud')),
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
        stream: _equipmentService.streamVisibleEquipment(
          organizationId: widget.organizationId,
          currentUserId: widget.currentUid,
          canViewMemberPersonalEquipment: widget.canManageEquipment,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Varustuse laadimine ebaõnnestus.'),
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
          final memberPersonalEquipment = equipment
              .where(
                (item) =>
                    item.isPersonal &&
                    item.ownerUserId != widget.currentUid,
              )
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildEquipmentSection(
                title: 'Minu varustus',
                equipment: personalEquipment,
                emptyText: 'Isiklikku varustust ei ole lisatud.',
                addLabel: 'Lisa minu varustus',
                onAdd: () => _showAddEquipmentDialog(
                  scope: EquipmentScope.personal,
                ),
              ),
              if (widget.canManageEquipment) ...[
                const SizedBox(height: 24),
                _buildEquipmentSection(
                  title: 'Liikmete varustus',
                  equipment: memberPersonalEquipment,
                  emptyText: 'Liikmete varustust ei ole lisatud.',
                  addLabel: '',
                  helperText:
                      'Admin saab vaadata ja muuta liikmete isiklikku varustust.',
                  onAdd: null,
                ),
              ],
              const SizedBox(height: 24),
              _buildEquipmentSection(
                title: 'Ühingu varustus',
                equipment: organizationEquipment,
                emptyText: 'Varustust ei ole lisatud.',
                addLabel: 'Lisa ühingu varustus',
                helperText: widget.canManageEquipment
                    ? null
                    : 'Sul puudub õigus ühingu varustust muuta.',
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
    String? helperText,
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
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
        ],
        const SizedBox(height: 12),
        _buildEquipmentAttentionNotice(equipment),
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
          leading: StatusBadge(
            label: _equipmentStatusLabel(item.status),
            type: _equipmentStatusBadgeType(item.status),
            icon: _equipmentStatusIcon(item.status),
          ),
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

  Widget _buildEquipmentAttentionNotice(List<EquipmentModel> equipment) {
    final problemItems = equipment
        .where((item) => item.status != EquipmentStatus.ok)
        .toList(growable: false);
    final hasProblems = problemItems.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasProblems ? const Color(0xFFFFF7E6) : const Color(0xFFE7F5E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasProblems ? const Color(0xFFE0A100) : const Color(0xFF2E7D32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasProblems
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
            color: hasProblems
                ? const Color(0xFF9A6A00)
                : const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasProblems
                  ? 'Tähelepanu vajav varustus: '
                      '${problemItems.map((item) => item.name).join(', ')}'
                  : 'Kõik varustus on korras.',
            ),
          ),
        ],
      ),
    );
  }

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

  bool _canEditEquipment(EquipmentModel item) {
    if (item.isPersonal) {
      return item.ownerUserId == widget.currentUid ||
          widget.canManageEquipment;
    }
    return widget.canManageEquipment;
  }

  String _equipmentPermissionMessage(EquipmentModel item) {
    if (!item.isPersonal) {
      return 'Sul puudub õigus ühingu varustust muuta.';
    }
    return 'Sul puudub õigus seda varustust muuta.';
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

  StatusBadgeType _equipmentStatusBadgeType(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return StatusBadgeType.equipmentWarning;
      case EquipmentStatus.broken:
      case EquipmentStatus.outOfService:
        return StatusBadgeType.critical;
      default:
        return StatusBadgeType.ready;
    }
  }

  IconData _equipmentStatusIcon(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return Icons.build_circle_outlined;
      case EquipmentStatus.broken:
      case EquipmentStatus.outOfService:
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline;
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
