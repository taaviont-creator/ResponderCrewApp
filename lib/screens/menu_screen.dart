import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import 'activities_screen.dart';
import 'certificates_screen.dart';
import 'equipment_screen.dart';
import 'members_screen.dart';
import 'operation_log_screen.dart';
import 'platform_readiness_screen.dart';
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
  });

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

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOpenReadinessOverview =
        isPlatformAdmin || isOrganizationAdmin;
    final canManageEquipment = isPlatformAdmin || isOrganizationAdmin;

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
          const SizedBox(height: AppTheme.sectionSpacing),
          if (isOrganizationAdmin)
            _MenuEntry(
              icon: Icons.group_outlined,
              title: 'Liikmed',
              subtitle: 'Liikmed ja rollid',
              onTap: () => _open(
                context,
                MembersScreen(
                  organizationId: organizationId,
                  currentUid: currentUid,
                  canManageRoles: true,
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
            title: 'Operatsioonilogi',
            subtitle: 'Operatsioonide sündmused ja kokkuvõtted',
            onTap: () => _open(
              context,
              OperationLogScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                currentUserName: currentUserName,
                canViewCalloutResponseSummary: isOrganizationAdmin,
                canStartOperationLog: canStartOperationLog,
              ),
            ),
          ),
          _MenuEntry(
            icon: Icons.event_outlined,
            title: 'Tegevused',
            subtitle: 'Kohtumised, õppused ja sündmused',
            onTap: () => _open(
              context,
              ActivitiesScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                canManageActivities: canCreateActivities,
              ),
            ),
          ),
          _MenuEntry(
            icon: Icons.school_outlined,
            title: 'Koolitused',
            subtitle: 'Koolitused ja õppused',
            onTap: () => _open(
              context,
              ActivitiesScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                canManageActivities: canCreateActivities,
              ),
            ),
          ),
          _MenuEntry(
            icon: Icons.card_membership_outlined,
            title:
                isOrganizationAdmin ? 'Sertifikaadid' : 'Minu sertifikaadid',
            subtitle: 'Pädevused ja kehtivusajad',
            onTap: () => _open(
              context,
              CertificatesScreen(
                organizationId: organizationId,
                currentUid: currentUid,
                canManageCertificates: isOrganizationAdmin,
              ),
            ),
          ),
          if (canViewStatistics)
            _MenuEntry(
              icon: Icons.insights_outlined,
              title: 'Statistika',
              subtitle: 'Organisatsiooni ülevaated',
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
          if (isPlatformAdmin || isOrganizationAdmin)
            _MenuEntry(
              icon: Icons.settings_outlined,
              title: 'Organisatsiooni seaded',
              subtitle: 'Õigused ja organisatsiooni valikud',
              onTap: onOpenOrganizationSettings,
            ),
          _MenuEntry(
            icon: Icons.health_and_safety_outlined,
            title: 'Juhtimiskeskuse koondvaade',
            subtitle: canOpenReadinessOverview
                ? 'Organisatsioonide valmisoleku ülevaade'
                : 'Saadaval administraatorile',
            onTap: canOpenReadinessOverview
                ? () => _open(
                      context,
                      PlatformReadinessScreen(
                        currentUid: currentUid,
                        activeOrganizationId: organizationId,
                        activeOrganizationName: organizationName,
                        canManageOwnSummary: isOrganizationAdmin,
                        isPlatformAdmin: isPlatformAdmin,
                      ),
                    )
                : null,
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
    required this.onTap,
  });

  final IconData icon;
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
                    Icon(icon, color: AppColors.navy, size: 26),
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
