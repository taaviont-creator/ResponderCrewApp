import '../widgets/app_layout.dart';
import '../services/operation_log_access_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/callout_model.dart';
import '../models/operation_log_model.dart';
import '../services/callout_service.dart';
import '../services/operation_log_service.dart';
import '../services/wakelock_service.dart';
import '../widgets/operation_log_timeline_view.dart';
import 'operation_log_report_screen.dart';
import '../widgets/callout_participants_section.dart';
import '../widgets/operation_note_dialog.dart';
import '../widgets/operation_log_actions.dart';
import '../widgets/operation_log_access_panel.dart';

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
  final _wakelockService = WakelockService();
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
      _wakelockService.toggle(enable: shouldEnable).catchError((Object _) {}),
    );
  }

  Future<void> _updateStatus(OperationLogModel log, String status) async {
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
  }

  Future<void> _showAddManualEventDialog(OperationLogModel log) async {
    await showDialog<void>(
      context: context,
      builder: (_) => OperationNoteDialog(
        onSave: (text, occurredAt) => _operationLogService.addManualEvent(
          operationLogId: log.id,
          organizationId: widget.organizationId,
          title: text,
          createdBy: widget.currentUid,
          occurredAt: occurredAt,
        ),
      ),
    );
  }

  Future<void> _addQuickAction(OperationLogModel log, String title) async {
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
    if (!widget.canStartOperationLog || action == 'Sündmus lõpetatud') {
      await _addQuickAction(log, action);
      return;
    }
    switch (action) {
      case 'Väljasõit':
        await _updateStatus(log, OperationLogStatus.enRoute);
        break;
      case 'Sündmuskohal':
        await _updateStatus(log, OperationLogStatus.onScene);
        break;
      case 'Otsing algas':
        await _updateStatus(log, OperationLogStatus.inProgress);
        break;
      case 'Teade edastatud':
      case 'Pukseerimine alustatud':
        await _addQuickAction(log, action);
        break;
      case 'Kannatanu leitud':
        await _addQuickAction(log, 'Kannatanu leitud');
        break;
      case 'Sündmuskohal tegevused tehtud':
        await _updateStatus(log, OperationLogStatus.completed);
        break;
      case 'Tagasisõit':
        await _addQuickAction(log, 'Tagasisõit');
        break;
      case 'Tagasi baasis':
        await _updateStatus(log, OperationLogStatus.returnedToBase);
        break;
    }
  }

  Future<void> _showFinalSummaryDialog(OperationLogModel log) async {
    await showDialog<void>(
      context: context,
      builder: (_) => OperationSummaryDialog(
        summary: log.summary,
        outcome: log.outcome,
        onSave: (summary, outcome) => _operationLogService.updateFinalSummary(
          operationLogId: log.id,
          organizationId: widget.organizationId,
          summary: summary,
          outcome: outcome,
          completedBy: widget.currentUid,
        ),
      ),
    );
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
        title: const Text('Uus operatiivlogi'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logikanne lisatud')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logikande lisamine ebaõnnestus.')),
      );
    }
  }

  @override
  void dispose() {
    _visibleActiveLogIds.clear();
    if (_wakelockEnabled) {
      unawaited(_wakelockService.disable().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Operatiivlogi')),
      floatingActionButton: widget.canStartOperationLog
          ? FloatingActionButton.extended(
              onPressed: _showAddOperationLogDialog,
              icon: const Icon(Icons.add),
              label: const Text('Uus logi'),
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
            return Center(child: Text('Logi laadimine ebaõnnestus.'));
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
                currentUid: widget.currentUid,
                key: ValueKey(log.id),
                log: log,
                organizationId: widget.organizationId,
                canStartOperationLog: widget.canStartOperationLog,
                canViewCalloutResponseSummary:
                    widget.canViewCalloutResponseSummary,
                isFocusedOperationLog: log.id == widget.initialLogId,
                initiallyExpanded:
                    log.id == widget.initialLogId ||
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
    required this.currentUid,
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
  final String currentUid;
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
  final _calloutService = CalloutService();
  late bool _expanded;
  late final Stream<CalloutModel?>? _calloutStream =
      widget.log.calloutId == null
      ? null
      : _calloutService.streamCallout(
          calloutId: widget.log.calloutId!,
          organizationId: widget.organizationId,
        );
  StreamSubscription<CalloutModel?>? _calloutSubscription;
  Stream<bool> _participantAccess() => widget.log.calloutId == null
      ? Stream.value(false)
      : OperationLogAccessService().participantAccess(
          organizationId: widget.organizationId,
          userId: widget.currentUid,
          calloutId: widget.log.calloutId!,
        );
  bool _calloutClosed = false;
  bool _calloutReadFailed = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _calloutSubscription = _calloutStream?.listen(
      (callout) {
        if (!mounted) return;
        setState(() {
          _calloutClosed = callout?.status != CalloutStatus.active;
          _calloutReadFailed = false;
        });
        _notifyVisibleActiveChanged();
      },
      onError: (Object _) {
        if (mounted) setState(() => _calloutReadFailed = true);
      },
    );
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
    _calloutSubscription?.cancel();
    widget.onVisibleActiveChanged(widget.log.id, false);
    super.dispose();
  }

  void _notifyVisibleActiveChanged() {
    widget.onVisibleActiveChanged(
      widget.log.id,
      _expanded && !_calloutClosed && _isActiveOperationLog(widget.log.status),
    );
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
          onExpansionChanged: (expanded) {
            setState(() => _expanded = expanded);
            _notifyVisibleActiveChanged();
          },
          children: _expanded
              ? _buildExpandedChildren(log, calloutClosed: _calloutClosed)
              : [],
        ),
      ),
    );
  }

  List<Widget> _buildExpandedChildren(
    OperationLogModel log, {
    required bool calloutClosed,
  }) {
    final canSummarize =
        calloutClosed ||
        log.status == OperationLogStatus.completed ||
        log.status == OperationLogStatus.returnedToBase;
    final finished = calloutClosed || !_isActiveOperationLog(log.status);
    return [
      if (_calloutReadFailed)
        const Text(
          'Väljakutse oleku laadimine ebaõnnestus. Kontrolli ühendust.',
        ),
      if (finished)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Täienda lõpetatud väljakutse logi. Kommentaare, kokkuvõtet ja osalejaid saab lisada ka tagantjärele.',
          ),
        ),
      OperationLogAccessPanel(
        createStream: _participantAccess,
        builder: (context, access) {
          if (!widget.canStartOperationLog &&
              (finished || access.hasError || access.data != true)) {
            return Text(
              finished || log.calloutId == null
                  ? 'Logi on ainult vaatamiseks.'
                  : access.hasError
                  ? 'Logi lisamisõigust ei õnnestunud kontrollida.'
                  : 'Logi täitmiseks märgi väljakutsel „Tulen” või „Hilinen” või lase juhil osalemine kinnitada.',
            );
          }
          return OperationLogActions(
            status: calloutClosed
                ? OperationLogStatus.returnedToBase
                : log.status,
            appendOnly: !widget.canStartOperationLog,
            onAction: (title) => widget.onHandleQuickAction(log, title),
            onComment: () => widget.onShowAddManualEventDialog(log),
          );
        },
      ),
      const SizedBox(height: 16),
      ExpansionTile(
        key: ValueKey('completion-$canSummarize'),
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: canSummarize,
        title: const Text('Kokkuvõte ja osalejad'),
        subtitle: const Text('Täida sündmuse lõpus või hiljem'),
        children: [
          if (log.calloutId != null)
            CalloutParticipantsSection(
              key: ValueKey('${widget.organizationId}-${log.calloutId}'),
              organizationId: widget.organizationId,
              calloutId: log.calloutId!,
              currentUid: widget.currentUid,
            ),
          if (canSummarize) ..._buildFinalSummaryChildren(log),
          if (!canSummarize)
            const Text(
              'Lõppkokkuvõtte saad lisada pärast sündmuskohal tegevuste või väljakutse lõpetamist.',
            ),
        ],
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.receipt_long),
        label: const Text('Vaata logi väljavõtet'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OperationLogReportScreen(
              log: log,
              organizationId: widget.organizationId,
              logStream: OperationLogService().streamLog(
                organizationId: widget.organizationId,
                logId: log.id,
              ),
            ),
          ),
        ),
      ),
      OperationLogTimelineView(
        operationLogId: log.id,
        organizationId: widget.organizationId,
      ),
      if (widget.canViewCalloutResponseSummary && log.calloutId != null)
        ExpansionTile(
          title: const Text('Reageerimisvastused'),
          children: [_buildCalloutResponseSummary(log.calloutId!)],
        ),
    ];
  }

  List<Widget> _buildFinalSummaryChildren(OperationLogModel log) {
    return [
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
        child: Text(log.summary.isEmpty ? 'Kokkuvõte puudub' : log.summary),
      ),
      const SizedBox(height: 12),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Tulemus', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(log.outcome.isEmpty ? 'Tulemus puudub' : log.outcome),
      ),
      if (widget.canStartOperationLog)
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
    ];
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
    final memberLabels = members
        .map((member) {
          if (showDelay && member.responseMinutes != null) {
            return '${member.displayName} (${member.responseMinutes} min)';
          }
          return member.displayName;
        })
        .join(', ');

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
    final focusOrder = _focusedLogSortOrder(
      a.id,
      focusedLogId,
    ).compareTo(_focusedLogSortOrder(b.id, focusedLogId));
    if (focusOrder != 0) return focusOrder;

    final statusOrder = _operationLogStatusSortOrder(
      a.status,
    ).compareTo(_operationLogStatusSortOrder(b.status));
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
  return OperationLogStatus.normalize(status) !=
      OperationLogStatus.returnedToBase;
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

String _operationLogStatusLabel(String status) =>
    OperationLogStatus.label(status);

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
