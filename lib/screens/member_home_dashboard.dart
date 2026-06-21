import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../models/availability_model.dart';
import '../models/callout_model.dart';
import '../models/platform_readiness_model.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/activity_service.dart';
import '../services/availability_service.dart';
import '../services/callout_service.dart';
import '../services/platform_readiness_service.dart';
import '../services/planned_unavailability_service.dart';
import '../widgets/latest_notifications_card.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/status_badge.dart';

class MemberHomeDashboard extends StatefulWidget {
  const MemberHomeDashboard({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.currentUid,
    required this.currentUserName,
    required this.onOpenCallouts,
    required this.onOpenNotifications,
    required this.onOpenActivities,
  });

  final String organizationId;
  final String? organizationName;
  final String currentUid;
  final String currentUserName;
  final VoidCallback onOpenCallouts;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenActivities;

  @override
  State<MemberHomeDashboard> createState() => _MemberHomeDashboardState();
}

class _MemberHomeDashboardState extends State<MemberHomeDashboard> {
  final _activityService = ActivityService();
  final _availabilityService = AvailabilityService();
  final _calloutService = CalloutService();
  final _plannedUnavailabilityService = PlannedUnavailabilityService();
  final _readinessService = PlatformReadinessService();
  var _isUpdatingAvailability = false;

