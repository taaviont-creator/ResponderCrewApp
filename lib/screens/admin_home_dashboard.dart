import '../widgets/upcoming_activities.dart';
import 'package:flutter/material.dart';

import '../widgets/active_callouts_card.dart';
import '../widgets/crew_readiness_card.dart';
import '../models/equipment_model.dart';
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
    required this.currentUserName,
    required this.topHeader,
    required this.onCreateCallout,
    required this.onCreateActivity,
    required this.onCreateEquipment,
    required this.onOpenCallouts,
    required this.onOpenReadiness,
    required this.onOpenCallout,
    required this.onOpenMembers,
    required this.onOpenEquipment,
    required this.onOpenNotifications,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final Widget topHeader;
  final VoidCallback onCreateCallout;
  final VoidCallback onCreateActivity;
  final VoidCallback onCreateEquipment;
  final VoidCallback onOpenCallouts;
  final VoidCallback onOpenReadiness;
  final ValueChanged<String> onOpenCallout;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenEquipment;
  final VoidCallback onOpenNotifications;

  final EquipmentService _equipmentService = EquipmentService();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        ActiveCalloutsCard(key: ValueKey(organizationId), organizationId: organizationId, userId: currentUid, userName: currentUserName, onOpen: onOpenCallout),
        topHeader,
        const SizedBox(height: 16),
        CrewReadinessCard( onOpenDetails: onOpenReadiness, organizationId: organizationId, currentUid: currentUid),
        const SizedBox(height: 16),
        PendingMemberRequestsNotice(organizationId: organizationId, currentUid: currentUid),
        Text('Kiirtegevused', style: Theme.of(context).textTheme.titleLarge),
        PrimaryActionButton(label: 'Loo väljakutse', icon: Icons.campaign_outlined,
          style: PrimaryActionButtonStyle.danger, onPressed: onCreateCallout),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: onCreateActivity, icon: const Icon(Icons.event_available), label: const Text('Lisa tegevus / koolitus')),
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
