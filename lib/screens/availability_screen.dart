import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/availability_model.dart';
import '../models/membership_model.dart';
import '../models/availability_reminder_settings_model.dart';
import '../models/platform_readiness_model.dart';
import '../models/planned_unavailability_model.dart';
import '../services/availability_reminder_settings_service.dart';
import '../services/availability_service.dart';
import '../services/membership_service.dart';
import '../services/platform_readiness_service.dart';
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
  });

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
  final _membershipService = MembershipService();
  final _platformReadinessService = PlatformReadinessService();
  final _plannedUnavailabilityService = PlannedUnavailabilityService();
  final _noteController = TextEditingController();
  var _noteInitialized = false;
  var _isUpdating = false;
  String? _cancellingPlannedUnavailabilityId;

  @override
  void dispose() {
    _noteController.dispose();
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
        const SnackBar(content: Text('Valmiduse muutmine ebaõnnestus.')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationName = widget.organizationName?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Valmisolek')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          AppSectionCard(
            child: Row(
              children: [
                const Icon(
                  Icons.anchor,
                  color: AppColors.navy,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organizationName == null || organizationName.isEmpty
                            ? 'Aktiivne organisatsioon'
                            : organizationName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _roleLabel(widget.membershipRole ?? ''),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: widget.canViewOrganizationReadiness
                      ? 'ADMIN'
                      : 'LIIGE',
                  type: StatusBadgeType.neutral,
                  icon: widget.canViewOrganizationReadiness
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          Text(
            'Minu valmisolek',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Määra oma operatiivne staatus.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildAvailabilityControl(),
          const SizedBox(height: AppTheme.sectionSpacing),
          _buildPlannedUnavailabilitySection(),
          const SizedBox(height: AppTheme.sectionSpacing),
          Text(
            'Meeskonna ülevaade',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildAvailabilityOverview(),
          const SizedBox(height: AppTheme.sectionSpacing),
          _buildAvailabilityReminderSettings(),
          const SizedBox(height: AppTheme.sectionSpacing),
        ],
      ),
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
        final responseMinutes =
            const {15, 30, 60}.contains(storedMinutes) ? storedMinutes : 15;
        final note = availability?.note ?? '';

        if (!_noteInitialized && snapshot.hasData) {
          _noteInitialized = true;
          _noteController.text = note;
        }

        return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),
              _StatusActionButton(
                label: 'VALVES',
                icon: Icons.check_circle_outline,
                selected: status == AvailabilityStatus.onDuty,
                backgroundColor: AppColors.ready,
                foregroundColor: Colors.white,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailability(
                          AvailabilityStatus.onDuty,
                          note: _noteController.text,
                        ),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _StatusActionButton(
                label: 'HILINEN',
                icon: Icons.schedule,
                selected: status == AvailabilityStatus.delayed,
                backgroundColor: AppColors.delayedSurface,
                foregroundColor: AppColors.delayed,
                borderColor: status == AvailabilityStatus.delayed
                    ? AppColors.delayed
                    : AppColors.border,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailability(
                          AvailabilityStatus.delayed,
                          responseMinutes: responseMinutes,
                          note: _noteController.text,
                        ),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _StatusActionButton(
                label: 'EI OLE VALVES',
                icon: Icons.cancel_outlined,
                selected: status == AvailabilityStatus.offDuty,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.offDuty,
                borderColor: AppColors.offDuty,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailability(
                          AvailabilityStatus.offDuty,
                          note: _noteController.text,
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
                      'Reageerimise viide',
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
                              _updateAvailability(
                                AvailabilityStatus.delayed,
                                responseMinutes: value,
                                note: _noteController.text,
                              );
                            },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Märkus (valikuline)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Nt: Olen teel sadamasse...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : () => _updateAvailability(
                                  status,
                                  responseMinutes:
                                      status == AvailabilityStatus.delayed
                                          ? responseMinutes
                                          : null,
                                  note: _noteController.text,
                                ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvesta märkus'),
                      ),
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

  Widget _buildPlannedUnavailabilitySection() {
    return StreamBuilder<List<PlannedUnavailabilityModel>>(
      stream: _plannedUnavailabilityService.streamMyPeriods(
        organizationId: widget.organizationId,
        includeCancelled: true,
      ),
      builder: (context, snapshot) {
        final periods = snapshot.data ?? const <PlannedUnavailabilityModel>[];

        Widget child;
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          child = const Center(child: CircularProgressIndicator());
        } else if (periods.isEmpty) {
          child = Text(
            'Planeeritud mittevalves aegu ei ole.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
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
          title: 'Minu planeeritud mittevalves ajad',
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

  Widget _buildPlannedUnavailabilityTile(
    PlannedUnavailabilityModel period,
  ) {
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

  Future<void> _showAddPlannedUnavailabilityDialog() async {
    final organizationId = widget.organizationId.trim();
    if (organizationId.isEmpty) {
      _showSnackBar(
        'Planeeritud mittevalves aega ei saa lisada ilma aktiivse ühinguta.',
      );
      return;
    }

    var startAt = _defaultPlannedStart();
    var endAt = startAt.add(const Duration(hours: 2));
    var isSaving = false;
    final noteController = TextEditingController();

    await showDialog<void>(
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
                await _plannedUnavailabilityService.createMyPeriod(
                  organizationId: organizationId,
                  startAt: startAt,
                  endAt: endAt,
                  note: noteController.text,
                );
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _showSnackBar('Planeeritud mittevalves aeg lisatud.');
              } catch (e) {
                if (!mounted || !dialogContext.mounted) return;
                setDialogState(() => isSaving = false);
                _showSnackBar(
                  'Planeeritud mittevalves aega ei saanud salvestada.',
                );
              }
            }

            return AlertDialog(
              title: const Text('Lisa planeeritud mittevalves aeg'),
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
                                  endAt = startAt.add(
                                    const Duration(hours: 2),
                                  );
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
                      decoration: const InputDecoration(
                        labelText: 'Märkus (valikuline)',
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

    noteController.dispose();
  }

  Future<DateTime?> _pickDateTime({
    required BuildContext dialogContext,
    required DateTime initial,
  }) async {
    final date = await showDatePicker(
      context: dialogContext,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !dialogContext.mounted) return null;

    final time = await showTimePicker(
      context: dialogContext,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
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
      _showSnackBar('Planeeritud mittevalves aeg tühistatud.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Sul puudub õigus seda kirjet muuta.');
    } finally {
      if (mounted) {
        setState(() => _cancellingPlannedUnavailabilityId = null);
      }
    }
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return const StatusBadge(
          label: 'VALVES',
          type: StatusBadgeType.ready,
        );
      case AvailabilityStatus.delayed:
        return const StatusBadge(
          label: 'HILINEN',
          type: StatusBadgeType.delayed,
        );
      default:
        return const StatusBadge(
          label: 'EI OLE VALVES',
          type: StatusBadgeType.offDuty,
        );
    }
  }

  Widget _buildAvailabilityOverview() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _membershipService.streamActiveMembershipsForOrganization(
        widget.organizationId,
      ),
      builder: (context, membershipsSnapshot) {
        if (membershipsSnapshot.connectionState == ConnectionState.waiting &&
            !membershipsSnapshot.hasData) {
          return const _LoadingCard();
        }

        final memberships = membershipsSnapshot.data ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return StreamBuilder<List<AvailabilityModel>>(
          stream: _availabilityService.streamOrganizationAvailability(
            organizationId: widget.organizationId,
          ),
          builder: (context, availabilitySnapshot) {
            final availabilityByUserId = <String, AvailabilityModel>{
              for (final availability
                  in availabilitySnapshot.data ?? const <AvailabilityModel>[])
                if (availability.userId.isNotEmpty)
                  availability.userId: availability,
            };

            final onDuty = <_MemberAvailability>[];
            final delayed = <_MemberAvailability>[];
            final offDuty = <_MemberAvailability>[];

            for (final membershipDoc in memberships) {
              final membership = membershipDoc.data();
              final userId = (membership['userId'] ?? '').toString();
              final item = _MemberAvailability(
                userId: userId,
                role: _roleLabel((membership['role'] ?? '').toString()),
                availability: availabilityByUserId[userId],
              );
              switch (item.status) {
                case AvailabilityStatus.onDuty:
                  onDuty.add(item);
                  break;
                case AvailabilityStatus.delayed:
                  delayed.add(item);
                  break;
                default:
                  offDuty.add(item);
                  break;
              }
            }

            if (memberships.isEmpty) {
              return const _EmptyCard(
                icon: Icons.group_off_outlined,
                message: 'Organisatsioonis ei ole aktiivseid liikmeid.',
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CountCard(
                        label: 'Valves',
                        count: onDuty.length,
                        color: AppColors.ready,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: AppTheme.itemSpacing),
                    Expanded(
                      child: _CountCard(
                        label: 'Hilinen',
                        count: delayed.length,
                        color: AppColors.delayed,
                        icon: Icons.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _CountCard(
                  label: 'Ei ole valves',
                  count: offDuty.length,
                  color: AppColors.offDuty,
                  icon: Icons.cancel_outlined,
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _buildMinimumCrewCard(onDuty.length),
                const SizedBox(height: AppTheme.itemSpacing),
                _MemberGroupCard(
                  title: 'Valves',
                  type: StatusBadgeType.ready,
                  members: onDuty,
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _MemberGroupCard(
                  title: 'Hilinen',
                  type: StatusBadgeType.delayed,
                  members: delayed,
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _MemberGroupCard(
                  title: 'Ei ole valves',
                  type: StatusBadgeType.offDuty,
                  members: offDuty,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMinimumCrewCard(int onDutyCount) {
    return StreamBuilder<List<PlatformReadinessSummary>>(
      stream: _platformReadinessService.streamOrganizationSummary(
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final summaries =
            snapshot.data ?? const <PlatformReadinessSummary>[];
        if (summaries.isEmpty || summaries.first.minimumCrewRequired <= 0) {
          return const _EmptyCard(
            icon: Icons.info_outline,
            message: 'Miinimumkoosseisu ei ole seadistatud.',
          );
        }

        final requiredCount = summaries.first.minimumCrewRequired;
        final isMet = onDutyCount >= requiredCount;
        final missing = requiredCount - onDutyCount;

        return AppSectionCard(
          accentColor: isMet ? AppColors.ready : AppColors.critical,
          child: Row(
            children: [
              Icon(
                isMet
                    ? Icons.verified_outlined
                    : Icons.warning_amber_rounded,
                color: isMet ? AppColors.ready : AppColors.critical,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Miinimumkoosseis',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMet
                          ? 'Täidetud: $onDutyCount / $requiredCount'
                          : 'Ei ole täidetud. Puudu ${missing > 0 ? missing : 0} liiget.',
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: isMet ? 'TÄIDETUD' : 'HOIATUS',
                type: isMet
                    ? StatusBadgeType.ready
                    : StatusBadgeType.critical,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityReminderSettings() {
    return StreamBuilder<AvailabilityReminderSettingsModel>(
      stream: _availabilityReminderSettingsService.streamMySettings(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final settings = snapshot.data ??
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

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year} ${_formatClock(value)}';
  }

  DateTime _defaultPlannedStart() {
    final now = DateTime.now().add(const Duration(hours: 1));
    return DateTime(now.year, now.month, now.day, now.hour);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _roleLabel(String role) {
    return MembershipRole.isOrgAdmin(role)
        ? 'Organisatsiooni administraator'
        : 'Liige';
  }

  List<String> _reminderTimeOptions(String selectedTime) {
    final times = <String>{
      for (var hour = 0; hour < 24; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
      selectedTime,
    }.toList()
      ..sort();
    return times;
  }

  String _reminderIntervalLabel(int hours) {
    if (hours == 168) return '7 päeva';
    return '$hours tundi';
  }
}

class _MemberAvailability {
  const _MemberAvailability({
    required this.userId,
    required this.role,
    required this.availability,
  });

  final String userId;
  final String role;
  final AvailabilityModel? availability;

  String get status => availability?.status ?? AvailabilityStatus.offDuty;
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
            color: borderColor ??
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      accentColor: color,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _MemberGroupCard extends StatelessWidget {
  const _MemberGroupCard({
    required this.title,
    required this.type,
    required this.members,
  });

  final String title;
  final StatusBadgeType type;
  final List<_MemberAvailability> members;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '$title (${members.length})',
      leading: Icon(_iconFor(type)),
      accentColor: _colorFor(type),
      child: members.isEmpty
          ? Text(
              'Selles grupis liikmeid ei ole.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          : Column(
              children: [
                for (var index = 0; index < members.length; index++) ...[
                  _MemberTile(member: members[index]),
                  if (index < members.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
    );
  }

  IconData _iconFor(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.ready:
        return Icons.check_circle_outline;
      case StatusBadgeType.delayed:
        return Icons.schedule;
      default:
        return Icons.cancel_outlined;
    }
  }

  Color _colorFor(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.ready:
        return AppColors.ready;
      case StatusBadgeType.delayed:
        return AppColors.delayed;
      default:
        return AppColors.offDuty;
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final _MemberAvailability member;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(member.userId)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['name'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final displayName =
            name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Liige');
        final initials = _initials(displayName);
        final minutes = member.availability?.responseMinutes;
        final note = member.availability?.note?.trim();
        final details = <String>[
          member.role,
          if (member.status == AvailabilityStatus.delayed && minutes != null)
            '+ $minutes min',
          if (note != null && note.isNotEmpty) note,
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceBlueStrong,
                foregroundColor: AppColors.navy,
                child: Text(initials),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      details.join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
