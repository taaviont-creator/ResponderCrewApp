import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../models/availability_model.dart';
import '../models/callout_model.dart';
import '../models/notification_model.dart';
import '../services/activity_service.dart';
import '../services/availability_service.dart';
import '../services/callout_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/status_badge.dart';

class MemberHomeDashboard extends StatefulWidget {
  const MemberHomeDashboard({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.currentUid,
    required this.currentUserName,
    required this.onOpenCallouts,
    required this.onOpenNotifications,
    required this.onOpenActivities,
  });

  final String organizationId;
  final String? organizationName;
  final String currentUid;
  final String currentUserName;
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
  final _notificationService = NotificationService();
  var _isUpdatingAvailability = false;

  Future<void> _updateAvailability(
    String status, {
    int? responseMinutes,
  }) async {
    if (_isUpdatingAvailability) return;

    setState(() => _isUpdatingAvailability = true);
    try {
      await _availabilityService.setMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
        memberName: widget.currentUserName,
        status: status,
        responseMinutes: responseMinutes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Valmiduse muutmine ebaõnnestus: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvailability = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        _buildOrganizationCard(),
        const SizedBox(height: AppTheme.sectionSpacing),
        Text(
          'Minu valmisolek',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildAvailabilityCard(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Viimane väljakutse',
          onOpen: widget.onOpenCallouts,
        ),
        const SizedBox(height: AppTheme.itemSpacing),
        _buildLatestCallout(),
        const SizedBox(height: AppTheme.sectionSpacing),
        _SectionTitle(
          title: 'Tulev tegevus',
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

  Widget _buildOrganizationCard() {
    final organizationName = widget.organizationName?.trim();

    return AppSectionCard(
      child: Row(
        children: [
          const Icon(
            Icons.anchor,
            color: AppColors.navy,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizationName == null || organizationName.isEmpty
                      ? 'Aktiivne organisatsioon'
                      : organizationName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Aktiivne organisatsioon',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const StatusBadge(
            label: 'LIIGE',
            type: StatusBadgeType.neutral,
            icon: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final availability = snapshot.data;
        final status = availability?.status ?? AvailabilityStatus.offDuty;
        final storedResponseMinutes = availability?.responseMinutes ?? 15;
        final responseMinutes = const {15, 30, 60}.contains(
          storedResponseMinutes,
        )
            ? storedResponseMinutes
            : 15;
        final updatedAt = availability?.updatedAt;

        return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _availabilityBadge(status)),
                  if (updatedAt != null)
                    Text(
                      'Uuendatud ${_formatClock(updatedAt)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _AvailabilityButton(
                label: 'VALVES',
                icon: Icons.check_circle_outline,
                isSelected: status == AvailabilityStatus.onDuty,
                backgroundColor: AppColors.ready,
                foregroundColor: Colors.white,
                onPressed: _isUpdatingAvailability
                    ? null
                    : () => _updateAvailability(AvailabilityStatus.onDuty),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _AvailabilityButton(
                label: 'EI OLE VALVES',
                icon: Icons.cancel_outlined,
                isSelected: status == AvailabilityStatus.offDuty,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.offDuty,
                borderColor: AppColors.offDuty,
                onPressed: _isUpdatingAvailability
                    ? null
                    : () => _updateAvailability(AvailabilityStatus.offDuty),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              Row(
                children: [
                  Expanded(
                    child: _AvailabilityButton(
                      label: 'HILINEN',
                      icon: Icons.schedule,
                      isSelected: status == AvailabilityStatus.delayed,
                      backgroundColor: AppColors.delayedSurface,
                      foregroundColor: AppColors.delayed,
                      borderColor: status == AvailabilityStatus.delayed
                          ? AppColors.delayed
                          : null,
                      onPressed: _isUpdatingAvailability
                          ? null
                          : () => _updateAvailability(
                                AvailabilityStatus.delayed,
                                responseMinutes: responseMinutes,
                              ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.itemSpacing),
                  Container(
                    height: AppTheme.primaryActionHeight,
                    constraints: const BoxConstraints(minWidth: 104),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppTheme.controlRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: responseMinutes,
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                        ],
                        onChanged: _isUpdatingAvailability
                            ? null
                            : (value) {
                                if (value == null) return;
                                _updateAvailability(
                                  AvailabilityStatus.delayed,
                                  responseMinutes: value,
                                );
                              },
                      ),
                    ),
                  ),
                ],
              ),
              if (_isUpdatingAvailability) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _availabilityBadge(String status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return const StatusBadge(
          label: 'VALVES',
          type: StatusBadgeType.ready,
        );
      case AvailabilityStatus.delayed:
        return const StatusBadge(
          label: 'HILINEN',
          type: StatusBadgeType.delayed,
        );
      default:
        return const StatusBadge(
          label: 'EI OLE VALVES',
          type: StatusBadgeType.offDuty,
        );
    }
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
              const SizedBox(height: 18),
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
                  label: const Text('AVA VÄLJAKUTSE'),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.streamOrganizationNotifications(
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _PreviewLoadingCard();
        }

        final notifications =
            (snapshot.data ?? const <NotificationModel>[]).take(2).toList();
        if (notifications.isEmpty) {
          return const _EmptyPreviewCard(
            icon: Icons.notifications_none,
            message: 'Uusi teavitusi ei ole.',
          );
        }

        return AppSectionCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (var index = 0; index < notifications.length; index++) ...[
                  _NotificationPreviewTile(
                    notification: notifications[index],
                    onTap: widget.onOpenNotifications,
                  ),
                  if (index < notifications.length - 1)
                    const Divider(height: 1),
                ],
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

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

class _AvailabilityButton extends StatelessWidget {
  const _AvailabilityButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.primaryActionHeight,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: isSelected ? 2 : 0,
          side: BorderSide(
            color: borderColor ??
                (isSelected ? foregroundColor : Colors.transparent),
            width: isSelected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _NotificationPreviewTile extends StatelessWidget {
  const _NotificationPreviewTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              notification.priority == NotificationPriority.critical ||
                      notification.priority == NotificationPriority.high
                  ? Icons.warning_amber_rounded
                  : Icons.circle,
              size: notification.priority == NotificationPriority.normal
                  ? 10
                  : 22,
              color: notification.priority == NotificationPriority.critical
                  ? AppColors.critical
                  : AppColors.navy,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (notification.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
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
