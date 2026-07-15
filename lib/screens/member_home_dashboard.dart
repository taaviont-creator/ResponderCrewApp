import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../models/availability_model.dart';
import '../models/callout_model.dart';
import '../models/membership_model.dart';
import '../models/platform_readiness_model.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/activity_service.dart';
import '../services/availability_service.dart';
import '../services/callout_service.dart';
import '../services/membership_service.dart';
import '../services/platform_readiness_service.dart';
import '../services/planned_unavailability_service.dart';
import '../widgets/latest_notifications_card.dart';
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
    required this.onOpenNotifications,
    required this.onOpenActivities,
  });

  final String organizationId;
  final String currentUid;
  final Widget topHeader;
  final VoidCallback onOpenCallouts;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenActivities;

  @override
  State<MemberHomeDashboard> createState() => _MemberHomeDashboardState();
}

class _MemberHomeDashboardState extends State<MemberHomeDashboard> {
  final _activityService = ActivityService();
  final _availabilityService = AvailabilityService();
  final _calloutService = CalloutService();
  final _membershipService = MembershipService();
  final _plannedUnavailabilityService = PlannedUnavailabilityService();
  final _readinessService = PlatformReadinessService();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        widget.topHeader,
        const SizedBox(height: AppTheme.sectionSpacing),
        _buildMinimumCrewCompact(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Aktiivne väljakutse',
          onOpen: widget.onOpenCallouts,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildLatestCallout(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Tulev tegevus/koolitus',
          onOpen: widget.onOpenActivities,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildUpcomingActivity(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Viimased teavitused',
          onOpen: widget.onOpenNotifications,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildLatestNotifications(),
        const SizedBox(height: AppTheme.sectionSpacing),
      ],
    );
  }

