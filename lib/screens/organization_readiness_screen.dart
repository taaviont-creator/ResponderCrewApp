import 'platform_readiness_screen.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ühingu reageerimisvalmidus', maxLines: 2),
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        CrewReadinessCard(
          key: ValueKey('crew-$organizationId'),
          organizationId: organizationId,
          currentUid: currentUid,
        ),
        const SizedBox(height: 16),
        OrganizationPlanning(
          key: ValueKey('planning-$organizationId'),
          organizationId: organizationId,
        ),
        if (MembershipRole.isOrgAdmin(membershipRole)) ...[
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Ühingu reageerimisvalmiduse haldus'),
            subtitle: const Text('Ühingu seaded, mitte sinu isiklik staatus'),
            leading: const Icon(Icons.admin_panel_settings_outlined),
            children: [
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
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Tehnika ja kontaktandmed'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlatformReadinessScreen(
                      currentUid: currentUid,
                      activeOrganizationId: organizationId,
                      activeOrganizationName: organizationName,
                      canManageOwnSummary: true,
                      isPlatformAdmin: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
