import '../widgets/app_layout.dart';
import '../widgets/callout_test_status_control.dart';
import 'dart:async';
import '../widgets/callout_response_controls.dart';

import 'package:flutter/material.dart';
import 'callout_report_screen.dart';
import '../widgets/callout_edit_dialog.dart';

import '../models/callout_model.dart';
import '../widgets/callout_departure_timing.dart';
import '../models/operation_log_model.dart';
import '../services/callout_service.dart';
import '../services/operation_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_badge.dart';
import 'operation_log_screen.dart';
import 'callout_attendance_screen.dart';
import '../services/callout_attendance_service.dart';

class CalloutDetailScreen extends StatefulWidget {
  const CalloutDetailScreen({
    super.key,
    required this.callout,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canManageCallouts,
    required this.canCloseCallouts,
    required this.canStartOperationLog,
  });

  final CalloutModel callout;
  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final bool canManageCallouts;
  final bool canCloseCallouts;
  final bool canStartOperationLog;

  @override
  State<CalloutDetailScreen> createState() => _CalloutDetailScreenState();
}

class _CalloutDetailScreenState extends State<CalloutDetailScreen> {
  final _calloutService = CalloutService();
  final _operationLogService = OperationLogService();
  StreamSubscription<CalloutModel?>? _calloutSubscription;
  CalloutModel? _liveCallout;
  bool _calloutReadFailed = false;
  late final Stream<OperationLogModel?> _logStream;
  late final Stream<bool> _canConfirmAttendance;
  final _eventStreams = <String, Stream<List<OperationLogEventModel>>>{};
  bool _isUpdatingStatus = false;
  bool _isOpeningOperationLog = false;

  CalloutModel get _callout => _liveCallout ?? widget.callout;

  bool get _isActive => _callout.status == CalloutStatus.active;

  @override
  void initState() {
    super.initState();
    _canConfirmAttendance = CalloutAttendanceService().canManage(
      organizationId: widget.organizationId,
      userId: widget.currentUid,
    );
    _logStream = _operationLogService.streamLogForCallout(
      calloutId: widget.callout.id,
      organizationId: widget.organizationId,
    );
    _calloutSubscription = _calloutService
        .streamCallout(
          calloutId: widget.callout.id,
          organizationId: widget.organizationId,
        )
        .listen(
          (callout) {
            if (!mounted) return;
            if (callout == null) {
              setState(() => _calloutReadFailed = true);
              return;
            }
            setState(() {
              _liveCallout = callout;
              _calloutReadFailed = false;
            });
          },
          onError: (Object _) {
            if (mounted) setState(() => _calloutReadFailed = true);
          },
        );
  }

  @override
  void dispose() {
    _calloutSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateCalloutStatus(String status) async {
    if (!widget.canCloseCallouts || _isUpdatingStatus || !_isActive) return;

    final isClosing = status == CalloutStatus.closed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isClosing ? 'Lõpeta sündmus' : 'Tühista väljakutse'),
        content: Text(
          isClosing
              ? 'Kas soovid väljakutse "${_callout.title}" lõpetada?'
              : 'Kas soovid väljakutse "${_callout.title}" tühistada?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Katkesta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isClosing ? 'Lõpeta' : 'Tühista'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUpdatingStatus = true);
    try {
      await _calloutService.updateCalloutStatus(
        calloutId: _callout.id,
        organizationId: widget.organizationId,
        status: status,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClosing ? 'Väljakutse lõpetatud' : 'Väljakutse tühistatud',
          ),
        ),
      );
      if (!isClosing) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Väljakutse uuendamine ebaõnnestus.')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _openOrStartOperationLog(OperationLogModel? existingLog) async {
    if (_isOpeningOperationLog) return;

    if (existingLog == null && !widget.canStartOperationLog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sul puudub õigus seda toimingut teha')),
      );
      return;
    }