  Widget _buildMinimumCrewCompact() {
    return StreamBuilder<List<PlatformReadinessSummary>>(
      stream: _readinessService.streamOrganizationSummary(
        organizationId: widget.organizationId,
      ),
      builder: (context, readinessSnapshot) {
        final summaries =
            readinessSnapshot.data ?? const <PlatformReadinessSummary>[];
        final summary = summaries.isEmpty ? null : summaries.first;
        final minimumCrewRequired = summary?.minimumCrewRequired ?? 0;

        return StreamBuilder<
            List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _membershipService.streamActiveMembershipsForOrganization(
            widget.organizationId,
          ),
          builder: (context, membershipsSnapshot) {
            final memberships = membershipsSnapshot.data ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            return StreamBuilder<List<AvailabilityModel>>(
              stream: _availabilityService.streamOrganizationAvailability(
                organizationId: widget.organizationId,
              ),
              builder: (context, availabilitySnapshot) {
                final availabilityByUserId = <String, AvailabilityModel>{
                  for (final availability in availabilitySnapshot.data ??
                      const <AvailabilityModel>[])
                    if (availability.userId.isNotEmpty)
                      availability.userId: availability,
                };

                return StreamBuilder<List<PlannedUnavailabilityModel>>(
                  stream:
                      _plannedUnavailabilityService.streamOrganizationPeriods(
                    organizationId: widget.organizationId,
                  ),
                  builder: (context, periodsSnapshot) {
                    return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
                      stream:
                          _plannedUnavailabilityService.streamOrganizationRules(
                        organizationId: widget.organizationId,
                      ),
                      builder: (context, rulesSnapshot) {
                        final now = DateTime.now();
                        final periods = periodsSnapshot.data ??
                            const <PlannedUnavailabilityModel>[];
                        final rules = rulesSnapshot.data ??
                            const <PlannedUnavailabilityRuleModel>[];
                        var effectiveOnDutyCount = 0;
                        var effectiveOnDutySecondLevelCount = 0;

                        for (final membershipDoc in memberships) {
                          final membership = membershipDoc.data();
                          final userId =
                              (membership['userId'] ?? '').toString();
                          final manualStatus =
                              availabilityByUserId[userId]?.status ??
                                  AvailabilityStatus.offDuty;
                          final effectiveStatus = _effectiveAvailabilityStatus(
                            userId: userId,
                            manualStatus: manualStatus,
                            periods: periods,
                            rules: rules,
                            now: now,
                          );

                          if (effectiveStatus == AvailabilityStatus.onDuty) {
                            effectiveOnDutyCount++;
                            if (SeaRescueLevel.isLevel2(
                              membership['seaRescueLevel'],
                            )) {
                              effectiveOnDutySecondLevelCount++;
                            }
                          }
                        }

                        final minimumCrewMet = minimumCrewRequired > 0 &&
                            effectiveOnDutyCount >= minimumCrewRequired;

                        return _MinimumCrewCompact(
                          minimumCrewRequired: minimumCrewRequired,
                          onDutyCount: effectiveOnDutyCount,
                          minimumCrewMet: minimumCrewMet,
                          secondLevelOnDutyCount:
                              effectiveOnDutySecondLevelCount,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _effectiveAvailabilityStatus({
    required String userId,
    required String manualStatus,
    required Iterable<PlannedUnavailabilityModel> periods,
    required Iterable<PlannedUnavailabilityRuleModel> rules,
    required DateTime now,
  }) {
    if (_hasActivePlannedUnavailabilityForUser(
          userId: userId,
          periods: periods,
          now: now,
        ) ||
        _hasActivePlannedUnavailabilityRuleForUser(
          userId: userId,
          rules: rules,
          now: now,
        )) {
      return AvailabilityStatus.offDuty;
    }

    return manualStatus;
  }

  bool _hasActivePlannedUnavailabilityForUser({
    required String userId,
    required Iterable<PlannedUnavailabilityModel> periods,
    required DateTime now,
  }) {
    return periods.any((period) {
      final startAt = period.startAt;
      final endAt = period.endAt;
      if (period.userId != userId ||
          !period.isActive ||
          startAt == null ||
          endAt == null) {
        return false;
      }
      return !now.isBefore(startAt) && now.isBefore(endAt);
    });
  }

  bool _hasActivePlannedUnavailabilityRuleForUser({
    required String userId,
    required Iterable<PlannedUnavailabilityRuleModel> rules,
    required DateTime now,
  }) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return rules.any((rule) {
      return rule.userId == userId &&
          rule.isActive &&
          rule.daysOfWeek.contains(now.weekday) &&
          minuteOfDay >= rule.startMinute &&
          minuteOfDay < rule.endMinute;
    });
  }

  bool _hasActivePlannedUnavailability(
    Iterable<PlannedUnavailabilityModel> periods,
    DateTime now,
  ) {
    return periods.any((period) {
      final startAt = period.startAt;
      final endAt = period.endAt;
      if (!period.isActive || startAt == null || endAt == null) {
        return false;
      }
      return !now.isBefore(startAt) && now.isBefore(endAt);
    });
  }

  bool _hasActivePlannedUnavailabilityRule(
    Iterable<PlannedUnavailabilityRuleModel> rules,
    DateTime now,
  ) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return rules.any((rule) {
      return rule.isActive &&
          rule.daysOfWeek.contains(now.weekday) &&
          minuteOfDay >= rule.startMinute &&
          minuteOfDay < rule.endMinute;
    });
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

        final callouts = snapshot.data ?? const <CalloutModel>[];
        if (callouts.isEmpty) {
          return const _EmptyPreviewCard(
            icon: Icons.campaign_outlined,
            message: 'Aktiivseid väljakutseid ei ole.',
          );
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
                callout.title,
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
                height: AppTheme.primaryActionHeight,
                child: ElevatedButton.icon(
                  onPressed: widget.onOpenCallouts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeCallout,
                    foregroundColor: Colors.white,
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
      CalloutResponseValue.delayed => 'Sinu vastus: Hilinen',
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
                    color: Colors.white,
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

  Widget _buildLatestNotifications() {
    return LatestNotificationsCard(
      organizationId: widget.organizationId,
      currentUid: widget.currentUid,
      onTap: widget.onOpenNotifications,
      usePriorityIcons: true,
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

class _MinimumCrewCompact extends StatelessWidget {
  const _MinimumCrewCompact({
    required this.minimumCrewRequired,
    required this.onDutyCount,
    required this.minimumCrewMet,
    required this.secondLevelOnDutyCount,
  });

  final int minimumCrewRequired;
  final int onDutyCount;
  final bool minimumCrewMet;
  final int secondLevelOnDutyCount;

  @override
  Widget build(BuildContext context) {
    final secondLevelMet = secondLevelOnDutyCount >= 1;
    final responseReady = minimumCrewMet && secondLevelMet;
    final color = minimumCrewRequired <= 0
        ? AppColors.textSecondary
        : responseReady
            ? AppColors.ready
            : AppColors.critical;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_2_outlined, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Miinimumkoosseis',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                      ),
                ),
              ),
              _MinimumCrewValue(
                label: 'Miinimum',
                value: minimumCrewRequired,
              ),
              const SizedBox(width: 12),
              _MinimumCrewValue(
                label: 'Valves',
                value: onDutyCount,
              ),
              const SizedBox(width: 12),
              _MinimumCrewValue(
                label: 'II aste valves:',
                value: secondLevelOnDutyCount,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            responseReady
                ? 'Ühing on reageerimisvalmis'
                : 'Ühing ei ole reageerimisvalmis',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (!secondLevelMet) ...[
            const SizedBox(height: 4),
            Text(
              'II astme merepäästja puudub',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.critical,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MinimumCrewValue extends StatelessWidget {
  const _MinimumCrewValue({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
