import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'app_section_card.dart';

class LatestNotificationsCard extends StatelessWidget {
  const LatestNotificationsCard({
    super.key,
    required this.organizationId,
    required this.onTap,
    this.usePriorityIcons = false,
  });

  final String organizationId;
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

        return AppSectionCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (var index = 0; index < notifications.length; index++) ...[
                  _NotificationTile(
                    notification: notifications[index],
                    onTap: onTap,
                    usePriorityIcon: usePriorityIcons,
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
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.usePriorityIcon,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final bool usePriorityIcon;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget;
    final double spacing;

    if (usePriorityIcon) {
      iconWidget = Icon(
        notification.priority == NotificationPriority.critical ||
                notification.priority == NotificationPriority.high
            ? Icons.warning_amber_rounded
            : Icons.circle,
        size: notification.priority == NotificationPriority.normal ? 10 : 22,
        color: notification.priority == NotificationPriority.critical
            ? AppColors.critical
            : AppColors.navy,
      );
      spacing = 14;
    } else {
      iconWidget = const Icon(
        Icons.notifications_outlined,
        color: AppColors.navy,
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