    setState(() => _isOpeningOperationLog = true);
    try {
      final log =
          existingLog ??
          await _operationLogService.startFromCallout(
            callout: _callout,
            organizationId: widget.organizationId,
            createdBy: widget.currentUid,
            createdByName: widget.currentUserName,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operatiivlogi avatud: ${log.title}')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OperationLogScreen(
            organizationId: widget.organizationId,
            currentUid: widget.currentUid,
            currentUserName: widget.currentUserName,
            canViewCalloutResponseSummary: widget.canManageCallouts,
            canStartOperationLog: widget.canStartOperationLog,
            initialLogId: log.id,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operatiivlogi avamine ebaõnnestus.')),
      );
    } finally {
      if (mounted) setState(() => _isOpeningOperationLog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Väljakutse info'),
        actions: [
          if (widget.canCloseCallouts && _isActive)
            PopupMenuButton<String>(
              tooltip: 'Väljakutse toimingud',
              enabled: !_isUpdatingStatus && !_calloutReadFailed,
              onSelected: _updateCalloutStatus,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: CalloutStatus.closed,
                  child: Text('Lõpeta sündmus'),
                ),
                PopupMenuItem(
                  value: CalloutStatus.cancelled,
                  child: Text('Tühista väljakutse'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          if (_calloutReadFailed)
            const AppSectionCard(
              child: Text(
                'Väljakutse värskendamine ebaõnnestus. Kuvatakse viimati saadud andmed. Kontrolli ühendust.',
              ),
            ),
          CalloutResponseControls(
            key: ValueKey(_callout.id),
            calloutId: _callout.id,
            organizationId: widget.organizationId,
            userId: widget.currentUid,
            userName: widget.currentUserName,
            active: _isActive,
            enabled: !_calloutReadFailed,
          ),
          const SizedBox(height: 12),
          if (_callout.isTest)
            const ListTile(
              leading: Icon(Icons.science_outlined),
              title: Text('Test-/proovisündmus'),
              subtitle: Text('Ei kuulu ametlikku statistikasse.'),
            ),
          _buildOverviewCard(),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildDescriptionCard(),
          const SizedBox(height: AppTheme.itemSpacing),
          if (_callout.status == CalloutStatus.closed)
            const AppSectionCard(
              child: Text(
                'Väljakutse on lõpetatud. Lisa või täienda nüüd operatiivlogi kokkuvõtet ja kinnita osalejad. Neid saab muuta ka hiljem.',
              ),
            ),
          _buildOperationLogAction(),
          FilledButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Sündmuse aruanne'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CalloutReportScreen(
                  organizationId: widget.organizationId,
                  calloutId: _callout.id,
                ),
              ),
            ),
          ),
          CalloutTestStatusControl(
            key: ValueKey('${widget.organizationId}-${widget.callout.id}'),
            callout: _callout,
            organizationId: widget.organizationId,
            userId: widget.currentUid,
          ),
          if (widget.canManageCallouts)
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Täienda sündmuse andmeid'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CalloutEditDialog(
                  callout: _callout,
                  organizationId: widget.organizationId,
                ),
              ),
            ),
          const SizedBox(height: AppTheme.itemSpacing),
          if (widget.canManageCallouts) ...[
            _buildResponseSummary(),
            const SizedBox(height: AppTheme.sectionSpacing),
          ],
          if (_callout.status != CalloutStatus.cancelled)
            StreamBuilder<bool>(
              stream: _canConfirmAttendance,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return OutlinedButton.icon(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Lisa / muuda ja kinnita osalejad'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalloutAttendanceScreen(
                        organizationId: widget.organizationId,
                        calloutId: _callout.id,
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: AppTheme.sectionSpacing),
        ],
      ),
    );
  }

  Widget _buildOperationLogAction() {
    return StreamBuilder<OperationLogModel?>(
      stream: _logStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AppSectionCard(
            child: Text('Logi laadimine ebaõnnestus. Kontrolli ühendust.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppSectionCard(child: LinearProgressIndicator());
        }
        final existingLog = snapshot.data;
        final canOpenOrStart =
            existingLog != null || widget.canStartOperationLog;
        if (!canOpenOrStart) return const SizedBox.shrink();

        return AppSectionCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (existingLog != null)
                StreamBuilder<List<OperationLogEventModel>>(
                  stream: _eventStreams.putIfAbsent(
                    existingLog.id,
                    () => _operationLogService.streamLogEvents(
                      operationLogId: existingLog.id,
                      organizationId: widget.organizationId,
                    ),
                  ),
                  builder: (context, events) {
                    if (events.hasError) {
                      return const Text(
                        'Väljasõidu aega ei õnnestunud laadida.',
                      );
                    }
                    if (!events.hasData) return const LinearProgressIndicator();
                    return CalloutDepartureTiming(
                      callout: _callout,
                      events: events.data!,
                    );
                  },
                ),
              const SizedBox(height: 8),
              PrimaryActionButton(
                label: existingLog == null
                    ? 'Alusta operatiivlogi'
                    : 'Ava operatiivlogi',
                icon: existingLog == null
                    ? Icons.playlist_add_outlined
                    : Icons.open_in_new,
                style: PrimaryActionButtonStyle.secondary,
                isLoading: _isOpeningOperationLog,
                onPressed: () => _openOrStartOperationLog(existingLog),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard() {
    return AppSectionCard(
      accentColor: _priorityColor(_callout.priority),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: CalloutType.label(_callout.calloutType),
                type: StatusBadgeType.neutral,
              ),
              StatusBadge(
                label: _priorityLabel(_callout.priority),
                type: _priorityBadgeType(_callout.priority),
                icon: Icons.warning_amber_rounded,
              ),
              StatusBadge(
                label: _statusLabel(_callout.status),
                type: _statusBadgeType(_callout.status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _callout.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (_callout.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.location_on_outlined,
              text: _callout.location,
            ),
          ],
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.schedule,
            text: _callout.effectiveStartedAt == null
                ? 'Loomise aeg puudub'
                : 'Algus ${_dateTime(_callout.effectiveStartedAt!)}',
          ),
          if (_callout.createdByName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.person_outline,
              text: 'Looja: ${_callout.createdByName}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return AppSectionCard(
      title: 'Sündmuse kirjeldus',
      leading: const Icon(Icons.description_outlined),
      child: Text(
        _callout.description.isEmpty
            ? 'Kirjeldust ei ole lisatud.'
            : _callout.description,
      ),
    );
  }

  Widget _buildResponseSummary() {
    return StreamBuilder<CalloutResponseDetails>(
      stream: _calloutService.streamCalloutResponseDetails(
        calloutId: _callout.id,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const AppSectionCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const AppSectionCard(
            child: Text('Meeskonna vastuste laadimine ebaõnnestus.'),
          );
        }
        final details = snapshot.data;
        if (details == null) {
          return const AppSectionCard(
            title: 'Meeskonna vastused',
            child: Text('Vastuste andmed ei ole praegu saadaval.'),
          );
        }

        final summary = details.summary;
        final comingCount = details.responding.length + details.delayed.length;
        final hasSecondLevelComing = [
          ...details.responding,
          ...details.delayed,
        ].any((member) => member.isSeaRescueLevel2);

        return AppSectionCard(
          title: 'Meeskonna vastused',
          subtitle: '${summary.totalResponded} vastanud',
          leading: const Icon(Icons.groups_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(
                    label: 'Reageerib ${summary.responding}',
                    type: StatusBadgeType.ready,
                  ),
                  StatusBadge(
                    label: 'Hilineb ${summary.delayed}',
                    type: StatusBadgeType.delayed,
                  ),
                  StatusBadge(
                    label: 'Ei tule ${summary.unavailable}',
                    type: StatusBadgeType.offDuty,
                  ),
                  StatusBadge(
                    label: 'Vastamata ${summary.noResponse}',
                    type: StatusBadgeType.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(
                    label: 'Tulemas: $comingCount',
                    type: StatusBadgeType.ready,
                  ),
                  StatusBadge(
                    label: hasSecondLevelComing
                        ? 'II astme tulija olemas'
                        : 'II astme tulija puudub',
                    type: hasSecondLevelComing
                        ? StatusBadgeType.ready
                        : _callout.calloutType == CalloutType.tross
                        ? StatusBadgeType.neutral
                        : StatusBadgeType.delayed,
                  ),
                ],
              ),
              if (_callout.calloutType == CalloutType.tross) ...[
                const SizedBox(height: 12),
                Text(
                  comingCount == 0
                      ? 'Reageerijaid pole veel kinnitatud.'
                      : 'Reageerimine ei kinnita pardalolekut.',
                ),
                const Text(
                  'SAR-i koosseisu- ja astmenõuded TROSSI aktiveerimist ei piira.',
                ),
              ],
              if (widget.canManageCallouts) ...[
                const SizedBox(height: 16),
                _buildMemberGroup('Reageerivad', details.responding),
                _buildMemberGroup(
                  'Hilinemisega reageerijad',
                  details.delayed,
                  showDelay: true,
                ),
                _buildMemberGroup('Ei saa tulla', details.unavailable),
                _buildMemberGroup('Vastamata', details.noResponse),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberGroup(
    String title,
    List<CalloutResponseMember> members, {
    bool showDelay = false,
  }) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          ...members.map(
            (member) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _responseIcon(member.response),
                    size: 18,
                    color: _responseColor(member.response),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${member.displayName} · ${member.isSeaRescueLevel2
                          ? 'II aste'
                          : member.seaRescueLevel == 'level1'
                          ? 'I aste'
                          : 'Aste puudub'}',
                    ),
                  ),
                  if (showDelay && member.responseMinutes != null)
                    Text('${member.responseMinutes} min'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case CalloutPriority.low:
        return 'Madal prioriteet';
      case CalloutPriority.high:
        return 'Kõrge prioriteet';
      case CalloutPriority.critical:
        return 'Kriitiline';
      default:
        return 'Tavaline prioriteet';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case CalloutStatus.closed:
        return 'Lõpetatud';
      case CalloutStatus.cancelled:
        return 'Tühistatud';
      default:
        return 'Aktiivne';
    }
  }

  StatusBadgeType _priorityBadgeType(String priority) {
    switch (priority) {
      case CalloutPriority.critical:
        return StatusBadgeType.critical;
      case CalloutPriority.high:
        return StatusBadgeType.activeCallout;
      default:
        return StatusBadgeType.neutral;
    }
  }

  StatusBadgeType _statusBadgeType(String status) {
    switch (status) {
      case CalloutStatus.closed:
        return StatusBadgeType.ready;
      case CalloutStatus.cancelled:
        return StatusBadgeType.offDuty;
      default:
        return StatusBadgeType.activeCallout;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case CalloutPriority.critical:
      case CalloutPriority.high:
        return AppColors.activeCallout;
      case CalloutPriority.normal:
        return AppColors.delayed;
      default:
        return AppColors.actionBlue;
    }
  }

  IconData _responseIcon(String response) {
    switch (response) {
      case CalloutResponseValue.responding:
        return Icons.check_circle_outline;
      case CalloutResponseValue.delayed:
        return Icons.schedule;
      case CalloutResponseValue.unavailable:
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _responseColor(String response) {
    switch (response) {
      case CalloutResponseValue.responding:
        return AppColors.ready;
      case CalloutResponseValue.delayed:
        return AppColors.delayed;
      case CalloutResponseValue.unavailable:
        return AppColors.activeCallout;
      default:
        return AppColors.offDuty;
    }
  }

  String _dateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date kell $time';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
