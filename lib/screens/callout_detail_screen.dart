import 'package:flutter/material.dart';

import '../models/callout_model.dart';
import '../models/operation_log_model.dart';
import '../services/callout_service.dart';
import '../services/operation_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_badge.dart';
import 'operation_log_screen.dart';

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
  bool _isSavingResponse = false;
  bool _isUpdatingStatus = false;
  bool _isOpeningOperationLog = false;

  bool get _isActive => widget.callout.status == CalloutStatus.active;

  Future<void> _showDelayedResponseDialog() async {
    var selectedMinutes = 15;
    final noteController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hilinen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vali eeldatav viivitus.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedMinutes,
                decoration: const InputDecoration(labelText: 'Hilinen'),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 minutit')),
                  DropdownMenuItem(value: 30, child: Text('30 minutit')),
                  DropdownMenuItem(value: 60, child: Text('60 minutit')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedMinutes = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Märkus',
                  hintText: 'Soovi korral lisa täpsustus',
                ),
                maxLines: 2,
              ),
            ],
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
        ),
      ),
    );

    if (shouldSave != true) return;
    await _setResponse(
      response: CalloutResponseValue.delayed,
      responseMinutes: selectedMinutes,
      note: noteController.text,
    );
  }

  Future<void> _setResponse({
    required String response,
    int? responseMinutes,
    String note = '',
  }) async {
    if (_isSavingResponse || !_isActive) return;
    setState(() => _isSavingResponse = true);

    try {
      await _calloutService.setMyResponse(
        calloutId: widget.callout.id,
        userId: widget.currentUid,
        userName: widget.currentUserName,
        organizationId: widget.organizationId,
        response: response,
        responseMinutes: responseMinutes,
        note: note,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vastus salvestatud')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vastuse salvestamine ebaõnnestus: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSavingResponse = false);
    }
  }

  Future<void> _updateCalloutStatus(String status) async {
    if (!widget.canCloseCallouts || _isUpdatingStatus || !_isActive) return;

    final isClosing = status == CalloutStatus.closed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isClosing ? 'Lõpeta väljakutse' : 'Tühista väljakutse',
        ),
        content: Text(
          isClosing
              ? 'Kas soovid väljakutse "${widget.callout.title}" lõpetada?'
              : 'Kas soovid väljakutse "${widget.callout.title}" tühistada?',
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
        calloutId: widget.callout.id,
        organizationId: widget.organizationId,
        status: status,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClosing
                ? 'Väljakutse lõpetatud'
                : 'Väljakutse tühistatud',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Väljakutse uuendamine ebaõnnestus: $error')),
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
      final log = existingLog ??
          await _operationLogService.startFromCallout(
            callout: widget.callout,
            organizationId: widget.organizationId,
            createdBy: widget.currentUid,
            createdByName: widget.currentUserName,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Op-logi avatud: ${log.title}')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OperationLogScreen(
            organizationId: widget.organizationId,
            currentUid: widget.currentUid,
            currentUserName: widget.currentUserName,
            canViewCalloutResponseSummary: widget.canManageCallouts,
            canStartOperationLog: widget.canStartOperationLog,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Op-logi avamine ebaõnnestus: $error')),
      );
    } finally {
      if (mounted) setState(() => _isOpeningOperationLog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Väljakutse info'),
        actions: [
          if (widget.canCloseCallouts && _isActive)
            PopupMenuButton<String>(
              tooltip: 'Väljakutse toimingud',
              onSelected: _updateCalloutStatus,
              itemBuilder: (context) => const [
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
          _buildOverviewCard(),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildDescriptionCard(),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildOperationLogAction(),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildResponseSummary(),
          if (_isActive) ...[
            const SizedBox(height: AppTheme.sectionSpacing),
            _buildResponseActions(),
          ],
          if (widget.canCloseCallouts && _isActive) ...[
            const SizedBox(height: AppTheme.sectionSpacing),
            PrimaryActionButton(
              label: 'Lõpeta väljakutse',
              icon: Icons.check_circle_outline,
              style: PrimaryActionButtonStyle.secondary,
              isLoading: _isUpdatingStatus,
              onPressed: () => _updateCalloutStatus(CalloutStatus.closed),
            ),
          ],
          const SizedBox(height: AppTheme.sectionSpacing),
        ],
      ),
    );
  }

  Widget _buildOperationLogAction() {
    return StreamBuilder<OperationLogModel?>(
      stream: _operationLogService.streamLogForCallout(
        calloutId: widget.callout.id,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final existingLog = snapshot.data;
        final canOpenOrStart = existingLog != null || widget.canStartOperationLog;
        if (!canOpenOrStart) return const SizedBox.shrink();

        return AppSectionCard(
          title: 'Operatsioonilogi',
          leading: const Icon(Icons.assignment_outlined),
          child: PrimaryActionButton(
            label: existingLog == null ? 'Alusta op-logi' : 'Ava op-logi',
            icon: existingLog == null
                ? Icons.playlist_add_outlined
                : Icons.open_in_new,
            style: PrimaryActionButtonStyle.secondary,
            isLoading: _isOpeningOperationLog,
            onPressed: () => _openOrStartOperationLog(existingLog),
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard() {
    return AppSectionCard(
      accentColor: _priorityColor(widget.callout.priority),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: _priorityLabel(widget.callout.priority),
                type: _priorityBadgeType(widget.callout.priority),
                icon: Icons.warning_amber_rounded,
              ),
              StatusBadge(
                label: _statusLabel(widget.callout.status),
                type: _statusBadgeType(widget.callout.status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.callout.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (widget.callout.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.location_on_outlined,
              text: widget.callout.location,
            ),
          ],
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.schedule,
            text: widget.callout.createdAt == null
                ? 'Loomise aeg puudub'
                : 'Loodud ${_dateTime(widget.callout.createdAt!)}',
          ),
          if (widget.callout.createdByName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.person_outline,
              text: 'Looja: ${widget.callout.createdByName}',
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
        widget.callout.description.isEmpty
            ? 'Kirjeldust ei ole lisatud.'
            : widget.callout.description,
      ),
    );
  }

  Widget _buildResponseSummary() {
    return StreamBuilder<CalloutResponseDetails>(
      stream: _calloutService.streamCalloutResponseDetails(
        calloutId: widget.callout.id,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const AppSectionCard(
            child: Center(child: CircularProgressIndicator()),
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
              if (widget.canManageCallouts) ...[
                const SizedBox(height: 16),
                _buildMemberGroup('Reageerivad', details.responding),
                _buildMemberGroup(
                  'Hilinenud',
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
                  Expanded(child: Text(member.displayName)),
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

  Widget _buildResponseActions() {
    return StreamBuilder<CalloutResponseModel?>(
      stream: _calloutService.streamMyResponse(
        calloutId: widget.callout.id,
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final currentResponse = snapshot.data?.response;
        final delayedMinutes = snapshot.data?.responseMinutes;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minu vastus',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _myResponseLabel(currentResponse, delayedMinutes),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: 'Reageerin',
              icon: Icons.directions_boat_outlined,
              isLoading: _isSavingResponse,
              onPressed: () => _setResponse(
                response: CalloutResponseValue.responding,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ResponseButton(
                    label: 'Hilinen',
                    icon: Icons.schedule,
                    selected:
                        currentResponse == CalloutResponseValue.delayed,
                    onPressed:
                        _isSavingResponse ? null : _showDelayedResponseDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResponseButton(
                    label: 'Ei saa tulla',
                    icon: Icons.cancel_outlined,
                    isDanger: true,
                    selected:
                        currentResponse == CalloutResponseValue.unavailable,
                    onPressed: _isSavingResponse
                        ? null
                        : () => _setResponse(
                              response: CalloutResponseValue.unavailable,
                            ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _myResponseLabel(String? response, int? minutes) {
    switch (response) {
      case CalloutResponseValue.responding:
        return 'Oled märkinud, et reageerid.';
      case CalloutResponseValue.delayed:
        return 'Oled märkinud viivituseks ${minutes ?? 0} minutit.';
      case CalloutResponseValue.unavailable:
        return 'Oled märkinud, et ei saa tulla.';
      default:
        return 'Sa ei ole veel sellele väljakutsele vastanud.';
    }
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
    final date = '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.year}';
    final time = '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date kell $time';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
  });

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

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final foreground = isDanger ? AppColors.critical : AppColors.navy;
    final background = isDanger
        ? AppColors.criticalSurface
        : AppColors.surfaceBlueStrong;

    return SizedBox(
      height: AppTheme.primaryActionHeight,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: selected ? 2 : 0,
          side: BorderSide(
            color: selected ? foreground : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