  Future<void> _updateAvailability(
    String status, {
    int? responseMinutes,
  }) async {
    if (_isUpdatingAvailability) return;

    setState(() => _isUpdatingAvailability = true);
    try {
      await _availabilityService.setMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
        memberName: widget.currentUserName,
        status: status,
        responseMinutes: responseMinutes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Valmiduse muutmine ebaõnnestus: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvailability = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        _buildOrganizationCard(),
        const SizedBox(height: AppTheme.sectionSpacing),
        Text(
          'Minu valmisolek',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildAvailabilityCard(),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildMinimumCrewCompact(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Viimane väljakutse',
          onOpen: widget.onOpenCallouts,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildLatestCallout(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Tulev tegevus',
          onOpen: widget.onOpenActivities,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildUpcomingActivity(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Viimased teavitused',
          onOpen: widget.onOpenNotifications,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildLatestNotifications(),
        const SizedBox(height: AppTheme.sectionSpacing),
      ],
    );
  }

  Widget _buildOrganizationCard() {
    final organizationName = widget.organizationName?.trim();

    return AppSectionCard(
      child: Row(
        children: [
          const Icon(
            Icons.anchor,
            color: AppColors.navy,
            size: 30,
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 2),
                Text(
                  'Aktiivne organisatsioon',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const StatusBadge(
            label: 'LIIGE',
            type: StatusBadgeType.neutral,
            icon: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final availability = snapshot.data;
        final status = availability?.status ?? AvailabilityStatus.offDuty;
        final storedResponseMinutes = availability?.responseMinutes ?? 15;
        final responseMinutes = const {15, 30, 60}.contains(
          storedResponseMinutes,
        )
            ? storedResponseMinutes
            : 15;
        final updatedAt = availability?.updatedAt;

        return _buildAvailabilityCardWithSchedule(
          status: status,
          responseMinutes: responseMinutes,
          updatedAt: updatedAt,
        );
      },
    );
  }

  Widget _buildAvailabilityCardWithSchedule({
    required String status,
    required int responseMinutes,
    required DateTime? updatedAt,
  }) {
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
            final rules = rulesSnapshot.data ??
                const <PlannedUnavailabilityRuleModel>[];
            final hasActiveSchedule =
                _hasActivePlannedUnavailability(periods, now) ||
                    _hasActivePlannedUnavailabilityRule(rules, now);
            final effectiveStatus = hasActiveSchedule
                ? AvailabilityStatus.offDuty
                : status;

            return _buildAvailabilityCardContent(
              status: status,
              effectiveStatus: effectiveStatus,
              hasActiveSchedule: hasActiveSchedule,
              responseMinutes: responseMinutes,
              updatedAt: updatedAt,
            );
          },
        );
      },
    );
  }

  Widget _buildAvailabilityCardContent({
    required String status,
    required String effectiveStatus,
    required bool hasActiveSchedule,
    required int responseMinutes,
    required DateTime? updatedAt,
  }) {
    return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _availabilityBadge(
                      effectiveStatus,
                      plannedOffDuty: hasActiveSchedule,
                    ),
                  ),
                  if (updatedAt != null)
                    Text(
                      'Uuendatud ${_formatClock(updatedAt)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
              if (hasActiveSchedule) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.offDutySurface,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    border: Border.all(color: AppColors.offDuty),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Planeeritud mittevalves aeg on aktiivne.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.offDuty,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nähtav staatus: Valvest väljas',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Käsitsi staatus: ${_availabilityStatusText(status)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _AvailabilityButton(
                label: 'VALVES',
                icon: Icons.check_circle_outline,
                isSelected: status == AvailabilityStatus.onDuty,
                backgroundColor: AppColors.ready,
                foregroundColor: Colors.white,
                onPressed: _isUpdatingAvailability
                    ? null
                    : () => _updateAvailability(AvailabilityStatus.onDuty),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _AvailabilityButton(
                label: 'EI OLE VALVES',
                icon: Icons.cancel_outlined,
                isSelected: status == AvailabilityStatus.offDuty,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.offDuty,
                borderColor: AppColors.offDuty,
                onPressed: _isUpdatingAvailability
                    ? null
                    : () => _updateAvailability(AvailabilityStatus.offDuty),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              Row(
                children: [
                  Expanded(
                    child: _AvailabilityButton(
                      label: 'HILINEN',
                      icon: Icons.schedule,
                      isSelected: status == AvailabilityStatus.delayed,
                      backgroundColor: AppColors.delayedSurface,
                      foregroundColor: AppColors.delayed,
                      borderColor: status == AvailabilityStatus.delayed
                          ? AppColors.delayed
                          : null,
                      onPressed: _isUpdatingAvailability
                          ? null
                          : () => _updateAvailability(
                                AvailabilityStatus.delayed,
                                responseMinutes: responseMinutes,
                              ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.itemSpacing),
                  Container(
                    height: AppTheme.primaryActionHeight,
                    constraints: const BoxConstraints(minWidth: 104),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppTheme.controlRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: responseMinutes,
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                        ],
                        onChanged: _isUpdatingAvailability
                            ? null
                            : (value) {
                                if (value == null) return;
                                _updateAvailability(
                                  AvailabilityStatus.delayed,
                                  responseMinutes: value,
                                );
                              },
                      ),
                    ),
                  ),
                ],
              ),
              if (_isUpdatingAvailability) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        );
  }

  Widget _buildMinimumCrewCompact() {
    return StreamBuilder<List<PlatformReadinessSummary>>(
      stream: _readinessService.streamOrganizationSummary(
        organizationId: widget.organizationId,
      ),
      builder: (context, readinessSnapshot) {
        final summaries =
            readinessSnapshot.data ?? const <PlatformReadinessSummary>[];
        final summary = summaries.isEmpty ? null : summaries.first;

        return _MinimumCrewCompact(
          minimumCrewRequired: summary?.minimumCrewRequired ?? 0,
          onDutyCount: summary?.onDutyCount ?? 0,
          minimumCrewMet: summary?.minimumCrewMet ?? false,
        );
      },
    );
  }

  bool _hasActivePlannedUnavailability(
    Iterable<PlannedUnavailabilityModel> periods,
    DateTime now,
  ) {
    return periods.any((period) {
      final startAt = period.startAt;
      final endAt = period.endAt;
      if (!period.isActive || startAt == null || endAt == null) {
        return false;
      }
      return !now.isBefore(startAt) && now.isBefore(endAt);
    });
  }

  bool _hasActivePlannedUnavailabilityRule(
    Iterable<PlannedUnavailabilityRuleModel> rules,
    DateTime now,
  ) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return rules.any((rule) {
      return rule.isActive &&
          rule.daysOfWeek.contains(now.weekday) &&
          minuteOfDay >= rule.startMinute &&
          minuteOfDay < rule.endMinute;
    });
  }

