import '../widgets/upcoming_activities.dart';
import 'package:flutter/material.dart';

import '../models/callout_model.dart';
import '../widgets/crew_readiness_card.dart';
import '../models/equipment_model.dart';
import '../services/callout_service.dart';
import '../services/equipment_service.dart';
import '../widgets/pending_member_requests_notice.dart';
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

  final CalloutService _calloutService = CalloutService();
  final EquipmentService _equipmentService = EquipmentService();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        topHeader,
        const SizedBox(height: 16),
        CrewReadinessCard(organizationId: organizationId, currentUid: currentUid),
        const SizedBox(height: 16),
        PendingMemberRequestsNotice(organizationId: organizationId, currentUid: currentUid),
        Text('Kiirtegevused', style: Theme.of(context).textTheme.titleLarge),
        PrimaryActionButton(label: 'Loo väljakutse', icon: Icons.campaign_outlined,
          style: PrimaryActionButtonStyle.danger, onPressed: onCreateCallout),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: onCreateActivity, icon: const Icon(Icons.event_available), label: const Text('Lisa tegevus / koolitus')),
        const SizedBox(height: 16),
        _buildActiveCallouts(),
        const SizedBox(height: 16),
        Text('Lähiaja tegevused ja koolitused', style: Theme.of(context).textTheme.titleLarge),
        UpcomingActivities(key: ValueKey(organizationId), organizationId: organizationId, userId: currentUid),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Alused ja varustus', onOpen: onOpenEquipment),
        const SizedBox(height: 8),
        _buildEquipmentAlerts(),
        const SizedBox(height: 16),
      ],
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

        if (snapshot.hasError) return const AppSectionCard(child: Text('Aluste ja varustuse seisundit ei õnnestunud laadida.'));
        final alerts = (snapshot.data ?? const <EquipmentModel>[])
            .where(
              (item) =>
                  !item.isPersonal && (item.category == EquipmentCategory.vessel || item.status != EquipmentStatus.ok),
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
          accentColor: alerts.any((item) => item.status != EquipmentStatus.ok)
              ? AppColors.equipmentWarning : null,
          child: Column(
            children: [
              for (var index = 0;
                  index < alerts.length;
                  index++) ...[
                _EquipmentAlertTile(
                  item: alerts[index],
                  onTap: onOpenEquipment,
                ),
                if (index < alerts.length - 1)
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
          return const SizedBox.shrink();
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
            Flexible(child: StatusBadge(
              label: switch (item.status) {
                EquipmentStatus.ok => 'Korras',
                EquipmentStatus.needsMaintenance => 'Vajab hooldust',
                EquipmentStatus.broken => 'Rikkis',
                EquipmentStatus.outOfService => 'Kasutusest väljas',
                _ => 'Seisund teadmata',
              },
              type: isCritical
                  ? StatusBadgeType.critical
                  : item.status == EquipmentStatus.ok
                      ? StatusBadgeType.ready : StatusBadgeType.equipmentWarning,
            )),
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
