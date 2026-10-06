import '../widgets/app_layout.dart';
import 'package:flutter/material.dart';
import '../models/membership_model.dart';
import '../theme/app_theme.dart';
import '../widgets/crew_readiness_card.dart';
import '../widgets/minimum_crew_control.dart';
import '../widgets/organization_duty_control.dart';
import '../widgets/organization_planning.dart';

class OrganizationReadinessScreen extends StatelessWidget {
  const OrganizationReadinessScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    this.organizationName,
    this.membershipRole,
  });
  final String organizationId, currentUid;
  final String? organizationName, membershipRole;
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Ühingu valmidus', maxLines: 2)),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        CrewReadinessCard(
          key: ValueKey('crew-$organizationId'),
          organizationId: organizationId,
          currentUid: currentUid,
        ),
        if (MembershipRole.isOrgAdmin(membershipRole)) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(
                      'Ühingu valve juhtimine',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: const Text('Admini valikud kogu ühingule'),
                  ),
                  MinimumCrewControl(
                    key: ValueKey('minimum-$organizationId'),
                    organizationId: organizationId,
                    organizationName: organizationName,
                    currentUid: currentUid,
                  ),
                  OrganizationDutyControl(
                    key: ValueKey('duty-$organizationId'),
                    organizationId: organizationId,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: OrganizationPlanning(
              key: ValueKey('planning-$organizationId'),
              organizationId: organizationId,
            ),
          ),
        ),
      ],
    ),
  );
}
