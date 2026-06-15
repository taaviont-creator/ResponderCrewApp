import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/availability_model.dart';
import '../models/callout_model.dart';
import '../models/equipment_model.dart';
import '../models/notification_model.dart';
import '../models/platform_readiness_model.dart';
import '../services/availability_service.dart';
import '../services/callout_service.dart';
import '../services/equipment_service.dart';
import '../services/membership_service.dart';
import '../services/notification_service.dart';
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
  final NotificationService _notificationService = NotificationService();
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

            var onDutyCount = 0;
            var delayedCount = 0;
            var offDutyCount = 0;

            for (final membership in memberships) {
              final userId = (membership.data()['userId'] ?? '').toString();
              final status = availabilityByUserId[userId]?.status ??
                  AvailabilityStatus.offDuty;
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
                final summary = summaries.isEmpty ? null : summaries.first;
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
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.streamOrganizationNotifications(
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _PreviewLoadingCard();
        }

        final notifications =
            (snapshot.data ?? const <NotificationModel>[]).take(2).toList();
        if (notifications.isEmpty) {
          return const _EmptyPreviewCard(
            icon: Icons.notifications_none,
            message: 'Uusi teavitusi ei ole.',
          );
        }

        return AppSectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < notifications.length; index++) ...[
                _NotificationTile(
                  notification: notifications[index],
                  onTap: onOpenNotifications,
                ),
                if (index < notifications.length - 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        );
      },
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

    final missingCount = minimumCrewRequired - onDutyCount;
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
            label: minimumCrewMet ? 'TÄIDETUD' : 'EI OLE TÄIDETUD',
            type: minimumCrewMet
                ? StatusBadgeType.ready
                : StatusBadgeType.critical,
          ),
          const SizedBox(height: 10),
          Text(
            minimumCrewMet
                ? 'Valves $onDutyCount / vajalik $minimumCrewRequired'
                : 'Puudu ${missingCount > 0 ? missingCount : 0} liiget',
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: AppColors.navy,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (notification.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
