import 'package:flutter/material.dart';

import '../models/equipment_model.dart';
import '../services/equipment_service.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageEquipment,
  });

  final String organizationId;
  final String currentUid;
  final bool canManageEquipment;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final _equipmentService = EquipmentService();

  Future<void> _showAddEquipmentDialog() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final noteController = TextEditingController();
    var selectedCategory = EquipmentCategory.other;
    var selectedStatus = EquipmentStatus.ok;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Lisa varustus'),
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
        name: nameController.text,
        category: selectedCategory,
        status: selectedStatus,
        location: locationController.text,
        note: noteController.text,
        createdBy: widget.currentUid,
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Varustus'),
      ),
      floatingActionButton: widget.canManageEquipment
          ? FloatingActionButton(
              onPressed: _showAddEquipmentDialog,
              child: const Icon(Icons.add),
            )
          : null,
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
          if (equipment.isEmpty) {
            return const Center(child: Text('Varustust ei ole veel lisatud'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: equipment.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = equipment[index];
              final subtitleParts = [
                _equipmentCategoryLabel(item.category),
                _equipmentStatusLabel(item.status),
                if (item.location.isNotEmpty) item.location,
                if (item.note.isNotEmpty) item.note,
              ];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text(subtitleParts.join(' - ')),
              );
            },
          );
        },
      ),
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
}
