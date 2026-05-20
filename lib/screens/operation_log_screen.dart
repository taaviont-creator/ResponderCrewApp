import 'package:flutter/material.dart';

import '../models/operation_log_model.dart';
import '../services/operation_log_service.dart';

class OperationLogScreen extends StatefulWidget {
  const OperationLogScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;

  @override
  State<OperationLogScreen> createState() => _OperationLogScreenState();
}

class _OperationLogScreenState extends State<OperationLogScreen> {
  final _operationLogService = OperationLogService();

  Future<void> _showAddOperationLogDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedType = OperationLogType.note;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Lisa logikanne'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Tuup'),
                    items: OperationLogType.values.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(_operationLogTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Pealkiri'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Kirjeldus / markus',
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
                child: const Text('Lisa'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true) return;

    try {
      await _operationLogService.addLog(
        organizationId: widget.organizationId,
        createdBy: widget.currentUid,
        createdByName: widget.currentUserName,
        type: selectedType,
        title: titleController.text,
        description: descriptionController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logikanne lisatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logikande lisamine ebaonnestus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operatsioonilogi'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOperationLogDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<OperationLogModel>>(
        stream: _operationLogService.streamOrganizationLogs(
          organizationId: widget.organizationId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Logi laadimine ebaonnestus: ${snapshot.error}'),
            );
          }

          final logs = snapshot.data ?? const <OperationLogModel>[];
          if (logs.isEmpty) {
            return const Center(child: Text('Logikandeid ei ole veel lisatud'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              final subtitleParts = [
                _operationLogTypeLabel(log.type),
                if (log.createdByName.isNotEmpty) log.createdByName,
                if (log.timestamp != null) _shortDateTime(log.timestamp!),
              ];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(log.title),
                subtitle: Text(
                  log.description.isEmpty
                      ? subtitleParts.join(' - ')
                      : '${subtitleParts.join(' - ')}\n${log.description}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _operationLogTypeLabel(String type) {
    switch (type) {
      case OperationLogType.departure:
        return 'Departure';
      case OperationLogType.arrivalOnScene:
        return 'Arrival on scene';
      case OperationLogType.searchStarted:
        return 'Search started';
      case OperationLogType.searchEnded:
        return 'Search ended';
      case OperationLogType.patientRecovered:
        return 'Patient recovered';
      case OperationLogType.towingStarted:
        return 'Towing started';
      case OperationLogType.towingEnded:
        return 'Towing ended';
      case OperationLogType.returnedToBase:
        return 'Returned to base';
      case OperationLogType.other:
        return 'Other';
      default:
        return 'Note';
    }
  }

  String _shortDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    final date = '${twoDigits(value.day)}.${twoDigits(value.month)}';
    final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
    return '$date $time';
  }
}
