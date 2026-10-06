import '../widgets/app_layout.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/availability_model.dart';
import '../models/effective_availability.dart';
import '../models/availability_reminder_settings_model.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/availability_reminder_settings_service.dart';
import '../services/availability_service.dart';
import '../services/planned_unavailability_service.dart';
import '../theme/app_theme.dart';
import '../widgets/personal_availability_card.dart';
import '../widgets/unavailability_editor.dart';
import '../models/activity_schedule.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canViewOrganizationReadiness,
    this.organizationName,
    this.membershipRole,
    this.openPlanningOnStart = false,
    this.availabilityService,
    this.plannedUnavailabilityService,
    this.reminderService,
  });

  final AvailabilityService? availabilityService;
  final PlannedUnavailabilityService? plannedUnavailabilityService;
  final AvailabilityReminderSettingsService? reminderService;
  final bool openPlanningOnStart;
  final String organizationId;
  final String? organizationName;
  final String? membershipRole;
  final String currentUid;
  final String currentUserName;
  final bool canViewOrganizationReadiness;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late final _availabilityService =
      widget.availabilityService ?? AvailabilityService();
  late final _availabilityReminderSettingsService =
      widget.reminderService ?? AvailabilityReminderSettingsService();
  late final _plannedUnavailabilityService =
      widget.plannedUnavailabilityService ?? PlannedUnavailabilityService();
  late Stream<AvailabilityModel?> _availability;
  late Stream<List<PlannedUnavailabilityModel>> _periods;
  late Stream<List<PlannedUnavailabilityRuleModel>> _rules;
  late Stream<AvailabilityReminderSettingsModel> _reminders;

  void _bindStreams() {
    _availability = _availabilityService.streamMyAvailability(
      userId: widget.currentUid,
      organizationId: widget.organizationId,
    );
    _periods = _plannedUnavailabilityService.streamMyPeriods(
      organizationId: widget.organizationId,
      includeCancelled: true,
    );
    _rules = _plannedUnavailabilityService.streamMyRules(
      organizationId: widget.organizationId,
      includeCancelled: true,
    );
    _reminders = _availabilityReminderSettingsService.streamMySettings(
      userId: widget.currentUid,
      organizationId: widget.organizationId,
    );
  }

  @override
  void didUpdateWidget(covariant AvailabilityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.currentUid != widget.currentUid) {
      _showCancelled = false;
      _bindStreams();
    }
  }

  var _isUpdating = false;
  Timer? _clock;
  bool _showCancelled = false;
  String? _cancellingPlannedUnavailabilityId;
  String? _cancellingPlannedUnavailabilityRuleId;

  @override
  void initState() {
    super.initState();
    _bindStreams();
    // Time boundaries do not create Firestore writes. Refresh the personal
    // preview even when this page stays open without user interaction.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    if (widget.openPlanningOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPlanEditor();
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _updateAvailabilityRespectingSchedule(
    String status, {
    int? responseMinutes,
    String? note,
  }) async {
    if (_isUpdating) return;
    final organizationId = widget.organizationId;
    final userId = widget.currentUid;
    final memberName = widget.currentUserName;
    setState(() => _isUpdating = true);
    try {
      if (status != AvailabilityStatus.offDuty) {
        final periods = await _plannedUnavailabilityService
            .streamMyPeriods(organizationId: organizationId)
            .first;
        final rules = await _plannedUnavailabilityService
            .streamMyRules(organizationId: organizationId)
            .first;
        if (!mounted ||
            organizationId != widget.organizationId ||
            userId != widget.currentUid) {
          return;
        }
        if (EffectiveAvailability.isPlannedUnavailable(
          userId: userId,
          periods: periods,
          rules: rules,
          now: ActivitySchedule.inEstonia(DateTime.now()),
        )) {
          _showSnackBar(
            'Planeeritud mittevalve on aktiivne. Muuda või tühista see enne valvesse märkimist.',
          );
          return;
        }
      }
      await _availabilityService.setMyAvailability(
        userId: userId,
        organizationId: organizationId,
        memberName: memberName,
        status: status,
        responseMinutes: responseMinutes,
        note: note?.trim(),
      );
    } catch (_) {
      _showSnackBar('Valmisoleku muutmine ebaõnnestus. Proovi uuesti.');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Valmisolek')),
    body: StreamBuilder<AvailabilityModel?>(
      key: ValueKey('${widget.organizationId}/${widget.currentUid}'),
      stream: _availability,
      builder: (context, availability) =>
          StreamBuilder<List<PlannedUnavailabilityModel>>(
            stream: _periods,
            builder: (context, periods) =>
                StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
                  stream: _rules,
                  builder: (context, rules) {
                    final now = ActivitySchedule.inEstonia(DateTime.now());
                    final plansLoaded = periods.hasData && rules.hasData;
                    final hasError =
                        availability.hasError ||
                        periods.hasError ||
                        rules.hasError;
                    final status =
                        availability.data?.status ?? AvailabilityStatus.offDuty;
                    final storedMinutes =
                        availability.data?.responseMinutes ?? 15;
                    final minutes = const {15, 30, 60}.contains(storedMinutes)
                        ? storedMinutes
                        : 15;
                    final plannedUnavailable =
                        plansLoaded &&
                        EffectiveAvailability.isPlannedUnavailable(
                          userId: widget.currentUid,
                          periods: periods.data!,
                          rules: rules.data!,
                          now: now,
                        );
                    return ListView(
                      padding: const EdgeInsets.all(AppTheme.screenPadding),
                      children: [
                        PersonalAvailabilityCard(
                          status: status,
                          minutes: minutes,
                          plannedUnavailable: plannedUnavailable,
                          saving: _isUpdating,
                          loading:
                              !plansLoaded ||
                              availability.connectionState ==
                                  ConnectionState.waiting,
                          error: hasError,
                          onRetry: () => setState(_bindStreams),
                          onSelect: (value) =>
                              _updateAvailabilityRespectingSchedule(
                                value,
                                responseMinutes:
                                    value == AvailabilityStatus.delayed
                                    ? minutes
                                    : null,
                                note: availability.data?.note,
                              ),
                          onDelayChanged: (value) =>
                              _updateAvailabilityRespectingSchedule(
                                AvailabilityStatus.delayed,
                                responseMinutes: value,
                                note: availability.data?.note,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _buildPlans(periods, rules, now),
                        const SizedBox(height: 16),
                        _buildAvailabilityReminderSettings(),
                      ],
                    );
                  },
                ),
          ),
    ),
  );

  Widget _buildPlans(
    AsyncSnapshot<List<PlannedUnavailabilityModel>> periods,
    AsyncSnapshot<List<PlannedUnavailabilityRuleModel>> rules,
    DateTime now,
  ) {
    final rows = <({DateTime at, Widget child})>[];
    for (final period in periods.data ?? const <PlannedUnavailabilityModel>[]) {
      if (period.isCancelled
          ? !_showCancelled
          : !(period.endAt?.isAfter(now) ?? false)) {
        continue;
      }
      rows.add((
        at: period.isCancelled ? DateTime(9999) : period.startAt ?? now,
        child: _buildPlannedUnavailabilityTile(period),
      ));
    }
    for (final rule in rules.data ?? const <PlannedUnavailabilityRuleModel>[]) {
      if (rule.isCancelled && !_showCancelled) continue;
      var next = DateTime(9999);
      if (rule.isActive) {
        for (var offset = 0; offset <= 7; offset++) {
          final day = DateTime(now.year, now.month, now.day + offset);
          if (!rule.daysOfWeek.contains(day.weekday)) continue;
          final start = ActivitySchedule.fromSelection(
            day,
            rule.startMinute ~/ 60,
            rule.startMinute % 60,
          );
          final end = ActivitySchedule.fromSelection(
            day,
            rule.endMinute ~/ 60,
            rule.endMinute % 60,
          );
          if (start != null && end != null && end.isAfter(now)) {
            next = start;
            break;
          }
        }
      }
      rows.add((
        at: next,
        child: _buildRecurringPlannedUnavailabilityTile(rule),
      ));
    }
    rows.sort((a, b) => a.at.compareTo(b.at));
    final failed = periods.hasError || rules.hasError;
    final loading = !failed && (!periods.hasData || !rules.hasData);
    final hasCancelled =
        (periods.data?.any((p) => p.isCancelled) ?? false) ||
        (rules.data?.any((r) => r.isCancelled) ?? false);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              children: [
                Text(
                  'Minu mittevalved',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _showPlanEditor,
                  icon: const Icon(Icons.add),
                  label: const Text('Lisa aeg'),
                ),
              ],
            ),
            if (failed) ...[
              const Text('Kõiki mittevalveid ei saanud laadida.'),
              TextButton(
                onPressed: () => setState(_bindStreams),
                child: const Text('Laadi uuesti'),
              ),
            ] else if (loading)
              const LinearProgressIndicator()
            else if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Planeeritud mittevalveid ei ole.'),
              ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              rows[i].child,
            ],
            if (hasCancelled)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Näita tühistatud'),
                value: _showCancelled,
                onChanged: (value) =>
                    setState(() => _showCancelled = value == true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedUnavailabilityTile(PlannedUnavailabilityModel period) {
    final isCancelling = _cancellingPlannedUnavailabilityId == period.id;
    final note = period.note.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.schedule_outlined,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDateTime(period.startAt)} - '
                      '${_formatDateTime(period.endAt)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period.isCancelled
                          ? 'Tühistatud · Ühekordne'
                          : 'Ühekordne',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (period.isActive)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: isCancelling
                      ? null
                      : () => _showPlanEditor(period: period),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Muuda'),
                ),
                TextButton.icon(
                  onPressed: isCancelling
                      ? null
                      : () => _cancelPlannedUnavailability(period),
                  icon: isCancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('Tühista'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecurringPlannedUnavailabilityTile(
    PlannedUnavailabilityRuleModel rule,
  ) {
    final isCancelling = _cancellingPlannedUnavailabilityRuleId == rule.id;
    final note = rule.note.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_repeat_outlined,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatWeekdays(rule.daysOfWeek),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rule.startTime} - ${rule.endTime}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.isCancelled
                          ? 'Tühistatud · Igal nädalal'
                          : 'Igal nädalal',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (rule.isActive)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: isCancelling
                      ? null
                      : () => _showPlanEditor(rule: rule),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Muuda'),
                ),
                TextButton.icon(
                  onPressed: isCancelling
                      ? null
                      : () => _cancelRecurringPlannedUnavailability(rule),
                  icon: isCancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('Tühista'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showPlanEditor({
    PlannedUnavailabilityModel? period,
    PlannedUnavailabilityRuleModel? rule,
  }) async {
    if (widget.organizationId.trim().isEmpty) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UnavailabilityEditor(
        organizationId: widget.organizationId,
        service: _plannedUnavailabilityService,
        period: period,
        rule: rule,
      ),
    );
    if (saved == true && mounted) _showSnackBar('Mittevalve salvestatud.');
  }

  Future<void> _cancelPlannedUnavailability(
    PlannedUnavailabilityModel period,
  ) async {
    if (_cancellingPlannedUnavailabilityId != null) return;

    setState(() => _cancellingPlannedUnavailabilityId = period.id);
    try {
      await _plannedUnavailabilityService.cancelMyPeriod(periodId: period.id);
      if (!mounted) return;
      _showSnackBar('Planeeritud valveväline aeg tühistatud.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Sul puudub õigus seda kirjet muuta.');
    } finally {
      if (mounted) {
        setState(() => _cancellingPlannedUnavailabilityId = null);
      }
    }
  }

  Future<void> _cancelRecurringPlannedUnavailability(
    PlannedUnavailabilityRuleModel rule,
  ) async {
    if (_cancellingPlannedUnavailabilityRuleId != null) return;

    setState(() => _cancellingPlannedUnavailabilityRuleId = rule.id);
    try {
      await _plannedUnavailabilityService.cancelMyRule(ruleId: rule.id);
      if (!mounted) return;
      _showSnackBar('Korduv valveväline aeg tühistatud.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Sul puudub õigus seda kirjet muuta.');
    } finally {
      if (mounted) {
        setState(() => _cancellingPlannedUnavailabilityRuleId = null);
      }
    }
  }

  Widget _buildAvailabilityReminderSettings() {
    return StreamBuilder<AvailabilityReminderSettingsModel>(
      stream: _reminders,
      builder: (context, snapshot) {
        final settings =
            snapshot.data ??
            AvailabilityReminderSettingsModel.defaults(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
            );
        final timeOptions = _reminderTimeOptions(settings.reminderTime);

        Future<void> updateSettings({
          bool? enabled,
          int? intervalHours,
          String? reminderTime,
        }) async {
          try {
            await _availabilityReminderSettingsService.setMySettings(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
              enabled: enabled ?? settings.enabled,
              intervalHours: intervalHours ?? settings.intervalHours,
              reminderTime: reminderTime ?? settings.reminderTime,
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Meeldetuletuse muutmine ebaõnnestus.'),
              ),
            );
          }
        }

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Valmisoleku meeldetuletused'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Meeldetuletused on lubatud'),
                value: settings.enabled,
                onChanged: (value) => updateSettings(enabled: value),
              ),
              DropdownButtonFormField<int>(
                initialValue: settings.intervalHours,
                decoration: const InputDecoration(labelText: 'Intervall'),
                items: AvailabilityReminderSettingsModel.allowedIntervalHours
                    .map(
                      (hours) => DropdownMenuItem<int>(
                        value: hours,
                        child: Text(_reminderIntervalLabel(hours)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) updateSettings(intervalHours: value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: settings.reminderTime,
                decoration: const InputDecoration(labelText: 'Kellaaeg'),
                items: timeOptions
                    .map(
                      (time) => DropdownMenuItem<String>(
                        value: time,
                        child: Text(time),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) updateSettings(reminderTime: value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime? value) => ActivitySchedule.format(value);

  String _formatWeekdays(List<int> daysOfWeek) {
    if (daysOfWeek.isEmpty) return '-';
    final sorted = daysOfWeek.toSet().toList()..sort();
    return sorted.map(_weekdayLabel).join(', ');
  }

  String _weekdayLabel(int day) {
    switch (day) {
      case 1:
        return 'E';
      case 2:
        return 'T';
      case 3:
        return 'K';
      case 4:
        return 'N';
      case 5:
        return 'R';
      case 6:
        return 'L';
      case 7:
        return 'P';
      default:
        return '-';
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _reminderTimeOptions(String selectedTime) {
    final times = <String>{
      for (var hour = 0; hour < 24; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
      selectedTime,
    }.toList()..sort();
    return times;
  }

  String _reminderIntervalLabel(int hours) {
    if (hours == 168) return '7 päeva';
    return '$hours tundi';
  }
}
