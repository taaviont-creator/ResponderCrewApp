import 'package:flutter/material.dart';

import '../models/callout_model.dart';
import '../models/operation_log_model.dart';
import '../services/callout_service.dart';
import '../services/operation_log_service.dart';

class OperationLogScreen extends StatefulWidget {
  const OperationLogScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canViewCalloutResponseSummary,
    required this.canStartOperationLog,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final bool canViewCalloutResponseSummary;
  final bool canStartOperationLog;

  @override
  State<OperationLogScreen> createState() => _OperationLogScreenState();
}

class _OperationLogScreenState extends State<OperationLogScreen> {
  final _calloutService = CalloutService();
  final _operationLogService = OperationLogService();

  static const _quickActions = [
    'Teel',
    'Kohal',
    'Otsing algas',
    'Kannatanu leitud',
    'Sündmus lõpetatud',
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
    if (!widget.canStartOperationLog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sul puudub õigus seda toimingut teha')),
      );
      return;
    }

    final noteController = TextEditingController();
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lisa märge'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Märkus'),
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
            child: const Text('Salvesta märge'),
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
    if (!widget.canStartOperationLog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sul puudub õigus seda toimingut teha')),
      );
      return;
    }

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

  Future<void> _handleQuickAction(OperationLogModel log, String action) async {
    switch (action) {
      case 'Teel':
        await _updateStatus(log, OperationLogStatus.enRoute);
        break;
      case 'Kohal':
        await _updateStatus(log, OperationLogStatus.onScene);
        break;
      case 'Otsing algas':
        await _addQuickAction(log, 'Otsing algas');
        break;
      case 'Kannatanu leitud':
        await _addQuickAction(log, 'Kannatanu leitud');
        break;
      case 'Sündmus lõpetatud':
        await _updateStatus(log, OperationLogStatus.completed);
        break;
    }
  }

  bool _isQuickActionEnabled(OperationLogModel log, String action) {
    if (!widget.canStartOperationLog) return false;

    final normalizedStatus = OperationLogStatus.normalize(log.status);
    if (normalizedStatus == OperationLogStatus.completed ||
        normalizedStatus == OperationLogStatus.returnedToBase) {
      return false;
    }

    switch (action) {
      case 'Teel':
        return normalizedStatus == OperationLogStatus.open;
      case 'Kohal':
        return normalizedStatus == OperationLogStatus.open ||
            normalizedStatus == OperationLogStatus.enRoute;
      case 'Sündmus lõpetatud':
        return normalizedStatus != OperationLogStatus.completed &&
            normalizedStatus != OperationLogStatus.returnedToBase;
      default:
        return true;
    }
  }

  Future<void> _showFinalSummaryDialog(OperationLogModel log) async {
    final summaryController = TextEditingController(text: log.summary);
    final outcomeController = TextEditingController(text: log.outcome);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lõppkokkuvõte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: summaryController,
                decoration: const InputDecoration(labelText: 'Lõppkokkuvõte'),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: outcomeController,
                decoration: const InputDecoration(labelText: 'Tulemus'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tühista'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvesta kokkuvõte'),
          ),
        ],
      ),
    );

    if (shouldSave != true) return;

    try {
      await _operationLogService.updateFinalSummary(
        operationLogId: log.id,
        organizationId: widget.organizationId,
        summary: summaryController.text,
        outcome: outcomeController.text,
        completedBy: widget.currentUid,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lõppkokkuvõtte salvestamine ebaõnnestus: $e')),
      );
    }
  }

  Future<void> _showAddOperationLogDialog() async {
    if (!widget.canStartOperationLog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sul puudub õigus seda toimingut teha')),
      );
      return;
    }

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
      floatingActionButton: widget.canStartOperationLog
          ? FloatingActionButton(
              onPressed: _showAddOperationLogDialog,
              child: const Icon(Icons.add),
            )
          : null,
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
                trailing: Chip(
                  label: Text(_operationLogStatusLabel(log.status)),
                  visualDensity: VisualDensity.compact,
                ),
                children: [
                  _buildStatusFlowControls(log),
                  if (widget.canViewCalloutResponseSummary &&
                      log.calloutId != null)
                    _buildCalloutResponseSummary(log.calloutId!),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Lõppkokkuvõte',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      log.summary.isEmpty ? 'Kokkuvõte puudub' : log.summary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tulemus',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      log.outcome.isEmpty ? 'Tulemus puudub' : log.outcome,
                    ),
                  ),
                  if (log.status == OperationLogStatus.completed &&
                      widget.canStartOperationLog)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showFinalSummaryDialog(log),
                        icon: const Icon(Icons.summarize_outlined),
                        label: Text(
                          log.summary.isEmpty
                              ? 'Lisa lõppkokkuvõte'
                              : 'Muuda lõppkokkuvõtet',
                        ),
                      ),
                    ),
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
                        final enabled = _isQuickActionEnabled(log, title);
                        return ActionChip(
                          label: Text(title),
                          onPressed: enabled
                              ? () => _handleQuickAction(log, title)
                              : null,
                        );
                      }).toList(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.canStartOperationLog
                          ? () => _showAddManualEventDialog(log)
                          : null,
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
                        return const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Märkmed',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text('Märkmeid pole lisatud.'),
                            SizedBox(height: 12),
                            Text(
                              'Ajajoon',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text('Sündmuste ajalugu puudub.'),
                          ],
                        );
                      }

                      final notes = events
                          .where((event) =>
                              event.type == OperationLogEventType.manualNote)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Märkmed',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (notes.isEmpty)
                            const Text('Märkmeid pole lisatud.')
                          else
                            ...notes.map(_buildOperationLogEventTile),
                          const SizedBox(height: 12),
                          const Text(
                            'Ajajoon',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ...events.map(_buildOperationLogEventTile),
                        ],
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

  Widget _buildOperationLogEventTile(OperationLogEventModel event) {
    final title = event.type == OperationLogEventType.manualNote &&
            event.text.isNotEmpty
        ? event.text
        : event.title;
    final subtitleLines = [
      if (event.type == OperationLogEventType.manualNote) 'Käsitsi märge',
      if (event.description.isNotEmpty) event.description,
      if (event.createdAt != null) _shortDateTime(event.createdAt!),
    ];

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_operationLogEventIcon(event.type)),
      title: Text(title),
      subtitle: subtitleLines.isEmpty ? null : Text(subtitleLines.join('\n')),
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

  Widget _buildStatusFlowControls(OperationLogModel log) {
    final nextStatus = _nextOperationLogStatus(log.status);
    final canUpdateStatus = widget.canStartOperationLog && nextStatus != null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: const Icon(Icons.flag_outlined, size: 18),
              label: Text('Staatus: ${_operationLogStatusLabel(log.status)}'),
              visualDensity: VisualDensity.compact,
            ),
            if (canUpdateStatus)
              OutlinedButton.icon(
                onPressed: () => _updateStatus(log, nextStatus),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  'Märgi: ${_operationLogStatusLabel(nextStatus)}',
                ),
              )
            else if (nextStatus == null)
              const Text('Staatuse voog on lõpetatud')
            else
              const Text('Sul puudub õigus staatust muuta'),
          ],
        ),
      ),
    );
  }

  String? _nextOperationLogStatus(String status) {
    switch (OperationLogStatus.normalize(status)) {
      case OperationLogStatus.open:
        return OperationLogStatus.enRoute;
      case OperationLogStatus.enRoute:
        return OperationLogStatus.onScene;
      case OperationLogStatus.onScene:
        return OperationLogStatus.inProgress;
      case OperationLogStatus.inProgress:
        return OperationLogStatus.completed;
      case OperationLogStatus.completed:
        return OperationLogStatus.returnedToBase;
      default:
        return null;
    }
  }

  Widget _buildCalloutResponseSummary(String calloutId) {
    return StreamBuilder<CalloutResponseDetails>(
      stream: _calloutService.streamCalloutResponseDetails(
        calloutId: calloutId,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final details = snapshot.data;
        if (details == null) return const SizedBox.shrink();
        final summary = details.summary;

        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reageerijad',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('Tuleb: ${summary.responding}'),
                    Text('Hilineb: ${summary.delayed}'),
                    Text('Ei saa tulla: ${summary.unavailable}'),
                    Text('Vastamata: ${summary.noResponse}'),
                    Text('Kokku vastanud: ${summary.totalResponded}'),
                  ],
                ),
                if (summary.totalResponded == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Vastuseid pole veel'),
                  ),
                _buildResponseGroup('Tuleb', details.responding),
                _buildResponseGroup(
                  'Hilineb',
                  details.delayed,
                  showDelay: true,
                ),
                _buildResponseGroup('Ei saa tulla', details.unavailable),
                _buildResponseGroup('Vastamata', details.noResponse),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponseGroup(
    String label,
    List<CalloutResponseMember> members, {
    bool showDelay = false,
  }) {
    final memberLabels = members.map((member) {
      if (showDelay && member.responseMinutes != null) {
        return '${member.displayName} (${member.responseMinutes} min)';
      }
      return member.displayName;
    }).join(', ');

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$label: ${memberLabels.isEmpty ? '-' : memberLabels}'),
    );
  }

  String _operationLogStatusLabel(String status) {
    const labels = {
      OperationLogStatus.open: 'Avatud',
      OperationLogStatus.enRoute: 'Teel',
      OperationLogStatus.onScene: 'Kohal',
      OperationLogStatus.inProgress: 'Tegevuses',
      OperationLogStatus.completed: 'Lõpetatud',
      OperationLogStatus.returnedToBase: 'Baasis tagasi',
    };
    final label = labels[OperationLogStatus.normalize(status)];
    if (label != null) return label;

    switch (OperationLogStatus.normalize(status)) {
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
      case OperationLogEventType.summarySaved:
        return Icons.summarize_outlined;
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
