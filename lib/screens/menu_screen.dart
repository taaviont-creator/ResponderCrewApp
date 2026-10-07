import '../widgets/app_layout.dart';
import '../widgets/platform_pending_badge.dart';
import 'notification_settings_screen.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/pending_invites_section.dart';
import 'activities_screen.dart';
import 'equipment_screen.dart';
import 'members_screen.dart';
import 'operation_log_screen.dart';
import 'platform_management_screen.dart';
import 'self_profile_screen.dart';
import 'statistics_screen.dart';
import 'contribution_form_screen.dart';

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
    this.pendingInvites = const PendingInvitesSection(),
    this.platformBadge = const PlatformPendingBadge(),
  });

  final Widget pendingInvites, platformBadge;
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final canManageEquipment = isOrganizationAdmin;

    return AppScaffold(
      appBar: AppBar(title: const Text('Menüü')),
      body: ResponsiveSections(
        header: [
          Text(
            organizationName?.trim().isNotEmpty == true
                ? organizationName!
                : 'RespondCrew',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            isOrganizationAdmin ? 'Administraator' : 'Liige',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          pendingInvites,
        ],
        primary: [
          const _MenuHeading('Ühingu töö'),
          _MenuEntry(
            icon: Icons.volunteer_activism_outlined,
            title: 'Panus',
            subtitle: isOrganizationAdmin
                ? 'Tehtud töö ja kinnitamine'
                : 'Minu tehtud töö',
            trailing: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Lisa panus'),
              onPressed: () => _open(
                context,
                ContributionFormScreen(
                  organizationId: organizationId,
                  currentUid: currentUid,
                  canManage: isOrganizationAdmin,
                ),
              ),
            ),
            onTap: () => _open(
              context,
              ActivitiesScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                canManageActivities: isOrganizationAdmin,
                contributionsOnly: true,
              ),
            ),
          ),
          _MenuEntry(
            icon: Icons.group_outlined,
            title: 'Liikmed',
            subtitle: isOrganizationAdmin
                ? 'Profiilid, rollid ja tunnistused'
                : 'Meeskond ja kontaktid',
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
            title: 'Varustus',
            subtitle: isOrganizationAdmin
                ? 'Ühingu varustus ja ladu'
                : 'Minu ja ühingu varustus',
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
            subtitle: canStartOperationLog
                ? 'Sündmuste logid ja aruandlus'
                : 'Sündmuste käik ja kokkuvõtted',
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
            subtitle: canCreateActivities
                ? 'Planeeri ja märgi osalemine'
                : 'Kalender ja minu osalemine',
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
              subtitle: isOrganizationAdmin
                  ? 'Valveaeg ja osalemine'
                  : 'Minu valveaeg ja panus',
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
        ],
        secondary: [
          if (isOrganizationAdmin || isPlatformAdmin)
            const _MenuHeading('Haldus'),
          if (isOrganizationAdmin)
            _MenuEntry(
              icon: Icons.settings_outlined,
              title: 'Ühingu seaded',
              subtitle: 'Andmed, valmidus ja õigused',
              onTap: onOpenOrganizationSettings,
            ),
          if (isPlatformAdmin)
            _MenuEntry(
              icon: Icons.apartment_outlined,
              title: 'RespondCrew haldus',
              leading: platformBadge,
              subtitle: 'Ühingud, kasutajakontod ja audit',
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PlatformManagementScreen(),
                ),
              ),
            ),
          const _MenuHeading('Minu konto'),
          _MenuEntry(
            icon: Icons.person_outline,
            title: 'Minu profiil',
            subtitle: 'Minu andmed, tunnistused ja koolitused',
            onTap: () => _open(
              context,
              SelfProfileScreen(
                currentUid: currentUid,
                organizationId: organizationId,
                canManageRoles: isOrganizationAdmin,
              ),
            ),
          ),
          if (onOpenNotifications != null)
            _MenuEntry(
              icon: Icons.notifications_outlined,
              title: 'Teavitused',
              subtitle: 'Ühingu teated',
              onTap: onOpenNotifications!,
            ),
          _MenuEntry(
            icon: Icons.notifications_active_outlined,
            title: 'Teavituste seaded',
            subtitle: 'Sinu valikud ja SAR-häire heli',
            onTap: () => _open(
              context,
              NotificationSettingsScreen(
                organizationId: organizationId,
                userId: currentUid,
                isAdmin: isOrganizationAdmin,
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
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Widget? leading;
  final Widget? trailing;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading ?? Icon(icon, color: AppColors.navy),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: trailing ?? const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _MenuHeading extends StatelessWidget {
  const _MenuHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}
