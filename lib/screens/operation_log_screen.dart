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

  static const _quickActions = [
    'Otsing alustatud',
    'Kannatanu leitud',
    'Esmaabi antud',
    'JRCC teavitatud',
    'Otsinguala laiendatud',
    'Pukseerimine alustatud',
    'Operatsioon lõpetatud',
  ];

  Future<void> _updateStatus(
    OperationLogModel log,
    String status,
  ) async {
    try {
      await _operationLogService.updateLogStatus(
        operationLogId: log.id,
        organizationId: widget.organizationId,
        status: status,
        updatedBy: widget.currentUid,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Staatuse muutmine ebaõnnestus: $e')),
      );
    }
  }

  Future<void> _showAddManualEventDialog(OperationLogModel log) async {
    final noteController = TextEditingController();
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lisa märge'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Märge'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tühista'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvesta'),
          ),
        ],
      ),
    );

    if (shouldCreate != true) return;

    try {
      await _operationLogService.addManualEvent(
        operationLogId: log.id,
        organizationId: widget.organizationId,
        title: noteController.text,
        createdBy: widget.currentUid,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Märke lisamine ebaõnnestus: $e')),
      );
    }
  }

  Future<void> _addQuickAction(
    OperationLogModel log,
    String title,
  ) async {
    try {
      await _operationLogService.addManualEvent(
        operationLogId: log.id,
        organizationId: widget.organizationId,
        title: title,
        createdBy: widget.currentUid,
        type: OperationLogEventType.quickAction,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kiirtegevuse lisamine ebaõnnestus: $e')),
      );
    }
  }

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
                _operationLogStatusLabel(log.status),
                _operationLogTypeLabel(log.type),
                if (log.createdByName.isNotEmpty) log.createdByName,
                if (log.timestamp != null) _shortDateTime(log.timestamp!),
              ];

              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                title: Text(log.title),
                subtitle: Text(
                  log.description.isEmpty
                      ? subtitleParts.join(' - ')
                      : '${subtitleParts.join(' - ')}\n${log.description}',
                ),
                trailing: DropdownButton<String>(
                  value: log.status,
                  underline: const SizedBox.shrink(),
                  items: OperationLogStatus.values.map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(_operationLogStatusLabel(status)),
                    );
                  }).toList(),
                  onChanged: (status) {
                    if (status == null || status == log.status) return;
                    _updateStatus(log, status);
                  },
                ),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kiirtegevused',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _quickActions.map((title) {
                        return ActionChip(
                          label: Text(title),
                          onPressed: () => _addQuickAction(log, title),
                        );
                      }).toList(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showAddManualEventDialog(log),
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Lisa märge'),
                    ),
                  ),
                  StreamBuilder<List<OperationLogEventModel>>(
                    stream: _operationLogService.streamLogEvents(
                      operationLogId: log.id,
                      organizationId: widget.organizationId,
                    ),
                    builder: (context, eventSnapshot) {
                      if (eventSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (eventSnapshot.hasError) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Sündmuste ajaloo laadimine ebaõnnestus.'),
                        );
                      }

                      final events = eventSnapshot.data ??
                          const <OperationLogEventModel>[];
                      if (events.isEmpty) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Sündmuste ajalugu puudub.'),
                        );
                      }

                      return Column(
                        children: events.map((event) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_operationLogEventIcon(event.type)),
                            title: Text(event.title),
                            subtitle: event.createdAt == null
                                ? null
                                : Text(_shortDateTime(event.createdAt!)),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
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

  String _operationLogStatusLabel(String status) {
    switch (status) {
      case OperationLogStatus.departed:
        return 'Väljasõit';
      case OperationLogStatus.arrived:
        return 'Kohal';
      case OperationLogStatus.inProgress:
        return 'Tegevus käib';
      case OperationLogStatus.completed:
        return 'Lõpetatud';
      case OperationLogStatus.returnedToBase:
        return 'Tagasi baasis';
      default:
        return 'Loodud';
    }
  }

  IconData _operationLogEventIcon(String type) {
    switch (type) {
      case OperationLogEventType.quickAction:
        return Icons.bolt;
      case OperationLogEventType.manualNote:
        return Icons.notes;
      default:
        return Icons.history;
    }
  }

  String _shortDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    final date = '${twoDigits(value.day)}.${twoDigits(value.month)}';
    final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
    return '$date $time';
  }
}
