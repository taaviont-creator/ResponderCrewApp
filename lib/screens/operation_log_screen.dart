import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/callout_model.dart';
import '../models/operation_log_model.dart';
import '../services/callout_service.dart';
import '../services/operation_log_service.dart';
import '../widgets/operation_log_timeline_view.dart';

class _EventLocation {
  const _EventLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

class OperationLogScreen extends StatefulWidget {
  const OperationLogScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canViewCalloutResponseSummary,
    required this.canStartOperationLog,
    this.initialLogId,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final bool canViewCalloutResponseSummary;
  final bool canStartOperationLog;
  /// When provided, the matching log card is initially expanded so that
  /// navigating from a callout detail opens the linked log directly.
  final String? initialLogId;

  @override
  State<OperationLogScreen> createState() => _OperationLogScreenState();
}

class _OperationLogScreenState extends State<OperationLogScreen> {
  final _operationLogService = OperationLogService();
  final Set<String> _visibleActiveLogIds = <String>{};
  bool _wakelockEnabled = false;

  void _handleVisibleActiveLogChanged(String logId, bool isVisibleActive) {
    if (!mounted) return;

    if (isVisibleActive) {
      _visibleActiveLogIds.add(logId);
    } else {
      _visibleActiveLogIds.remove(logId);
    }

    _syncWakelock();
  }

  void _syncWakelock() {
    final shouldEnable = _visibleActiveLogIds.isNotEmpty;
    if (_wakelockEnabled == shouldEnable) return;

    _wakelockEnabled = shouldEnable;
    unawaited(
      WakelockPlus.toggle(enable: shouldEnable).catchError((Object _) {}),
    );
  }

  Future<void> _updateStatus(
    OperationLogModel log,
    String status,
  ) async {
    try {
      final location = await _tryGetCurrentEventLocation();
      await _operationLogService.updateLogStatus(
        operationLogId: log.id,
        organizationId: widget.organizationId,
        status: status,
        updatedBy: widget.currentUid,
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracyMeters: location?.accuracyMeters,
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
      final location = await _tryGetCurrentEventLocation();
      await _operationLogService.addManualEvent(
        operationLogId: log.id,
        organizationId: widget.organizationId,
        title: title,
        createdBy: widget.currentUid,
        type: OperationLogEventType.quickAction,
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracyMeters: location?.accuracyMeters,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kiirtegevuse lisamine ebaõnnestus: $e')),
      );
    }
  }

  Future<void> _showOtherQuickActionDialog(OperationLogModel log) async {
    if (!widget.canStartOperationLog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sul puudub õigus seda toimingut teha')),
      );
      return;
    }

    final descriptionController = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lisa muu sündmus'),
        content: TextField(
          controller: descriptionController,
          decoration: const InputDecoration(labelText: 'Kirjeldus'),
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

    final description = descriptionController.text.trim();
    if (shouldSave != true || description.isEmpty) return;

    await _addQuickAction(log, 'Muu: $description');
  }

  Future<_EventLocation?> _tryGetCurrentEventLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 3),
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      return _EventLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleQuickAction(OperationLogModel log, String action) async {
    switch (action) {
      case 'Sõitsin välja':
        await _updateStatus(log, OperationLogStatus.enRoute);
        break;
      case 'Kohal':
        await _updateStatus(log, OperationLogStatus.onScene);
        break;
      case 'Otsing algas':
        await _updateStatus(log, OperationLogStatus.inProgress);
        break;
      case 'Kannatanu leitud':
        await _addQuickAction(log, 'Kannatanu leitud');
        break;
      case 'Sündmus lõpetatud':
        await _updateStatus(log, OperationLogStatus.completed);
        break;
      case 'Tagasi':
        await _addQuickAction(log, 'Tagasi');
        break;
      case 'Baasis':
        await _updateStatus(log, OperationLogStatus.returnedToBase);
        break;
      case 'Muu':
        await _showOtherQuickActionDialog(log);
        break;
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

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uus operatsioonilogi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Pealkiri'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Kirjeldus (valikuline)',
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
      ),
    );

    if (shouldCreate != true) return;

    try {
      await _operationLogService.addLog(
        organizationId: widget.organizationId,
        createdBy: widget.currentUid,
        createdByName: widget.currentUserName,
        type: OperationLogType.other,
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
        SnackBar(content: Text('Logikande lisamine ebaõnnestus: $e')),
      );
    }
  }