  Widget _availabilityBadge(String status, {bool plannedOffDuty = false}) {
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
        return StatusBadge(
          label: plannedOffDuty ? 'VALVEST VÄLJAS' : 'EI OLE VALVES',
          type: StatusBadgeType.offDuty,
        );
    }
  }

  String _availabilityStatusText(String status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return 'Valves';
      case AvailabilityStatus.delayed:
        return 'Hilinen';
      default:
        return 'Ei ole valves';
    }
  }

  Widget _buildLatestCallout() {
    return StreamBuilder<List<CalloutModel>>(
      stream: _calloutService.streamActiveCallouts(
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _PreviewLoadingCard();
        }

        final callouts = snapshot.data ?? const <CalloutModel>[];
        if (callouts.isEmpty) {
          return const _EmptyPreviewCard(
            icon: Icons.campaign_outlined,
            message: 'Aktiivseid väljakutseid ei ole.',
          );
        }

        final callout = callouts.first;
        return AppSectionCard(
          accentColor: AppColors.activeCallout,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatusBadge(
                      label: _calloutPriorityLabel(callout.priority),
                      type: callout.priority == CalloutPriority.critical
                          ? StatusBadgeType.critical
                          : StatusBadgeType.activeCallout,
                    ),
                  ),
                  if (callout.createdAt != null)
                    Text(
                      _relativeTime(callout.createdAt!),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                callout.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (callout.location.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(callout.location)),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: AppTheme.primaryActionHeight,
                child: ElevatedButton.icon(
                  onPressed: widget.onOpenCallouts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeCallout,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.controlRadius),
                    ),
                  ),
                  icon: const Icon(Icons.campaign),
                  label: const Text('AVA VÄLJAKUTSE'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingActivity() {
    return StreamBuilder<List<ActivityModel>>(
      stream: _activityService.streamOrganizationActivities(
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _PreviewLoadingCard();
        }

        final activity = _nextActivity(
          snapshot.data ?? const <ActivityModel>[],
        );
        if (activity == null) {
          return const _EmptyPreviewCard(
            icon: Icons.event_outlined,
            message: 'Tulevasi tegevusi ega koolitusi ei ole.',
          );
        }

        return AppSectionCard(
          child: InkWell(
            onTap: widget.onOpenActivities,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.deepSeaBlue,
                    borderRadius:
                        BorderRadius.circular(AppTheme.controlRadius),
                  ),
                  child: Icon(
                    activity.type == ActivityType.training
                        ? Icons.school_outlined
                        : Icons.event_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (activity.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          activity.location,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                      if (activity.startTime.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activity.startTime,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLatestNotifications() {
    return LatestNotificationsCard(
      organizationId: widget.organizationId,
      onTap: widget.onOpenNotifications,
      usePriorityIcons: true,
    );
  }

  ActivityModel? _nextActivity(List<ActivityModel> activities) {
    final now = DateTime.now();
    final upcoming = activities.where((activity) {
      final startTime = DateTime.tryParse(activity.startTime);
      return startTime != null && !startTime.isBefore(now);
    }).toList()
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a.startTime)!;
        final bTime = DateTime.tryParse(b.startTime)!;
        return aTime.compareTo(bTime);
      });

    return upcoming.isEmpty ? null : upcoming.first;
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Praegu';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min tagasi';
    if (difference.inHours < 24) return '${difference.inHours} h tagasi';
    return '${difference.inDays} p tagasi';
  }

  String _calloutPriorityLabel(String priority) {
    switch (priority) {
      case CalloutPriority.critical:
        return 'KRIITILINE';
      case CalloutPriority.high:
        return 'KÕRGE PRIORITEET';
      case CalloutPriority.low:
        return 'MADAL PRIORITEET';
      default:
        return 'AKTIIVNE';
    }
  }
}

class _MinimumCrewCompact extends StatelessWidget {
  const _MinimumCrewCompact({
    required this.minimumCrewRequired,
    required this.onDutyCount,
    required this.minimumCrewMet,
  });

  final int minimumCrewRequired;
  final int onDutyCount;
  final bool minimumCrewMet;

  @override
  Widget build(BuildContext context) {
    final color = minimumCrewRequired <= 0
        ? AppColors.textSecondary
        : minimumCrewMet
            ? AppColors.ready
            : AppColors.critical;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_2_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Miinimumkoosseis',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                  ),
            ),
          ),
          _MinimumCrewValue(
            label: 'Miinimum',
            value: minimumCrewRequired,
          ),
          const SizedBox(width: 12),
          _MinimumCrewValue(
            label: 'Valves',
            value: onDutyCount,
          ),
        ],
      ),
    );
  }
}

class _MinimumCrewValue extends StatelessWidget {
  const _MinimumCrewValue({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.onOpen,
  });

  final String title;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton(
          onPressed: onOpen,
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Ava kõik',
        ),
      ],
    );
  }
}

class _AvailabilityButton extends StatelessWidget {
  const _AvailabilityButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.primaryActionHeight,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: isSelected ? 2 : 0,
          side: BorderSide(
            color: borderColor ??
                (isSelected ? foregroundColor : Colors.transparent),
            width: isSelected ? 2 : 1,
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

class _EmptyPreviewCard extends StatelessWidget {
  const _EmptyPreviewCard({
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
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLoadingCard extends StatelessWidget {
  const _PreviewLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
