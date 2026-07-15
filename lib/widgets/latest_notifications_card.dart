import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'app_section_card.dart';

class LatestNotificationsCard extends StatelessWidget {
  const LatestNotificationsCard({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.onTap,
    this.usePriorityIcons = false,
  });

  final String organizationId;
  final String currentUid;
  final VoidCallback onTap;
  final bool usePriorityIcons;

  static final _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.streamOrganizationNotifications(
        organizationId: organizationId,
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

        return StreamBuilder<Set<String>>(
          stream: _notificationService.streamMyReadNotificationIds(
            userId: currentUid,
            organizationId: organizationId,
          ),
          builder: (context, readSnapshot) {
            final readNotificationIds =
                readSnapshot.data ?? const <String>{};
            final hasReadState = readSnapshot.hasData;

            return AppSectionCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (var index = 0;
                        index < notifications.length;
                        index++) ...[
                      _NotificationTile(
                        notification: notifications[index],
                        onTap: onTap,
                        usePriorityIcon: usePriorityIcons,
                        isRead: hasReadState &&
                            readNotificationIds.contains(
                              notifications[index].id,
                            ),
                        showReadState: hasReadState,
                      ),
                      if (index < notifications.length - 1)
                        const Divider(height: 1),
                    ],
                    const Divider(height: 1),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Kõik teavitused'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.usePriorityIcon,
    required this.isRead,
    required this.showReadState,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final bool usePriorityIcon;
  final bool isRead;
  final bool showReadState;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget;
    final double spacing;
    final unread = showReadState && !isRead;
    final titleColor = isRead ? AppColors.textSecondary : AppColors.textPrimary;
    final bodyColor = isRead ? AppColors.textSecondary : null;
    final titleWeight = unread ? FontWeight.w700 : FontWeight.w500;

    if (usePriorityIcon) {
      iconWidget = Icon(
        notification.priority == NotificationPriority.critical ||
                notification.priority == NotificationPriority.high
            ? Icons.warning_amber_rounded
            : Icons.circle,
        size: notification.priority == NotificationPriority.normal ? 10 : 22,
        color: isRead
            ? AppColors.textSecondary
            : (notification.priority == NotificationPriority.critical
                ? AppColors.critical
                : AppColors.navy),
      );
      spacing = 14;
    } else {
      iconWidget = Icon(
        Icons.notifications_outlined,
        color: isRead ? AppColors.textSecondary : AppColors.navy,
      );
      spacing = 12;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            iconWidget,
            SizedBox(width: spacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: titleColor,
                                    fontWeight: titleWeight,
                                  ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        const _UnreadBadge(),
                      ],
                    ],
                  ),
                  if (notification.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: bodyColor,
                          ),
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.deepSeaBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Uus',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.deepSeaBlue,
              fontWeight: FontWeight.w700,
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
