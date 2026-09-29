import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/equipment_model.dart';
import '../services/equipment_service.dart';
import '../services/membership_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/equipment_item_card.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageEquipment,
    this.openOrganizationCreateOnLoad = false,
    this.initialView = 'shared',
  });

  final String organizationId;
  final String currentUid;
  final bool canManageEquipment;
  final bool openOrganizationCreateOnLoad;
  final String initialView;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final _equipmentService = EquipmentService();
  final _membershipService = MembershipService();
  late String _view = widget.initialView;
  String _search = '';
  String? _category;

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
    } catch (_) {
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
                    decoration: const InputDecoration(labelText: 'Märkus'),
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
        storage: scope == EquipmentScope.organization && _view == 'warehouse' ? 'warehouse' : 'shared',
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustuse lisamine ebaõnnestus.')),
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
                    decoration: const InputDecoration(labelText: 'Märkus'),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustuse uuendamine ebaõnnestus.')),
      );
    }
  }

  Future<void> _showIssueEquipmentDialog(EquipmentModel item) async {
    if (!_canManageOrganizationAssignment(item)) return;

    List<_EquipmentMemberOption> members;
    try {
      members = await _loadIssueMemberOptions();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustust ei saanud väljastada.')),
      );
      return;
    }

    if (!mounted) return;
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liikmeid ei leitud.')),
      );
      return;
    }

    var selectedMember = members.first;
    final member = await showDialog<_EquipmentMemberOption>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Väljasta liikmele'),
            content: DropdownButtonFormField<_EquipmentMemberOption>(
              initialValue: selectedMember,
              decoration: const InputDecoration(labelText: 'Liige'),
              items: members.map((member) {
                return DropdownMenuItem<_EquipmentMemberOption>(
                  value: member,
                  child: Text(member.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => selectedMember = value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Katkesta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedMember),
                child: const Text('Väljasta'),
              ),
            ],
          );
        },
      ),
    );

    if (member == null) return;

    try {
      await _equipmentService.issueOrganizationEquipment(
        equipmentId: item.id,
        organizationId: widget.organizationId,
        assignedToUserId: member.userId,
        assignedToName: member.label,
        issuedBy: widget.currentUid,
        canManageOrganizationEquipment: widget.canManageEquipment,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustus väljastatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustust ei saanud väljastada.')),
      );
    }
  }

  Future<void> _markEquipmentReturned(EquipmentModel item) async {
    if (!_canManageOrganizationAssignment(item)) return;

    final shouldReturn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Märgi tagastatuks'),
        content: Text('Märkida "${item.name}" tagastatuks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Katkesta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Märgi tagastatuks'),
          ),
        ],
      ),
    );

    if (shouldReturn != true) return;

    try {
      await _equipmentService.returnOrganizationEquipment(
        equipmentId: item.id,
        organizationId: widget.organizationId,
        returnedBy: widget.currentUid,
        canManageOrganizationEquipment: widget.canManageEquipment,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustus märgitud tagastatuks.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustust ei saanud tagastada.')),
      );
    }
  }

  Future<List<_EquipmentMemberOption>> _loadIssueMemberOptions() async {
    final memberships = await _membershipService
        .loadActiveMembershipsForOrganization(widget.organizationId.trim());
    final members = await Future.wait(
      memberships.map((membershipDoc) async {
        final membership = membershipDoc.data();
        final userId = _stringValue(membership['userId']);
        if (userId.isEmpty) return null;

        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final userData = userSnapshot.data() ?? <String, dynamic>{};
        final name = _firstString([
          userData['name'],
          membership['name'],
          membership['displayName'],
        ]);
        final email = _firstString([
          userData['email'],
          membership['email'],
          userData['normalizedEmail'],
          membership['normalizedEmail'],
        ]);
        final label = name.isNotEmpty
            ? name
            : (email.isNotEmpty ? email : userId);

        return _EquipmentMemberOption(
          userId: userId,
          label: label,
        );
      }),
    );

    final options = members.whereType<_EquipmentMemberOption>().toList();
    options.sort((a, b) => a.label.compareTo(b.label));
    return options;
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
          final visible = equipment.where((item) {
            final matchesTab = item.appearsIn(_view, widget.currentUid);
            return matchesTab && (_category == null || item.category == _category) &&
              '${item.name} ${item.assignedToName} ${item.location}'.toLowerCase().contains(_search);
          }).toList();
          final title = switch (_view) {'warehouse' => 'Ladu', 'mine' => 'Minu varustus', 'members' => 'Liikmete varustus', _ => 'Ühingu varustus'};
          return ListView(padding: const EdgeInsets.all(16), children: [
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Otsi varustust või saajat'),
              onChanged: (value) => setState(() => _search = value.trim().toLowerCase())),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final entry in const {'shared': 'Ühingu varustus', 'warehouse': 'Ladu', 'mine': 'Minu varustus', 'members': 'Liikmete varustus'}.entries)
                ChoiceChip(label: Text(entry.value), selected: _view == entry.key,
                  onSelected: (_) => setState(() => _view = entry.key)),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: _category ?? '', decoration: const InputDecoration(labelText: 'Kategooria'),
              items: [const DropdownMenuItem(value: '', child: Text('Kõik kategooriad')),
                for (final category in EquipmentCategory.values) DropdownMenuItem(value: category, child: Text(_equipmentCategoryLabel(category)))],
              onChanged: (value) => setState(() => _category = value == '' ? null : value)),
            const SizedBox(height: 16),
            _buildEquipmentSection(title: title, equipment: visible, emptyText: 'Varustust ei leitud.',
              addLabel: _view == 'mine' ? 'Lisa isiklik varustus' : 'Lisa varustus',
              helperText: _view == 'warehouse' ? 'Laos olevad esemed saab väljastada liikmele. Tagastatud ese tuleb tagasi lattu.' :
                _view == 'mine' ? 'Sulle väljastatud ja sinu isiklik varustus.' : null,
              onAdd: _view == 'members' || (_view != 'mine' && !widget.canManageEquipment) ? null :
                () => _showAddEquipmentDialog(scope: _view == 'mine' ? EquipmentScope.personal : EquipmentScope.organization)),
          ]);
        },
      ),
    );
  }

  Future<void> _moveEquipment(EquipmentModel item, String storage) async {
    try {
      await _equipmentService.updateEquipment(equipmentId: item.id,
        organizationId: widget.organizationId, name: item.name, category: item.category,
        status: item.status, location: item.location, nextMaintenanceDate: item.nextMaintenanceDate,
        note: item.note, updatedBy: widget.currentUid, canManageOrganizationEquipment: widget.canManageEquipment, storage: storage);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Varustuse liigutamine ebaõnnestus.')));
    }
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
        if (equipment.isNotEmpty) _buildEquipmentAttentionNotice(equipment),
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
    final assignmentStatus = _assignmentStatusLabel(item);
    final subtitleParts = [
      _equipmentCategoryLabel(item.category),
      ?assignmentStatus,
      if (item.location.isNotEmpty) item.location,
      if (item.nextMaintenanceDate.isNotEmpty)
        'Hooldus ${item.nextMaintenanceDate}',
      ?maintenanceStatus,
      if (item.note.isNotEmpty) item.note,
    ];

    return EquipmentItemCard(name: item.name, description: subtitleParts.join(' · '),
      statusLabel: _equipmentStatusLabel(item.status), statusType: _equipmentStatusBadgeType(item.status),
      statusIcon: _equipmentStatusIcon(item.status), actions: _buildEquipmentActions(item));
  }

  Widget? _buildEquipmentActions(EquipmentModel item) {
    if (!_canEditEquipment(item)) return null;

    if (item.isPersonal) {
      return IconButton(
        icon: const Icon(Icons.edit),
        tooltip: 'Muuda varustust',
        onPressed: () => _showEditEquipmentDialog(item),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Varustuse toimingud',
      onSelected: (value) {
        if (value == 'edit') {
          _showEditEquipmentDialog(item);
        } else if (value == 'issue') {
          _showIssueEquipmentDialog(item);
        } else if (value == 'warehouse' || value == 'shared') {
          _moveEquipment(item, value);
        } else if (value == 'return') {
          _markEquipmentReturned(item);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('Muuda varustust'),
        ),
        if (!item.isAssigned)
          PopupMenuItem<String>(value: item.storage == 'warehouse' ? 'shared' : 'warehouse',
            child: Text(item.storage == 'warehouse' ? 'Liiguta ühiskasutusse' : 'Liiguta lattu')),
        if (!item.isAssigned)
          const PopupMenuItem<String>(
            value: 'issue',
            child: Text('Väljasta liikmele'),
          ),
        if (item.isAssigned)
          const PopupMenuItem<String>(
            value: 'return',
            child: Text('Märgi tagastatuks'),
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

  String? _assignmentStatusLabel(EquipmentModel item) {
    if (item.isPersonal) return item.ownerUserId == widget.currentUid ? 'Isiklik varustus' : 'Liikme isiklik varustus';
    if (!item.isAssigned) return 'Saadaval';
    if (item.assignedToUserId == widget.currentUid) return 'Väljastatud mulle';

    final assignedToName = item.assignedToName.trim();
    return assignedToName.isEmpty
        ? 'Väljastatud: ${item.assignedToUserId}'
        : 'Väljastatud: $assignedToName';
  }

  String _firstString(List<Object?> values) {
    for (final value in values) {
      final text = _stringValue(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _stringValue(Object? value) {
    return value is String ? value.trim() : '';
  }

  String _equipmentCategoryLabel(String category) => EquipmentCategory.label(category);

  bool _canEditEquipment(EquipmentModel item) {
    if (item.isPersonal) {
      return item.ownerUserId == widget.currentUid ||
          widget.canManageEquipment;
    }
    return widget.canManageEquipment;
  }

  bool _canManageOrganizationAssignment(EquipmentModel item) {
    return widget.canManageEquipment && !item.isPersonal;
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

class _EquipmentMemberOption {
  const _EquipmentMemberOption({
    required this.userId,
    required this.label,
  });

  final String userId;
  final String label;
}
