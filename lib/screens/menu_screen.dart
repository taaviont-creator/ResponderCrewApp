import '../widgets/platform_pending_badge.dart';
import 'notification_settings_screen.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/pending_invites_section.dart';
import 'activities_screen.dart';
import 'equipment_screen.dart';
import 'members_screen.dart';
import 'operation_log_screen.dart';
import 'platform_management_screen.dart';
import 'self_profile_screen.dart';
import 'statistics_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.currentUid,
    required this.currentUserName,
    required this.isOrganizationAdmin,
    required this.isPlatformAdmin,
    required this.canCreateActivities,
    required this.canViewStatistics,
    required this.canStartOperationLog,
    required this.onOpenOrganizationSettings,
    this.onSwitchOrganization,
    this.onOpenNotifications,
  });

  final VoidCallback? onOpenNotifications;
  final String organizationId;
  final String? organizationName;
  final String currentUid;
  final String currentUserName;
  final bool isOrganizationAdmin;
  final bool isPlatformAdmin;
  final bool canCreateActivities;
  final bool canViewStatistics;
  final bool canStartOperationLog;
  final VoidCallback onOpenOrganizationSettings;
  final VoidCallback? onSwitchOrganization;

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {

    final canManageEquipment = isOrganizationAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Menüü')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          Text(
            organizationName?.trim().isNotEmpty == true
                ? organizationName!
                : 'RespondCrew',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            isOrganizationAdmin ? 'Administraator' : 'Liige',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const PendingInvitesSection(),
          if (onOpenNotifications != null) _MenuEntry(icon: Icons.notifications_outlined,
            title: 'Teavitused', subtitle: 'Ühingu teated', onTap: onOpenNotifications!),
          _MenuEntry(icon: Icons.notifications_active_outlined, title: 'Teavituste seaded', subtitle: 'Sinu valikud ja SAR-häire heli',
            onTap: () => _open(context, NotificationSettingsScreen(organizationId: organizationId, userId: currentUid, isAdmin: isOrganizationAdmin))),
          const SizedBox(height: AppTheme.sectionSpacing),
          _MenuEntry(
            icon: Icons.person_outline,
            title: 'Minu profiil',
            subtitle: 'Andmed, valmisolek ja panus',
            onTap: () => _open(
              context,
              SelfProfileScreen(
                currentUid: currentUid,
                organizationId: organizationId,
                canManageRoles: isOrganizationAdmin,
              ),
            ),
          ),
            _MenuEntry(
              icon: Icons.group_outlined,
              title: 'Liikmed',
              subtitle: 'Liikmed ja rollid',
              onTap: () => _open(
                context,
                MembersScreen(
                  organizationId: organizationId,
                  currentUid: currentUid,
                  canManageRoles: isOrganizationAdmin,
                ),
              ),
            ),
          _MenuEntry(
            icon: Icons.inventory_2_outlined,
            title: canManageEquipment ? 'Varustus' : 'Minu varustus',
            subtitle: 'Varustuse seisund ja hooldus',
            onTap: () => _open(
              context,
              EquipmentScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                canManageEquipment: canManageEquipment,
              ),
            ),
          ),
          _MenuEntry(
            icon: Icons.assignment_outlined,
            title: 'Operatiivlogi',
            subtitle: 'Operatsioonide sündmused ja kokkuvõtted',
            onTap: () => _open(
              context,
              OperationLogScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                currentUserName: currentUserName,
                canViewCalloutResponseSummary: canStartOperationLog,
                canStartOperationLog: canStartOperationLog,
              ),
            ),
          ),
          _MenuEntry(
            icon: Icons.event_outlined,
            title: 'Tegevused ja koolitused',
            subtitle: 'Kohtumised, koolitused ja õppused',
            onTap: () => _open(
              context,
              ActivitiesScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                canManageActivities: canCreateActivities,
              ),
            ),
          ),
          if (canViewStatistics)
            _MenuEntry(
              icon: Icons.insights_outlined,
              title: 'Statistika',
              subtitle: 'Ühingu ülevaated',
              onTap: () => _open(
                context,
                StatisticsScreen(
                  organizationId: organizationId,
                  currentUid: currentUid,
                  canViewStatistics: true,
                  canViewOrganizationCertificates: isOrganizationAdmin,
                ),
              ),
            ),
          if (onSwitchOrganization != null)
            _MenuEntry(
              icon: Icons.swap_horiz_outlined,
              title: 'Vaheta ühingut',
              subtitle: 'Lülitu teise ühingu vaatele',
              onTap: onSwitchOrganization,
            ),
          if (isOrganizationAdmin)
            _MenuEntry(
              icon: Icons.settings_outlined,
              title: 'Ühingu seaded',
              subtitle: 'Õigused ja ühingu valikud',
              onTap: onOpenOrganizationSettings,
            ),
          if (isPlatformAdmin)
            _MenuEntry(
              icon: Icons.apartment_outlined,
              title: 'RespondCrew haldus',
              leading: const PlatformPendingBadge(),
              subtitle: 'Ühingud, kasutajakontod ja audit',
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(builder: (_) => const PlatformManagementScreen())),
            ),

        ],
      ),
    );
  }
}

class _MenuEntry extends StatelessWidget {
  const _MenuEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.leading,
    required this.onTap,
  });

  final IconData icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.itemSpacing),
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: AppSectionCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    leading ?? Icon(icon, color: AppColors.navy, size: 26),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      onTap == null
                          ? Icons.lock_outline
                          : Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
