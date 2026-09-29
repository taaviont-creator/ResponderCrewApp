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
import '../widgets/app_section_card.dart';
import '../widgets/status_badge.dart';

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
  });

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
  final _availabilityService = AvailabilityService();
  final _availabilityReminderSettingsService =
      AvailabilityReminderSettingsService();
  final _plannedUnavailabilityService = PlannedUnavailabilityService();
  var _isUpdating = false;
  Timer? _clock;
  bool _showCancelled = false;
  String? _cancellingPlannedUnavailabilityId;
  String? _cancellingPlannedUnavailabilityRuleId;

  @override
  void initState() {
    super.initState();
    // Time boundaries do not create Firestore writes. Refresh the personal
    // preview even when this page stays open without user interaction.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    if (widget.openPlanningOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddPlannedUnavailabilityDialog();
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _updateAvailability(
    String status, {
    int? responseMinutes,
    String? note,
  }) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      await _availabilityService.setMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
        memberName: widget.currentUserName,
        status: status,
        responseMinutes: responseMinutes,
        note: note?.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valmisoleku muutmine ebaõnnestus.')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Valmisolek')),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        _buildAvailabilityControl(),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Näita tühistatud mittevalveid'),
          value: _showCancelled,
          onChanged: (value) => setState(() => _showCancelled = value == true),
        ),
        _buildPlannedUnavailabilitySection(),
        const SizedBox(height: 12),
        _buildRecurringPlannedUnavailabilitySection(),
        const SizedBox(height: 12),
        _buildAvailabilityReminderSettings(),
      ],
    ),
  );

  Future<void> _updateAvailabilityRespectingSchedule(
    String status, {
    int? responseMinutes,
    String? note,
  }) async {
    if (status != AvailabilityStatus.offDuty) {
      final periods = await _plannedUnavailabilityService
          .streamMyPeriods(organizationId: widget.organizationId)
          .first;
      final rules = await _plannedUnavailabilityService
          .streamMyRules(organizationId: widget.organizationId)
          .first;
      final hasActiveSchedule = EffectiveAvailability.isPlannedUnavailable(
        userId: widget.currentUid,
        periods: periods,
        rules: rules,
      );

      if (hasActiveSchedule) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Planeeritud valveväline aeg on aktiivne. '
              'Tühista see enne valvesse märkimist.',
            ),
          ),
        );
        return;
      }
    }

    await _updateAvailability(
      status,
      responseMinutes: responseMinutes,
      note: note,
    );
  }

  Widget _buildAvailabilityControl() {
    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final availability = snapshot.data;
        final status = availability?.status ?? AvailabilityStatus.offDuty;
        final storedMinutes = availability?.responseMinutes ?? 15;
        final responseMinutes = const {15, 30, 60}.contains(storedMinutes)
            ? storedMinutes
            : 15;
        final note = availability?.note ?? '';

        return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Käsitsi valitud staatus',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _statusBadge(status)),
                  if (availability?.updatedAt != null)
                    Text(
                      'Uuendatud ${_formatClock(availability!.updatedAt!)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _buildScheduledStatusPreview(status),
              const SizedBox(height: 20),
              _StatusActionButton(
                label: 'Valves',
                icon: Icons.check_circle_outline,
                selected: status == AvailabilityStatus.onDuty,
                backgroundColor: AppColors.ready,
                foregroundColor: Colors.white,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailabilityRespectingSchedule(
                        AvailabilityStatus.onDuty,
                        note: note,
                      ),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _StatusActionButton(
                label: 'Hilinemisega',
                icon: Icons.schedule,
                selected: status == AvailabilityStatus.delayed,
                backgroundColor: AppColors.delayedSurface,
                foregroundColor: AppColors.delayed,
                borderColor: status == AvailabilityStatus.delayed
                    ? AppColors.delayed
                    : AppColors.border,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailabilityRespectingSchedule(
                        AvailabilityStatus.delayed,
                        responseMinutes: responseMinutes,
                        note: note,
                      ),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _StatusActionButton(
                label: 'Mitte valves',
                icon: Icons.cancel_outlined,
                selected: status == AvailabilityStatus.offDuty,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.offDuty,
                borderColor: AppColors.offDuty,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailability(
                        AvailabilityStatus.offDuty,
                        note: note,
                      ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reageerimisviivitus',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: responseMinutes,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('+ 15 min')),
                        DropdownMenuItem(value: 30, child: Text('+ 30 min')),
                        DropdownMenuItem(value: 60, child: Text('+ 60 min')),
                      ],
                      onChanged: _isUpdating
                          ? null
                          : (value) {
                              if (value == null) return;
                              _updateAvailabilityRespectingSchedule(
                                AvailabilityStatus.delayed,
                                responseMinutes: value,
                                note: note,
                              );
                            },
                    ),
                  ],
                ),
              ),
              if (_isUpdating) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduledStatusPreview(String manualStatus) {
    return StreamBuilder<List<PlannedUnavailabilityModel>>(
      stream: _plannedUnavailabilityService.streamMyPeriods(
        organizationId: widget.organizationId,
      ),
      builder: (context, periodsSnapshot) {
        return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
          stream: _plannedUnavailabilityService.streamMyRules(
            organizationId: widget.organizationId,
          ),
          builder: (context, rulesSnapshot) {
            final now = DateTime.now();
            final periods =
                periodsSnapshot.data ?? const <PlannedUnavailabilityModel>[];
            final rules =
                rulesSnapshot.data ?? const <PlannedUnavailabilityRuleModel>[];
            final hasActiveSchedule =
                EffectiveAvailability.isPlannedUnavailable(
                  userId: widget.currentUid,
                  periods: periods,
                  rules: rules,
                  now: now,
                );
            final effectiveStatus = EffectiveAvailability.resolve(
              userId: widget.currentUid,
              manualStatus: manualStatus,
              periods: periods,
              rules: rules,
              now: now,
            );

            return _ScheduledStatusPreview(
              hasActiveSchedule: hasActiveSchedule,
              effectiveStatusLabel: _availabilityStatusLabel(effectiveStatus),
            );
          },
        );
      },
    );
  }

  String _availabilityStatusLabel(String status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return 'Valves';
      case AvailabilityStatus.delayed:
        return 'Hilinemisega';
      default:
        return 'Mitte valves';
    }
  }

  Widget _buildPlannedUnavailabilitySection() {
    return StreamBuilder<List<PlannedUnavailabilityModel>>(
      stream: _plannedUnavailabilityService.streamMyPeriods(
        organizationId: widget.organizationId,
        includeCancelled: _showCancelled,
      ),
      builder: (context, snapshot) {
        final periods = (snapshot.data ?? const <PlannedUnavailabilityModel>[])
            .where(
              (p) =>
                  p.isCancelled || (p.endAt?.isAfter(DateTime.now()) ?? false),
            )
            .toList();

        Widget child;
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          child = const Center(child: CircularProgressIndicator());
        } else if (periods.isEmpty) {
          child = Text(
            'Planeeritud valveväliseid aegu ei ole.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          );
        } else {
          child = Column(
            children: [
              for (var index = 0; index < periods.length; index++) ...[
                _buildPlannedUnavailabilityTile(periods[index]),
                if (index < periods.length - 1) const Divider(height: 1),
              ],
            ],
          );
        }

        return AppSectionCard(
          title: 'Minu planeeritud mittevalved',
          subtitle: 'Praegused ja tulevased planeeringud',
          leading: const Icon(Icons.event_busy_outlined),
          trailing: TextButton.icon(
            onPressed: _showAddPlannedUnavailabilityDialog,
            icon: const Icon(Icons.add),
            label: const Text('Lisa'),
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildRecurringPlannedUnavailabilitySection() {
    return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
      stream: _plannedUnavailabilityService.streamMyRules(
        organizationId: widget.organizationId,
        includeCancelled: _showCancelled,
      ),
      builder: (context, snapshot) {
        final rules = snapshot.data ?? const <PlannedUnavailabilityRuleModel>[];

        Widget child;
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          child = const Center(child: CircularProgressIndicator());
        } else if (rules.isEmpty) {
          child = Text(
            'Korduvaid valveväliseid aegu ei ole.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          );
        } else {
          child = Column(
            children: [
              for (var index = 0; index < rules.length; index++) ...[
                _buildRecurringPlannedUnavailabilityTile(rules[index]),
                if (index < rules.length - 1) const Divider(height: 1),
              ],
            ],
          );
        }

        return AppSectionCard(
          title: 'Minu korduvad mittevalved',
          leading: const Icon(Icons.event_repeat_outlined),
          trailing: TextButton.icon(
            onPressed: _showAddRecurringPlannedUnavailabilityDialog,
            icon: const Icon(Icons.add),
            label: const Text('Lisa'),
          ),
          child: child,
        );
      },
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
              const SizedBox(width: 8),
              StatusBadge(
                label: period.isCancelled ? 'TÜHISTATUD' : 'AKTIIVNE',
                type: period.isCancelled
                    ? StatusBadgeType.neutral
                    : StatusBadgeType.offDuty,
                icon: period.isCancelled
                    ? Icons.cancel_outlined
                    : Icons.event_busy_outlined,
              ),
            ],
          ),
          if (period.isActive) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isCancelling
                    ? null
                    : () =>
                          _showAddPlannedUnavailabilityDialog(existing: period),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Muuda'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
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
            ),
          ],
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
              const SizedBox(width: 8),
              StatusBadge(
                label: rule.isCancelled ? 'Tühistatud' : 'Aktiivne',
                type: rule.isCancelled
                    ? StatusBadgeType.neutral
                    : StatusBadgeType.offDuty,
                icon: rule.isCancelled
                    ? Icons.cancel_outlined
                    : Icons.event_repeat_outlined,
              ),
            ],
          ),
          if (rule.isActive) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isCancelling
                    ? null
                    : () => _showAddRecurringPlannedUnavailabilityDialog(
                        existing: rule,
                      ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Muuda'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
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
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddPlannedUnavailabilityDialog({
    PlannedUnavailabilityModel? existing,
  }) async {
    final organizationId = widget.organizationId.trim();
    if (organizationId.isEmpty) {
      _showSnackBar(
        'Planeeritud valvevälist aega ei saa lisada ilma aktiivse ühinguta.',
      );
      return;
    }

    var startAt = existing?.startAt ?? _defaultPlannedStart();
    var endAt = existing?.endAt ?? startAt.add(const Duration(hours: 2));
    var isSaving = false;
    final noteController = TextEditingController(text: existing?.note ?? '');

    final route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (!startAt.isBefore(endAt)) {
                _showSnackBar('Algusaeg peab olema enne lõpuaega.');
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                if (existing == null) {
                  await _plannedUnavailabilityService.createMyPeriod(
                    organizationId: organizationId,
                    startAt: startAt,
                    endAt: endAt,
                    note: noteController.text,
                  );
                } else {
                  await _plannedUnavailabilityService.updateMyPeriod(
                    periodId: existing.id,
                    organizationId: organizationId,
                    startAt: startAt,
                    endAt: endAt,
                    note: noteController.text,
                  );
                }
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _showSnackBar(
                  existing == null
                      ? 'Planeeritud valveväline aeg lisatud.'
                      : 'Planeering muudetud.',
                );
              } catch (e) {
                if (!mounted || !dialogContext.mounted) return;
                setDialogState(() => isSaving = false);
                _showSnackBar(
                  'Planeeritud valvevälist aega ei saanud salvestada.',
                );
              }
            }

            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Lisa planeeritud valveväline aeg'
                    : 'Muuda planeeritud valvevälist aega',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DateTimePickerTile(
                      label: 'Algus',
                      value: _formatDateTime(startAt),
                      onTap: isSaving
                          ? null
                          : () async {
                              final selected = await _pickDateTime(
                                dialogContext: dialogContext,
                                initial: startAt,
                              );
                              if (selected == null) return;
                              setDialogState(() {
                                startAt = selected;
                                if (!startAt.isBefore(endAt)) {
                                  endAt = startAt.add(const Duration(hours: 2));
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    _DateTimePickerTile(
                      label: 'Lõpp',
                      value: _formatDateTime(endAt),
                      onTap: isSaving
                          ? null
                          : () async {
                              final selected = await _pickDateTime(
                                dialogContext: dialogContext,
                                initial: endAt,
                              );
                              if (selected == null) return;
                              setDialogState(() => endAt = selected);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      enabled: !isSaving,
                      maxLines: 2,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Märkus (valikuline)',
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Katkesta'),
                ),
                FilledButton.icon(
                  onPressed: isSaving ? null : save,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Salvesta'),
                ),
              ],
            );
          },
        );
      },
    );

    await Navigator.of(context).push(route);
    await route.completed;
    noteController.dispose();
  }

  Future<void> _showAddRecurringPlannedUnavailabilityDialog({
    PlannedUnavailabilityRuleModel? existing,
  }) async {
    final organizationId = widget.organizationId.trim();
    if (organizationId.isEmpty) {
      _showSnackBar('Korduvat valvevälist aega ei saanud salvestada.');
      return;
    }

    final selectedDays = {...?existing?.daysOfWeek};
    var startTime = TimeOfDay(
      hour: (existing?.startMinute ?? 480) ~/ 60,
      minute: (existing?.startMinute ?? 480) % 60,
    );
    var endTime = TimeOfDay(
      hour: (existing?.endMinute ?? 1020) ~/ 60,
      minute: (existing?.endMinute ?? 1020) % 60,
    );
    var isSaving = false;
    final noteController = TextEditingController(text: existing?.note ?? '');

    final route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (selectedDays.isEmpty) {
                _showSnackBar('Vali vähemalt üks nädalapäev.');
                return;
              }

              final startMinute = _minuteOfDay(startTime);
              final endMinute = _minuteOfDay(endTime);
              if (startMinute >= endMinute) {
                _showSnackBar('Algusaeg peab olema enne lõpuaega.');
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                if (existing == null) {
                  await _plannedUnavailabilityService.createMyRule(
                    organizationId: organizationId,
                    daysOfWeek: selectedDays.toList(),
                    startMinute: startMinute,
                    endMinute: endMinute,
                    note: noteController.text,
                  );
                } else {
                  await _plannedUnavailabilityService.updateMyRule(
                    ruleId: existing.id,
                    organizationId: organizationId,
                    daysOfWeek: selectedDays.toList(),
                    startMinute: startMinute,
                    endMinute: endMinute,
                    note: noteController.text,
                  );
                }
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _showSnackBar(
                  existing == null
                      ? 'Korduv valveväline aeg lisatud.'
                      : 'Korduv planeering muudetud.',
                );
              } catch (e) {
                if (!mounted || !dialogContext.mounted) return;
                setDialogState(() => isSaving = false);
                _showSnackBar(
                  'Korduvat valvevälist aega ei saanud salvestada.',
                );
              }
            }

            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Lisa korduv valveväline aeg'
                    : 'Muuda korduvat valvevälist aega',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vali nädalapäevad',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final day in const [1, 2, 3, 4, 5, 6, 7])
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_weekdayLabel(day)),
                        value: selectedDays.contains(day),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedDays.add(day);
                                  } else {
                                    selectedDays.remove(day);
                                  }
                                });
                              },
                      ),
                    const SizedBox(height: 12),
                    _DateTimePickerTile(
                      label: 'Algusaeg',
                      value: _formatTimeOfDay(startTime),
                      onTap: isSaving
                          ? null
                          : () async {
                              final selected = await _pickTimeOfDay(
                                dialogContext: dialogContext,
                                initialTime: startTime,
                              );
                              if (selected == null) return;
                              setDialogState(() => startTime = selected);
                            },
                    ),
                    const SizedBox(height: 12),
                    _DateTimePickerTile(
                      label: 'Lõpuaeg',
                      value: _formatTimeOfDay(endTime),
                      onTap: isSaving
                          ? null
                          : () async {
                              final selected = await _pickTimeOfDay(
                                dialogContext: dialogContext,
                                initialTime: endTime,
                              );
                              if (selected == null) return;
                              setDialogState(() => endTime = selected);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      enabled: !isSaving,
                      maxLines: 2,
                      maxLength: 2000,
                      decoration: const InputDecoration(labelText: 'Märkus'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Katkesta'),
                ),
                FilledButton.icon(
                  onPressed: isSaving ? null : save,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Salvesta'),
                ),
              ],
            );
          },
        );
      },
    );

    await Navigator.of(context).push(route);
    await route.completed;
    noteController.dispose();
  }

  Future<DateTime?> _pickDateTime({
    required BuildContext dialogContext,
    required DateTime initial,
  }) async {
    final date = await showDatePicker(
      context: dialogContext,
      initialDate: initial,
      firstDate:
          initial.isBefore(DateTime.now().subtract(const Duration(days: 1)))
          ? initial
          : DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !dialogContext.mounted) return null;

    final time = await _pickTimeOfDay(
      dialogContext: dialogContext,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<TimeOfDay?> _pickTimeOfDay({
    required BuildContext dialogContext,
    required TimeOfDay initialTime,
  }) {
    return showTimePicker(
      context: dialogContext,
      initialTime: initialTime,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
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

  Widget _statusBadge(String status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return const StatusBadge(label: 'Valves', type: StatusBadgeType.ready);
      case AvailabilityStatus.delayed:
        return const StatusBadge(
          label: 'Hilinemisega',
          type: StatusBadgeType.delayed,
        );
      default:
        return const StatusBadge(
          label: 'Mitte valves',
          type: StatusBadgeType.offDuty,
        );
    }
  }

  Widget _buildAvailabilityReminderSettings() {
    return StreamBuilder<AvailabilityReminderSettingsModel>(
      stream: _availabilityReminderSettingsService.streamMySettings(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
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

        return AppSectionCard(
          padding: EdgeInsets.zero,
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

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year} ${_formatClock(value)}';
  }

  int _minuteOfDay(TimeOfDay value) {
    return value.hour * 60 + value.minute;
  }

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

  DateTime _defaultPlannedStart() {
    final now = DateTime.now().add(const Duration(hours: 1));
    return DateTime(now.year, now.month, now.day, now.hour);
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

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.primaryActionHeight,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: selected ? 2 : 0,
          side: BorderSide(
            color:
                borderColor ??
                (selected ? foregroundColor : Colors.transparent),
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _DateTimePickerTile extends StatelessWidget {
  const _DateTimePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(value),
      ),
    );
  }
}

class _ScheduledStatusPreview extends StatelessWidget {
  const _ScheduledStatusPreview({
    required this.hasActiveSchedule,
    required this.effectiveStatusLabel,
  });

  final bool hasActiveSchedule;
  final String effectiveStatusLabel;

  @override
  Widget build(BuildContext context) {
    final color = hasActiveSchedule
        ? AppColors.offDuty
        : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlue,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planeeritud staatuse mõju',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveSchedule
                ? 'Planeeritud valveväline aeg on aktiivne ja sind ei '
                      'arvestata valves olevate liikmete hulka.'
                : 'Planeeritud valveväline aeg ei ole hetkel aktiivne.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: hasActiveSchedule
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nähtav staatus: $effectiveStatusLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasActiveSchedule
                  ? AppColors.offDuty
                  : AppColors.textSecondary,
              fontWeight: hasActiveSchedule
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sinu käsitsi valitud staatus säilib.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
