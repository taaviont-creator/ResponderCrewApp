import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/availability_model.dart';
import '../models/callout_model.dart';
import '../models/equipment_model.dart';
import '../models/platform_readiness_model.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/availability_service.dart';
import '../services/callout_service.dart';
import '../services/equipment_service.dart';
import '../services/membership_service.dart';
import '../services/planned_unavailability_service.dart';
import '../widgets/latest_notifications_card.dart';
import '../services/platform_readiness_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_badge.dart';

class AdminHomeDashboard extends StatelessWidget {
  AdminHomeDashboard({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.onCreateCallout,
    required this.onCreateActivity,
    required this.onCreateEquipment,
    required this.onOpenCallouts,
    required this.onOpenEquipment,
    required this.onOpenNotifications,
    required this.onOpenOrganizationSettings,
  });

  final String organizationId;
  final String? organizationName;
  final VoidCallback onCreateCallout;
  final VoidCallback onCreateActivity;
  final VoidCallback onCreateEquipment;
  final VoidCallback onOpenCallouts;
  final VoidCallback onOpenEquipment;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenOrganizationSettings;

  final AvailabilityService _availabilityService = AvailabilityService();
  final CalloutService _calloutService = CalloutService();
  final EquipmentService _equipmentService = EquipmentService();
  final MembershipService _membershipService = MembershipService();
  final PlannedUnavailabilityService _plannedUnavailabilityService =
      PlannedUnavailabilityService();
  final PlatformReadinessService _readinessService =
      PlatformReadinessService();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        _buildOrganizationCard(context),
        const SizedBox(height: AppTheme.sectionSpacing),
        Text(
          'Ühingu valmisolek',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildReadinessOverview(),
        const SizedBox(height: AppTheme.sectionSpacing),
        Text(
          'Kiirtegevused',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        PrimaryActionButton(
          label: 'LOO VÄLJAKUTSE',
          icon: Icons.campaign,
          style: PrimaryActionButtonStyle.danger,
          onPressed: onCreateCallout,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        PrimaryActionButton(
          label: 'Lisa tegevus',
          icon: Icons.event_available_outlined,
          style: PrimaryActionButtonStyle.secondary,
          onPressed: onCreateActivity,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        PrimaryActionButton(
          label: 'Lisa varustus',
          icon: Icons.build_outlined,
          style: PrimaryActionButtonStyle.secondary,
          onPressed: onCreateEquipment,
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Varustuse hoiatused',
          onOpen: onOpenEquipment,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildEquipmentAlerts(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Aktiivsed väljakutsed',
          onOpen: onOpenCallouts,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildActiveCallouts(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Viimased teavitused',
          onOpen: onOpenNotifications,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildLatestNotifications(),
        const SizedBox(height: AppTheme.sectionSpacing),
      ],
    );
  }

  Widget _buildOrganizationCard(BuildContext context) {
    final name = organizationName?.trim();

    return AppSectionCard(
      child: Row(
        children: [
          const Icon(Icons.anchor, color: AppColors.navy, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty
                      ? 'Aktiivne organisatsioon'
                      : name,
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
            label: 'ADMIN',
            type: StatusBadgeType.neutral,
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onOpenOrganizationSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Organisatsiooni seaded',
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessOverview() {
    return StreamBuilder<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _membershipService.streamActiveMembershipsForOrganization(
        organizationId,
      ),
      builder: (context, membershipsSnapshot) {
        final memberships = membershipsSnapshot.data ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return StreamBuilder<List<AvailabilityModel>>(
          stream: _availabilityService.streamOrganizationAvailability(
            organizationId: organizationId,
          ),
          builder: (context, availabilitySnapshot) {
            final availabilityByUserId = <String, AvailabilityModel>{
              for (final availability
                  in availabilitySnapshot.data ?? const <AvailabilityModel>[])
                if (availability.userId.isNotEmpty)
                  availability.userId: availability,
            };

            return StreamBuilder<List<PlannedUnavailabilityModel>>(
              stream: _plannedUnavailabilityService.streamOrganizationPeriods(
                organizationId: organizationId,
              ),
              builder: (context, periodsSnapshot) {
                return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
                  stream: _plannedUnavailabilityService.streamOrganizationRules(
                    organizationId: organizationId,
                  ),
                  builder: (context, rulesSnapshot) {
                    final now = DateTime.now();
                    final periods = periodsSnapshot.data ??
                        const <PlannedUnavailabilityModel>[];
                    final rules = rulesSnapshot.data ??
                        const <PlannedUnavailabilityRuleModel>[];
                    var onDutyCount = 0;
                    var delayedCount = 0;
                    var offDutyCount = 0;

                    for (final membership in memberships) {
                      final userId =
                          (membership.data()['userId'] ?? '').toString();
                      final manualStatus = availabilityByUserId[userId]?.status ??
                          AvailabilityStatus.offDuty;
                      final status = _effectiveAvailabilityStatus(
                        userId: userId,
                        manualStatus: manualStatus,
                        periods: periods,
                        rules: rules,
                        now: now,
                      );
                      if (status == AvailabilityStatus.onDuty) {
                        onDutyCount++;
                      } else if (status == AvailabilityStatus.delayed) {
                        delayedCount++;
                      } else {
                        offDutyCount++;
                      }
                    }

                    return StreamBuilder<List<PlatformReadinessSummary>>(
                      stream: _readinessService.streamOrganizationSummary(
                        organizationId: organizationId,
                      ),
                      builder: (context, readinessSnapshot) {
                        final summaries = readinessSnapshot.data ??
                            const <PlatformReadinessSummary>[];
                        final summary =
                            summaries.isEmpty ? null : summaries.first;
                        final minimumCrewRequired =
                            summary?.minimumCrewRequired ?? 0;
                        final minimumCrewMet = minimumCrewRequired > 0 &&
                            onDutyCount >= minimumCrewRequired;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _ReadinessCountCard(
                                    label: 'Valves',
                                    count: onDutyCount,
                                    icon: Icons.check_circle_outline,
                                    color: AppColors.ready,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.itemSpacing),
                                Expanded(
                                  child: _ReadinessCountCard(
                                    label: 'Hilinen',
                                    count: delayedCount,
                                    icon: Icons.schedule,
                                    color: AppColors.delayed,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.itemSpacing),
                            _ReadinessCountCard(
                              label: 'Ei ole valves',
                              count: offDutyCount,
                              icon: Icons.cancel_outlined,
                              color: AppColors.offDuty,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Valves liikmete arv arvestab aktiivseid '
                              'planeeritud mittevalves aegu.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.itemSpacing),
                            _MinimumCrewCard(
                              minimumCrewRequired: minimumCrewRequired,
                              onDutyCount: onDutyCount,
                              minimumCrewMet: minimumCrewMet,
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _effectiveAvailabilityStatus({
    required String userId,
    required String manualStatus,
    required Iterable<PlannedUnavailabilityModel> periods,
    required Iterable<PlannedUnavailabilityRuleModel> rules,
    required DateTime now,
  }) {
    if (_hasActivePlannedUnavailability(
          userId: userId,
          periods: periods,
          now: now,
        ) ||
        _hasActivePlannedUnavailabilityRule(
          userId: userId,
          rules: rules,
          now: now,
        )) {
      return AvailabilityStatus.offDuty;
    }

    return manualStatus;
  }

  bool _hasActivePlannedUnavailability({
    required String userId,
    required Iterable<PlannedUnavailabilityModel> periods,
    required DateTime now,
  }) {
    return periods.any((period) {
      final startAt = period.startAt;
      final endAt = period.endAt;
      if (period.userId != userId ||
          !period.isActive ||
          startAt == null ||
          endAt == null) {
        return false;
      }
      return !now.isBefore(startAt) && now.isBefore(endAt);
    });
  }

  bool _hasActivePlannedUnavailabilityRule({
    required String userId,
    required Iterable<PlannedUnavailabilityRuleModel> rules,
    required DateTime now,
  }) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return rules.any((rule) {
      return rule.userId == userId &&
          rule.isActive &&
          rule.daysOfWeek.contains(now.weekday) &&
          minuteOfDay >= rule.startMinute &&
          minuteOfDay < rule.endMinute;
    });
  }

  Widget _buildEquipmentAlerts() {
    return StreamBuilder<List<EquipmentModel>>(
      stream: _equipmentService.streamOrganizationEquipment(
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _PreviewLoadingCard();
        }

        final alerts = (snapshot.data ?? const <EquipmentModel>[])
            .where(
              (item) =>
                  !item.isPersonal && item.status != EquipmentStatus.ok,
            )
            .toList();

        if (alerts.isEmpty) {
          return const _EmptyPreviewCard(
            icon: Icons.verified_outlined,
            message: 'Ühingu varustusel aktiivseid hoiatusi ei ole.',
          );
        }

        return AppSectionCard(
          padding: EdgeInsets.zero,
          accentColor: AppColors.equipmentWarning,
          child: Column(
            children: [
              for (var index = 0;
                  index < alerts.length && index < 2;
                  index++) ...[
                _EquipmentAlertTile(
                  item: alerts[index],
                  onTap: onOpenEquipment,
                ),
                if (index < alerts.length - 1 && index < 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveCallouts() {
    return StreamBuilder<List<CalloutModel>>(
      stream: _calloutService.streamActiveCallouts(
        organizationId: organizationId,
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
          child: InkWell(
            onTap: onOpenCallouts,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.campaign,
                  color: AppColors.activeCallout,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StatusBadge(
                        label: 'AKTIIVNE',
                        type: StatusBadgeType.activeCallout,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        callout.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (callout.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          callout.location,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
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
      organizationId: organizationId,
      onTap: onOpenNotifications,
      usePriorityIcons: false,
    );
  }
}

class _ReadinessCountCard extends StatelessWidget {
  const _ReadinessCountCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _MinimumCrewCard extends StatelessWidget {
  const _MinimumCrewCard({
    required this.minimumCrewRequired,
    required this.onDutyCount,
    required this.minimumCrewMet,
  });

  final int minimumCrewRequired;
  final int onDutyCount;
  final bool minimumCrewMet;

  @override
  Widget build(BuildContext context) {
    if (minimumCrewRequired <= 0) {
      return const AppSectionCard(
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text('Miinimumkoosseisu ei ole seadistatud.'),
            ),
          ],
        ),
      );
    }

    final color = minimumCrewMet ? AppColors.ready : AppColors.critical;

    return AppSectionCard(
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                minimumCrewMet
                    ? Icons.verified_outlined
                    : Icons.warning_amber_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Text(
                'Miinimumkoosseis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatusBadge(
            label: minimumCrewMet
                ? 'Miinimumkoosseis täidetud'
                : 'Valmisolek alla miinimumi',
            type: minimumCrewMet
                ? StatusBadgeType.ready
                : StatusBadgeType.critical,
          ),
          const SizedBox(height: 10),
          Text(
            'Miinimum: $minimumCrewRequired\n'
            'Hetkel valves: $onDutyCount',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
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

class _EquipmentAlertTile extends StatelessWidget {
  const _EquipmentAlertTile({
    required this.item,
    required this.onTap,
  });

  final EquipmentModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCritical = item.status == EquipmentStatus.broken ||
        item.status == EquipmentStatus.outOfService;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(
              label: isCritical ? 'KRIITILINE' : 'VAJAB HOOLDUST',
              type: isCritical
                  ? StatusBadgeType.critical
                  : StatusBadgeType.equipmentWarning,
            ),
          ],
        ),
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
