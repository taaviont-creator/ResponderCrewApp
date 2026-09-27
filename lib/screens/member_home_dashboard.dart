import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../models/callout_model.dart';
import '../widgets/vessel_status_card.dart';
import '../widgets/crew_readiness_card.dart';
import '../services/activity_service.dart';
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
  });

  final String organizationId;
  final String currentUid;
  final Widget topHeader;
  final VoidCallback onOpenCallouts;
  final ValueChanged<String> onOpenCallout;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenActivities;

  @override
  State<MemberHomeDashboard> createState() => _MemberHomeDashboardState();
}

class _MemberHomeDashboardState extends State<MemberHomeDashboard> {
  final _activityService = ActivityService();
  final _calloutService = CalloutService();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        widget.topHeader,
        const SizedBox(height: 16),
        CrewReadinessCard(organizationId: widget.organizationId, currentUid: widget.currentUid),
        const SizedBox(height: 16),

        _buildLatestCallout(),
        const SizedBox(height: 16),
        VesselStatusCard(organizationId: widget.organizationId),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Tulev tegevus/koolitus', onOpen: widget.onOpenActivities),
        const SizedBox(height: 8),
        _buildUpcomingActivity(),
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

  Widget _buildUpcomingActivity() {
    return StreamBuilder<List<ActivityModel>>(
      stream: _activityService.streamOrganizationActivities(
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _PreviewLoadingCard();
        }

        final activity = _nextActivity(
          snapshot.data ?? const <ActivityModel>[],
        );
        if (activity == null) {
          return const _EmptyPreviewCard(
            icon: Icons.event_outlined,
            message: 'Tulevasi tegevusi ega koolitusi ei ole.',
          );
        }

        return AppSectionCard(
          child: InkWell(
            onTap: widget.onOpenActivities,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.deepSeaBlue,
                    borderRadius:
                        BorderRadius.circular(AppTheme.controlRadius),
                  ),
                  child: Icon(
                    activity.type == ActivityType.training
                        ? Icons.school_outlined
                        : Icons.event_outlined,
                    color: AppColors.background,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (activity.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          activity.location,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                      if (activity.startTime.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activity.startTime,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  ActivityModel? _nextActivity(List<ActivityModel> activities) {
    final now = DateTime.now();
    final upcoming = activities.where((activity) {
      final startTime = DateTime.tryParse(activity.startTime);
      return startTime != null && !startTime.isBefore(now);
    }).toList()
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a.startTime)!;
        final bTime = DateTime.tryParse(b.startTime)!;
        return aTime.compareTo(bTime);
      });

    return upcoming.isEmpty ? null : upcoming.first;
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