  @override
  void dispose() {
    _visibleActiveLogIds.clear();
    if (_wakelockEnabled) {
      unawaited(WakelockPlus.disable().catchError((Object _) {}));
    }
    super.dispose();
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

          final logs = _sortOperationLogsForUse(
            snapshot.data ?? const <OperationLogModel>[],
            focusedLogId: widget.initialLogId,
          );
          if (logs.isEmpty) {
            return const Center(child: Text('Logikandeid ei ole veel lisatud'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _OperationLogCard(
                key: ValueKey(log.id),
                log: log,
                organizationId: widget.organizationId,
                canStartOperationLog: widget.canStartOperationLog,
                canViewCalloutResponseSummary:
                    widget.canViewCalloutResponseSummary,
                isFocusedOperationLog: log.id == widget.initialLogId,
                initiallyExpanded: log.id == widget.initialLogId ||
                    (widget.initialLogId == null &&
                        index == 0 &&
                        _isActiveOperationLog(log.status)),
                onUpdateStatus: _updateStatus,
                onShowAddManualEventDialog: _showAddManualEventDialog,
                onHandleQuickAction: _handleQuickAction,
                onShowFinalSummaryDialog: _showFinalSummaryDialog,
                onVisibleActiveChanged: _handleVisibleActiveLogChanged,
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-card widget — owns expand/collapse state and mounts the timeline stream
// only while the card is expanded.
// ---------------------------------------------------------------------------

class _OperationLogCard extends StatefulWidget {
  const _OperationLogCard({
    super.key,
    required this.log,
    required this.organizationId,
    required this.canStartOperationLog,
    required this.canViewCalloutResponseSummary,
    required this.onUpdateStatus,
    required this.onShowAddManualEventDialog,
    required this.onHandleQuickAction,
    required this.onShowFinalSummaryDialog,
    required this.onVisibleActiveChanged,
    this.isFocusedOperationLog = false,
    this.initiallyExpanded = false,
  });

  final OperationLogModel log;
  final String organizationId;
  final bool canStartOperationLog;
  final bool canViewCalloutResponseSummary;
  final bool isFocusedOperationLog;
  final bool initiallyExpanded;
  final Future<void> Function(OperationLogModel, String) onUpdateStatus;
  final Future<void> Function(OperationLogModel) onShowAddManualEventDialog;
  final Future<void> Function(OperationLogModel, String) onHandleQuickAction;
  final Future<void> Function(OperationLogModel) onShowFinalSummaryDialog;
  final void Function(String, bool) onVisibleActiveChanged;

  @override
  State<_OperationLogCard> createState() => _OperationLogCardState();
}

class _OperationLogCardState extends State<_OperationLogCard> {
  static const _quickActions = [
    'Sõitsin välja',
    'Kohal',
    'Otsing algas',
    'Kannatanu leitud',
    'Sündmus lõpetatud',
    'Tagasi',
    'Baasis',
    'Muu',
  ];

  final _calloutService = CalloutService();
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _notifyVisibleActiveChanged();
  }

  @override
  void didUpdateWidget(covariant _OperationLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.status != widget.log.status) {
      _notifyVisibleActiveChanged();
    }
  }

  @override
  void dispose() {
    widget.onVisibleActiveChanged(widget.log.id, false);
    super.dispose();
  }

  void _notifyVisibleActiveChanged() {
    widget.onVisibleActiveChanged(
      widget.log.id,
      _expanded && _isActiveOperationLog(widget.log.status),
    );
  }

  bool _isQuickActionEnabled(OperationLogModel log, String action) {
    if (!widget.canStartOperationLog) return false;

    final normalizedStatus = OperationLogStatus.normalize(log.status);
    if (normalizedStatus == OperationLogStatus.returnedToBase) {
      return false;
    }

    switch (action) {
      case 'Sõitsin välja':
        return normalizedStatus == OperationLogStatus.open;
      case 'Kohal':
        return normalizedStatus == OperationLogStatus.open ||
            normalizedStatus == OperationLogStatus.enRoute;
      case 'Otsing algas':
        return normalizedStatus == OperationLogStatus.onScene;
      case 'Kannatanu leitud':
        return normalizedStatus == OperationLogStatus.onScene ||
            normalizedStatus == OperationLogStatus.inProgress;
      case 'Sündmus lõpetatud':
        return normalizedStatus != OperationLogStatus.completed &&
            normalizedStatus != OperationLogStatus.returnedToBase;
      case 'Tagasi':
      case 'Baasis':
        return normalizedStatus == OperationLogStatus.completed;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final isActive = _isActiveOperationLog(log.status);
    final isEmphasized = isActive || widget.isFocusedOperationLog;
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleParts = [
      _operationLogStatusLabel(log.status),
      _operationLogTypeLabel(log.type),
      if (log.createdByName.isNotEmpty) log.createdByName,
      if (log.timestamp != null) _shortDateTime(log.timestamp!),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEmphasized
            ? colorScheme.primaryContainer.withValues(alpha: 0.18)
            : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isEmphasized
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isEmphasized ? 4 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: isEmphasized ? 8 : 4),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 12,
          ),
          title: Text(
            log.title,
            style: isEmphasized
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
          subtitle: Text(
            log.description.isEmpty
                ? subtitleParts.join(' - ')
                : '${subtitleParts.join(' - ')}\n${log.description}',
          ),
          trailing: Chip(
            label: Text(_operationLogStatusLabel(log.status)),
            visualDensity: VisualDensity.compact,
            backgroundColor: isEmphasized ? colorScheme.primaryContainer : null,
          ),
          onExpansionChanged: (expanded) {
            setState(() => _expanded = expanded);
            _notifyVisibleActiveChanged();
          },
          children: _expanded ? _buildExpandedChildren(log) : [],
        ),
      ),
    );
  }

  List<Widget> _buildExpandedChildren(OperationLogModel log) {
    return [
      _buildStatusSummary(log),
      if (widget.canViewCalloutResponseSummary && log.calloutId != null)
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
            onPressed: () => widget.onShowFinalSummaryDialog(log),
            icon: const Icon(Icons.summarize_outlined),
            label: Text(
              log.summary.isEmpty
                  ? 'Lisa lõppkokkuvõte'
                  : 'Muuda lõppkokkuvõtet',
            ),
          ),
        ),
      if (_isActiveOperationLog(log.status) && widget.canStartOperationLog) ...[
        _buildOperationalModeHint(context),
        const SizedBox(height: 12),
      ],
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Kiirtegevused',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 4),
      LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = constraints.maxWidth >= 360
              ? (constraints.maxWidth - 8) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickActions.map((title) {
              final enabled = _isQuickActionEnabled(log, title);
              return SizedBox(
                width: buttonWidth,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: enabled
                      ? () => widget.onHandleQuickAction(log, title)
                      : null,
                  icon: Icon(_quickActionIcon(title), size: 20),
                  label: Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton.icon(
            onPressed: widget.canStartOperationLog
                ? () => widget.onShowAddManualEventDialog(log)
                : null,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Lisa märge'),
          ),
        ),
      ),
      OperationLogTimelineView(
        operationLogId: log.id,
        organizationId: widget.organizationId,
      ),
    ];
  }

  Widget _buildStatusSummary(OperationLogModel log) {
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
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalModeHint(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.28),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bolt_outlined,
            color: colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktiivne operatsioonilogi',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kasuta allolevaid kiirtegevusi sündmuse käigu märkimiseks.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tegevused salvestatakse ajajoonele.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _quickActionIcon(String action) {
    switch (action) {
      case 'Sõitsin välja':
        return Icons.directions_boat_outlined;
      case 'Kohal':
        return Icons.place_outlined;
      case 'Otsing algas':
        return Icons.search;
      case 'Kannatanu leitud':
        return Icons.person_outline;
      case 'Sündmus lõpetatud':
        return Icons.check_circle_outline;
      case 'Tagasi':
        return Icons.keyboard_return;
      case 'Baasis':
        return Icons.home_outlined;
      case 'Muu':
        return Icons.more_horiz;
      default:
        return Icons.bolt;
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
}

// ---------------------------------------------------------------------------
// Top-level private helpers — pure functions, no state or context access.
// Shared by _OperationLogScreenState (dialog labels) and _OperationLogCard.
// ---------------------------------------------------------------------------

List<OperationLogModel> _sortOperationLogsForUse(
  List<OperationLogModel> logs, {
  String? focusedLogId,
}) {
  final sorted = List<OperationLogModel>.of(logs);
  sorted.sort((a, b) {
    final focusOrder = _focusedLogSortOrder(a.id, focusedLogId)
        .compareTo(_focusedLogSortOrder(b.id, focusedLogId));
    if (focusOrder != 0) return focusOrder;

    final statusOrder =
        _operationLogStatusSortOrder(a.status)
            .compareTo(_operationLogStatusSortOrder(b.status));
    if (statusOrder != 0) return statusOrder;

    final aTime = _operationLogSortTime(a);
    final bTime = _operationLogSortTime(b);
    return bTime.compareTo(aTime);
  });
  return sorted;
}

int _focusedLogSortOrder(String logId, String? focusedLogId) {
  return focusedLogId != null && logId == focusedLogId ? 0 : 1;
}

bool _isActiveOperationLog(String status) {
  return _operationLogStatusSortOrder(status) == 0;
}

int _operationLogStatusSortOrder(String status) {
  switch (OperationLogStatus.normalize(status)) {
    case OperationLogStatus.open:
    case OperationLogStatus.enRoute:
    case OperationLogStatus.onScene:
    case OperationLogStatus.inProgress:
      return 0;
    case OperationLogStatus.completed:
      return 1;
    case OperationLogStatus.returnedToBase:
      return 2;
    default:
      return 0;
  }
}

DateTime _operationLogSortTime(OperationLogModel log) {
  return log.timestamp ??
      log.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
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

String _operationLogTypeLabel(String type) {
  switch (type) {
    case OperationLogType.departure:
      return 'Väljasõit';
    case OperationLogType.arrivalOnScene:
      return 'Jõudmine kohale';
    case OperationLogType.searchStarted:
      return 'Otsing algas';
    case OperationLogType.searchEnded:
      return 'Otsing lõpetatud';
    case OperationLogType.patientRecovered:
      return 'Kannatanu leitud';
    case OperationLogType.towingStarted:
      return 'Pukseerimine algas';
    case OperationLogType.towingEnded:
      return 'Pukseerimine lõpetatud';
    case OperationLogType.returnedToBase:
      return 'Baasi tagasi';
    case OperationLogType.other:
      return 'Muu';
    default:
      return 'Märge';
  }
}

String _shortDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  final date = '${twoDigits(value.day)}.${twoDigits(value.month)}';
  final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  return '$date $time';
}
