import '../widgets/app_layout.dart';
import 'package:flutter/material.dart';

import '../widgets/upcoming_activities.dart';
import '../widgets/active_callouts_card.dart';
import '../widgets/vessel_status_card.dart';
import '../widgets/crew_readiness_card.dart';
import '../widgets/dashboard_quick_actions.dart';

class MemberHomeDashboard extends StatefulWidget {
  const MemberHomeDashboard({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.topHeader,
    required this.onOpenCallouts,
    required this.onOpenReadiness,
    required this.onOpenCallout,
    required this.onOpenMembers,
    required this.onOpenNotifications,
    required this.onOpenActivities,
    required this.onOpenEquipment,
    this.onCreateCallout,
    this.onCreateActivity,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final Widget topHeader;
  final VoidCallback onOpenCallouts;
  final VoidCallback onOpenReadiness;
  final ValueChanged<String> onOpenCallout;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenActivities;
  final VoidCallback onOpenEquipment;
  final VoidCallback? onCreateCallout;
  final VoidCallback? onCreateActivity;

  @override
  State<MemberHomeDashboard> createState() => _MemberHomeDashboardState();
}

class _MemberHomeDashboardState extends State<MemberHomeDashboard> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveSections(
      header: [
        ActiveCalloutsCard(
          key: ValueKey(widget.organizationId),
          organizationId: widget.organizationId,
          userId: widget.currentUid,
          userName: widget.currentUserName,
          onOpen: widget.onOpenCallout,
        ),
      ],
      primary: [
        widget.topHeader,
        const SizedBox(height: 16),
        CrewReadinessCard(
          memberPreviewLimit: 4,
          onOpenDetails: widget.onOpenReadiness,
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
        ),
        const SizedBox(height: 16),
      ],
      secondary: [
        DashboardQuickActions(
          onCreateCallout: widget.onCreateCallout,
          onCreateActivity: widget.onCreateActivity,
        ),
        SectionHeading(
          title: 'Lähiaja tegevused ja koolitused',
          onOpen: widget.onOpenActivities,
        ),
        const SizedBox(height: 8),
        UpcomingActivities(
          key: ValueKey(widget.organizationId),
          organizationId: widget.organizationId,
          userId: widget.currentUid,
        ),
        const SizedBox(height: 16),
        SectionHeading(
          title: 'Alused ja varustus',
          onOpen: widget.onOpenEquipment,
        ),
        VesselStatusCard(organizationId: widget.organizationId),
        const SizedBox(height: 16),
      ],
    );
  }
}
