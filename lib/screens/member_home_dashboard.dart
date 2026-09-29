import 'package:flutter/material.dart';

import '../widgets/upcoming_activities.dart';
import '../models/callout_model.dart';
import '../widgets/vessel_status_card.dart';
import '../widgets/crew_readiness_card.dart';
import '../services/callout_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/status_badge.dart';

class MemberHomeDashboard extends StatefulWidget {
  const MemberHomeDashboard({
    super.key,
    required this.organizationId,
    required this.currentUid,
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
  final _calloutService = CalloutService();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        widget.topHeader,
        const SizedBox(height: 16),
        if (widget.onCreateCallout != null || widget.onCreateActivity != null)
          AppSectionCard(title: 'Kiirtegevused', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.onCreateCallout != null) FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.activeCallout, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
              onPressed: widget.onCreateCallout, icon: const Icon(Icons.campaign), label: const Text('Loo väljakutse')),
            if (widget.onCreateActivity != null) OutlinedButton.icon(onPressed: widget.onCreateActivity, icon: const Icon(Icons.event_available), label: const Text('Lisa tegevus / koolitus')),
          ])),
        CrewReadinessCard(organizationId: widget.organizationId, currentUid: widget.currentUid),
        const SizedBox(height: 16),

        _buildLatestCallout(),
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

  Widget _buildLatestCallout() {
    return StreamBuilder<List<CalloutModel>>(
      stream: _calloutService.streamActiveCallouts(
        organizationId: widget.organizationId,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatusBadge(
                      label: _calloutPriorityLabel(callout.priority),
                      type: callout.priority == CalloutPriority.critical
                          ? StatusBadgeType.critical
                          : StatusBadgeType.activeCallout,
                    ),
                  ),
                  if (callout.createdAt != null)
                    Text(
                      _relativeTime(callout.createdAt!),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
            '${CalloutType.label(callout.calloutType)} · ${callout.title}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (callout.location.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(callout.location)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _buildMyCalloutResponseStatus(callout.id),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,

                child: ElevatedButton.icon(
                  onPressed: () => widget.onOpenCallout(callout.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeCallout,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.controlRadius),
                    ),
                  ),
                  icon: const Icon(Icons.campaign),
                  label: const Text('Ava väljakutse'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyCalloutResponseStatus(String calloutId) {
    return StreamBuilder<CalloutResponseModel?>(
      stream: _calloutService.streamMyResponse(
        calloutId: calloutId,
        userId: widget.currentUid,
        organizationId: widget.organizationId,
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

  String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Praegu';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min tagasi';
    if (difference.inHours < 24) return '${difference.inHours} h tagasi';
    return '${difference.inDays} p tagasi';
  }

  String _calloutPriorityLabel(String priority) {
    switch (priority) {
      case CalloutPriority.critical:
        return 'KRIITILINE';
      case CalloutPriority.high:
        return 'KÕRGE PRIORITEET';
      case CalloutPriority.low:
        return 'MADAL PRIORITEET';
      default:
        return 'AKTIIVNE';
    }
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

class _PreviewLoadingCard extends StatelessWidget {
  const _PreviewLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
