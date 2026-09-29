import 'package:flutter/material.dart';

import '../widgets/upcoming_activities.dart';
import '../widgets/active_callouts_card.dart';
import '../widgets/vessel_status_card.dart';
import '../widgets/crew_readiness_card.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';

class MemberHomeDashboard extends StatefulWidget {
  const MemberHomeDashboard({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.topHeader,
    required this.onOpenCallouts,
    required this.onOpenCallout,
    required this.onOpenMembers,
    required this.onOpenNotifications,
    required this.onOpenActivities,
    this.onCreateCallout,
    this.onCreateActivity,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final Widget topHeader;
  final VoidCallback onOpenCallouts;
  final ValueChanged<String> onOpenCallout;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenActivities;
  final VoidCallback? onCreateCallout;
  final VoidCallback? onCreateActivity;

  @override
  State<MemberHomeDashboard> createState() => _MemberHomeDashboardState();
}

class _MemberHomeDashboardState extends State<MemberHomeDashboard> {

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        ActiveCalloutsCard(key: ValueKey(widget.organizationId), organizationId: widget.organizationId, userId: widget.currentUid, userName: widget.currentUserName, onOpen: widget.onOpenCallout),
        widget.topHeader,
        const SizedBox(height: 16),
        if (widget.onCreateCallout != null || widget.onCreateActivity != null)
          AppSectionCard(title: 'Kiirtegevused', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.onCreateCallout != null) FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.activeCallout, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
              onPressed: widget.onCreateCallout, icon: const Icon(Icons.campaign), label: const Text('Loo väljakutse')),
            if (widget.onCreateActivity != null) OutlinedButton.icon(onPressed: widget.onCreateActivity, icon: const Icon(Icons.event_available), label: const Text('Lisa tegevus / koolitus')),
          ])),
        CrewReadinessCard(compact: true, organizationId: widget.organizationId, currentUid: widget.currentUid),
        const SizedBox(height: 16),

        VesselStatusCard(organizationId: widget.organizationId),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Lähiaja tegevused ja koolitused', onOpen: widget.onOpenActivities),
        const SizedBox(height: 8),
        UpcomingActivities(key: ValueKey(widget.organizationId), organizationId: widget.organizationId, userId: widget.currentUid),
        const SizedBox(height: 16),
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
