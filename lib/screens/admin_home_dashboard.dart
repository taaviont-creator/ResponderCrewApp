import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/availability_model.dart';
import '../models/callout_model.dart';
import '../widgets/vessel_status_card.dart';
import '../models/equipment_model.dart';
import '../models/effective_availability.dart';
import '../models/membership_model.dart';
import '../models/platform_readiness_model.dart';
import '../models/response_readiness.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/availability_service.dart';
import '../services/callout_service.dart';
import '../services/equipment_service.dart';
import '../services/membership_service.dart';
import '../services/planned_unavailability_service.dart';
import '../widgets/latest_notifications_card.dart';
import '../widgets/pending_member_requests_notice.dart';
import '../services/platform_readiness_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_badge.dart';

class AdminHomeDashboard extends StatelessWidget {
  AdminHomeDashboard({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.topHeader,
    required this.onCreateCallout,
    required this.onCreateActivity,
    required this.onCreateEquipment,
    required this.onOpenCallouts,
    required this.onOpenCallout,
    required this.onOpenMembers,
    required this.onOpenEquipment,
    required this.onOpenNotifications,
  });

  final String organizationId;
  final String currentUid;
  final Widget topHeader;
  final VoidCallback onCreateCallout;
  final VoidCallback onCreateActivity;
  final VoidCallback onCreateEquipment;
  final VoidCallback onOpenCallouts;
  final ValueChanged<String> onOpenCallout;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenEquipment;
  final VoidCallback onOpenNotifications;

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
        _SectionTitle(
          title: 'Aktiivne väljakutse',
          onOpen: onOpenCallouts,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildActiveCallouts(),
        const SizedBox(height: AppTheme.sectionSpacing),
        topHeader,
        PendingMemberRequestsNotice(
          organizationId: organizationId,
          currentUid: currentUid,
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        Text(
          'Kiirtegevused',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        PrimaryActionButton(
          label: 'Lisa väljakutse',
          icon: Icons.campaign,
          style: PrimaryActionButtonStyle.danger,
          onPressed: onCreateCallout,
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        Text(
          'Ühingu valmisolek',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildReadinessOverview(),
        const SizedBox(height: 12),
        PrimaryActionButton(label: 'Vaata liikmeid', icon: Icons.groups_outlined, style: PrimaryActionButtonStyle.secondary, onPressed: onOpenMembers),
        const SizedBox(height: 12),
        VesselStatusCard(organizationId: organizationId),
        const SizedBox(height: AppTheme.sectionSpacing),

        const SizedBox(height: AppTheme.itemSpacing),
        PrimaryActionButton(
          label: 'Lisa tegevus/koolitus',
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
          title: 'Viimased teavitused',
          onOpen: onOpenNotifications,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildLatestNotifications(),
        const SizedBox(height: AppTheme.sectionSpacing),
      ],
    );
  }

  Widget _buildReadinessOverview() {
    return StreamBuilder<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _membershipService.streamActiveMembershipsForOrganization(
        organizationId,
      ),
      builder: (context, membershipsSnapshot) {
        if (membershipsSnapshot.hasError) return const Text('Valmisoleku laadimine ebaõnnestus. Kontrolli ühendust.');
        if (!membershipsSnapshot.hasData) return const LinearProgressIndicator();
        final memberships = membershipsSnapshot.data ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return StreamBuilder<List<AvailabilityModel>>(
          stream: _availabilityService.streamOrganizationAvailability(
            organizationId: organizationId,
          ),
          builder: (context, availabilitySnapshot) {
        if (availabilitySnapshot.hasError) return const Text('Valmisoleku laadimine ebaõnnestus. Kontrolli ühendust.');
        if (!availabilitySnapshot.hasData) return const LinearProgressIndicator();
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
        if (periodsSnapshot.hasError) return const Text('Valmisoleku laadimine ebaõnnestus. Kontrolli ühendust.');
        if (!periodsSnapshot.hasData) return const LinearProgressIndicator();
                return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
                  stream: _plannedUnavailabilityService.streamOrganizationRules(
                    organizationId: organizationId,
                  ),
                  builder: (context, rulesSnapshot) {
        if (rulesSnapshot.hasError) return const Text('Valmisoleku laadimine ebaõnnestus. Kontrolli ühendust.');
        if (!rulesSnapshot.hasData) return const LinearProgressIndicator();
                    final now = DateTime.now();
                    final periods = periodsSnapshot.data ??
                        const <PlannedUnavailabilityModel>[];
                    final rules = rulesSnapshot.data ??
                        const <PlannedUnavailabilityRuleModel>[];
                    var onDutyCount = 0;
                    var delayedCount = 0;
                    var offDutyCount = 0;
                    var effectiveOnDutySecondLevelCount = 0;

                    for (final membership in memberships) {
                      final membershipData = membership.data();
                      final userId =
                          (membershipData['userId'] ?? '').toString();
                      final manualStatus = availabilityByUserId[userId]?.status ??
                          AvailabilityStatus.offDuty;
                      final status = EffectiveAvailability.resolve(
                        userId: userId,
                        manualStatus: manualStatus,
                        periods: periods,
                        rules: rules,
                        now: now,
                      );
                      if (status == AvailabilityStatus.onDuty) {
                        onDutyCount++;
                        if (SeaRescueLevel.isLevel2(
                          membershipData['seaRescueLevel'],
                        )) {
                          effectiveOnDutySecondLevelCount++;
                        }
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
        if (readinessSnapshot.hasError) return const Text('Valmisoleku laadimine ebaõnnestus. Kontrolli ühendust.');
        if (!readinessSnapshot.hasData) return const LinearProgressIndicator();
                        final summaries = readinessSnapshot.data ??
                            const <PlatformReadinessSummary>[];
                        final summary =
                            summaries.isEmpty ? null : summaries.first;
                        final minimumCrewRequired =
                            summary?.minimumCrewRequired ?? 0;

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
                            _MinimumCrewCompact(
                              minimumCrewRequired: minimumCrewRequired,
                              onDutyCount: onDutyCount,
                              secondLevelOnDutyCount:
                                  effectiveOnDutySecondLevelCount,
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

        if (snapshot.hasError) return const AppSectionCard(child: Text('Varustuse hoiatusi ei õnnestunud laadida.'));
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

        if (snapshot.hasError) return const AppSectionCard(child: Text('Väljakutse laadimine ebaõnnestus. Kontrolli ühendust.'));
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
            onTap: () => onOpenCallout(callout.id),
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
            '${CalloutType.label(callout.calloutType)} · ${callout.title}',
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
                      const SizedBox(height: 8),
                      _buildMyCalloutResponseStatus(
                        context,
                        callout.id,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Ava väljakutse',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.activeCallout,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyCalloutResponseStatus(
    BuildContext context,
    String calloutId,
  ) {
    return StreamBuilder<CalloutResponseModel?>(
      stream: _calloutService.streamMyResponse(
        calloutId: calloutId,
        userId: currentUid,
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        final response = snapshot.data;
        final color = switch (response?.response) {
          CalloutResponseValue.responding => AppColors.ready,
          CalloutResponseValue.delayed => AppColors.delayed,
          CalloutResponseValue.unavailable => AppColors.critical,
          _ => AppColors.textSecondary,
        };

        return Text(
          _myCalloutResponseLabel(response),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        );
      },
    );
  }

  String _myCalloutResponseLabel(CalloutResponseModel? response) {
    return switch (response?.response) {
      CalloutResponseValue.responding => 'Sinu vastus: Tulen',
      CalloutResponseValue.delayed => response?.responseMinutes == null
          ? 'Sinu vastus: Hilinen'
          : 'Sinu vastus: Hilinen · ${response!.responseMinutes} min',
      CalloutResponseValue.unavailable => 'Sinu vastus: Ei tule',
      _ => 'Vastus puudub',
    };
  }

  Widget _buildLatestNotifications() {
    return LatestNotificationsCard(
      organizationId: organizationId,
      currentUid: currentUid,
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

class _MinimumCrewCompact extends StatelessWidget {
  const _MinimumCrewCompact({
    required this.minimumCrewRequired,
    required this.onDutyCount,
    required this.secondLevelOnDutyCount,
  });

  final int minimumCrewRequired;
  final int onDutyCount;
  final int secondLevelOnDutyCount;

  @override
  Widget build(BuildContext context) {
    final readiness = ResponseReadiness.evaluate(
      minimumCrewRequired: minimumCrewRequired,
      onDutyCount: onDutyCount,
      secondLevelOnDutyCount: secondLevelOnDutyCount,
    );
    final responseReady = readiness.isReady;
    final readinessReasons = readiness.missingRequirements;
    final color = !readiness.isConfigured
        ? AppColors.textSecondary
        : responseReady
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const SizedBox(width: 12),
              _MinimumCrewValue(
                label: 'II aste',
                value: secondLevelOnDutyCount,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            responseReady
                ? 'Ühing on reageerimiseks valmis'
                : 'Ühing ei ole reageerimiseks valmis',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (!responseReady && readinessReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final reason in readinessReasons) ...[
              _ReadinessReasonLine(label: reason),
              if (reason != readinessReasons.last) const SizedBox(height: 2),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReadinessReasonLine extends StatelessWidget {
  const _ReadinessReasonLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline,
          color: AppColors.critical,
          size: 14,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.critical,
                ),
          ),
        ),
      ],
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
