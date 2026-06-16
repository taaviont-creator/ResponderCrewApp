import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/status_badge.dart';
import 'activities_screen.dart';
import 'availability_screen.dart';
import 'callouts_screen.dart';
import 'certificates_screen.dart';
import 'equipment_screen.dart';

enum _NotificationFilter {
  all,
  unread,
  callouts,
  equipment,
  readiness,
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canManageNotifications,
    required this.canCreateActivities,
    required this.canStartOperationLog,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final bool canManageNotifications;
  final bool canCreateActivities;
  final bool canStartOperationLog;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  var _selectedFilter = _NotificationFilter.all;

  Future<void> _showAddNotificationDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    var selectedType = NotificationType.system;
    var selectedPriority = NotificationPriority.normal;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Lisa teavitus'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Pealkiri',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Sõnum',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tüüp',
                    ),
                    items: NotificationType.values.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(_notificationTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Prioriteet',
                    ),
                    items: NotificationPriority.values.map((priority) {
                      return DropdownMenuItem<String>(
                        value: priority,
                        child: Text(_notificationPriorityLabel(priority)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedPriority = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Katkesta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lisa'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true) return;

    try {
      await _notificationService.addNotification(
        organizationId: widget.organizationId,
        title: titleController.text,
        message: messageController.text,
        type: selectedType,
        priority: selectedPriority,
        createdBy: widget.currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teavitus lisatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teavituse lisamine ebaõnnestus: $e')),
      );
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    try {
      await _notificationService.markAsRead(
        notificationId: notification.id,
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teavitus märgitud loetuks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loetuks märkimine ebaõnnestus: $e')),
      );
    }
  }

  Future<void> _markAllAsRead({
    required List<NotificationModel> notifications,
    required Set<String> readNotificationIds,
  }) async {
    try {
      await _notificationService.markAllAsRead(
        notifications: notifications,
        readNotificationIds: readNotificationIds,
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kõik teavitused märgitud loetuks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kõigi loetuks märkimine ebaõnnestus: $e')),
      );
    }
  }

  Future<void> _openNotification({
    required NotificationModel notification,
    required bool isRead,
  }) async {
    final notificationOrganizationId = notification.organizationId.isNotEmpty
        ? notification.organizationId
        : notification.commandId;
    if (notificationOrganizationId != widget.organizationId) {
      _showNoNotificationViewMessage();
      return;
    }

    if (!isRead) {
      try {
        await _notificationService.markAsRead(
          notificationId: notification.id,
          userId: widget.currentUid,
          organizationId: widget.organizationId,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loetuks märkimine ebaõnnestus: $e')),
        );
        return;
      }
    }

    if (!mounted) return;

    const supportedRelatedTypes = {
      'callout',
      'equipment',
      'activity',
      'availability',
      'organizationReadiness',
      'certificate',
    };
    final targetType =
        supportedRelatedTypes.contains(notification.relatedType)
            ? notification.relatedType!
            : notification.type;
    Widget? targetScreen;

    switch (targetType) {
      case 'callout':
        targetScreen = CalloutsScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          currentUserName: widget.currentUserName,
          canManageCallouts: widget.canManageNotifications,
          canCloseCallouts: widget.canManageNotifications,
          canStartOperationLog: widget.canStartOperationLog,
        );
        break;
      case 'equipment':
        targetScreen = EquipmentScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          canManageEquipment: widget.canManageNotifications,
        );
        break;
      case 'activity':
        targetScreen = ActivitiesScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          canManageActivities: widget.canCreateActivities,
        );
        break;
      case 'availability':
      case 'organizationReadiness':
      case NotificationType.minimumCrew:
      case NotificationType.readiness:
        targetScreen = AvailabilityScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          currentUserName: widget.currentUserName,
          canViewOrganizationReadiness: widget.canManageNotifications,
        );
        break;
      case NotificationType.certificate:
        targetScreen = CertificatesScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          canManageCertificates: widget.canManageNotifications,
        );
        break;
    }

    if (targetScreen == null) {
      _showNoNotificationViewMessage();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetScreen!),
    );
  }

  void _showNoNotificationViewMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selle teavituse jaoks puudub eraldi vaade.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teavitused'),
      ),
      floatingActionButton: widget.canManageNotifications
          ? FloatingActionButton(
              onPressed: _showAddNotificationDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.streamOrganizationNotifications(
          organizationId: widget.organizationId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Teavituste laadimine ebaõnnestus: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data ?? const <NotificationModel>[];
          if (notifications.isEmpty) {
            return _buildEmptyState('Teavitusi ei ole lisatud');
          }

          return StreamBuilder<Set<String>>(
            stream: _notificationService.streamMyReadNotificationIds(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
            ),
            builder: (context, readsSnapshot) {
              if (readsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (readsSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Lugemisoleku laadimine ebaõnnestus: '
                    '${readsSnapshot.error}',
                  ),
                );
              }

              final readNotificationIds =
                  readsSnapshot.data ?? const <String>{};
              final unreadCount = notifications
                  .where(
                    (notification) =>
                        !readNotificationIds.contains(notification.id),
                  )
                  .length;
              final filteredNotifications = notifications.where((notification) {
                switch (_selectedFilter) {
                  case _NotificationFilter.unread:
                    return !readNotificationIds.contains(notification.id);
                  case _NotificationFilter.callouts:
                    return notification.type == NotificationType.callout ||
                        notification.relatedType == NotificationType.callout;
                  case _NotificationFilter.equipment:
                    return notification.type == NotificationType.equipment ||
                        notification.relatedType == NotificationType.equipment;
                  case _NotificationFilter.readiness:
                    return notification.type == NotificationType.availability ||
                        notification.type == NotificationType.minimumCrew ||
                        notification.type == NotificationType.readiness ||
                        notification.relatedType == 'availability' ||
                        notification.relatedType == 'organizationReadiness';
                  case _NotificationFilter.all:
                    return true;
                }
              }).toList(growable: false);

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  AppTheme.screenPadding,
                  AppTheme.screenPadding,
                  96,
                ),
                children: [
                  _buildNotificationSummary(
                    totalCount: notifications.length,
                    unreadCount: unreadCount,
                  ),
                  const SizedBox(height: AppTheme.itemSpacing),
                  _buildFilterChips(unreadCount: unreadCount),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _markAllAsRead(
                          notifications: notifications,
                          readNotificationIds: readNotificationIds,
                        ),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Märgi kõik loetuks'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.itemSpacing),
                  if (filteredNotifications.isEmpty)
                    _buildEmptyCard('Selle filtriga teavitusi ei ole')
                  else
                    ...filteredNotifications.map((notification) {
                      final isRead =
                          readNotificationIds.contains(notification.id);
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.itemSpacing,
                        ),
                        child: _buildNotificationCard(
                          notification: notification,
                          isRead: isRead,
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationSummary({
    required int totalCount,
    required int unreadCount,
  }) {
    return AppSectionCard(
      accentColor: unreadCount > 0 ? AppColors.deepSeaBlue : AppColors.ready,
      leading: const Icon(Icons.notifications_outlined),
      title: 'Teavitused',
      subtitle: unreadCount > 0
          ? '$unreadCount lugemata teavitust'
          : 'Kõik teavitused on loetud',
      trailing: StatusBadge(
        label: '$totalCount kokku',
        type: StatusBadgeType.neutral,
      ),
      child: Text(
        'Olulised väljakutsed, valmisoleku muutused ja varustuse teated ühes vaates.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }

  Widget _buildFilterChips({required int unreadCount}) {
    final filters = [
      (_NotificationFilter.unread, 'Lugemata', unreadCount),
      (_NotificationFilter.all, 'Kõik', null),
      (_NotificationFilter.callouts, 'Väljakutsed', null),
      (_NotificationFilter.equipment, 'Varustus', null),
      (_NotificationFilter.readiness, 'Valmisolek', null),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final value = filter.$1;
          final label = filter.$3 == null
              ? filter.$2
              : '${filter.$2} ${filter.$3}';
          final selected = _selectedFilter == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFilter = value),
              selectedColor: AppColors.navy,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: AppColors.surfaceBlueStrong,
              side: BorderSide(
                color: selected ? AppColors.navy : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard({
    required NotificationModel notification,
    required bool isRead,
  }) {
    final isUrgent = notification.priority == NotificationPriority.high ||
        notification.priority == NotificationPriority.critical ||
        notification.type == NotificationType.callout;
    final organizationId = notification.organizationId.isNotEmpty
        ? notification.organizationId
        : notification.commandId;

    return Semantics(
      button: true,
      label: 'Ava teavitus ${notification.title}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () => _openNotification(
          notification: notification,
          isRead: isRead,
        ),
        child: AppSectionCard(
          accentColor: _notificationAccentColor(notification, isRead),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationIcon(notification),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title.isEmpty
                                ? _notificationCategoryLabel(notification)
                                : notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: isRead
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.activeCallout,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (notification.createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _shortDateTime(notification.createdAt!),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(
                          label: _notificationCategoryLabel(notification),
                          type: _notificationBadgeType(notification),
                          icon: _notificationTypeIcon(notification.type),
                        ),
                        StatusBadge(
                          label: _notificationPriorityLabel(
                            notification.priority,
                          ),
                          type: _notificationPriorityBadgeType(
                            notification.priority,
                          ),
                        ),
                        StatusBadge(
                          label: isRead ? 'Loetud' : 'Lugemata',
                          type: isRead
                              ? StatusBadgeType.neutral
                              : StatusBadgeType.activeCallout,
                          icon: isRead
                              ? Icons.mark_email_read_outlined
                              : Icons.mark_email_unread_outlined,
                        ),
                        if (organizationId.isNotEmpty)
                          StatusBadge(
                            label: 'Org $organizationId',
                            type: StatusBadgeType.neutral,
                            icon: Icons.apartment_outlined,
                          ),
                      ],
                    ),
                    if (!isRead) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _markAsRead(notification),
                          icon: const Icon(Icons.done),
                          label: const Text('Märgi loetuks'),
                        ),
                      ),
                    ],
                    if (isUrgent && !isRead) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Oluline teavitus',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.activeCallout,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationModel notification) {
    final color = _notificationAccentColor(notification, false);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _notificationTypeIcon(notification.type),
        color: color,
        size: 26,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: _buildEmptyCard(message),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return AppSectionCard(
      leading: const Icon(Icons.notifications_none),
      title: 'Teavitused',
      child: Text(message),
    );
  }

  Color _notificationAccentColor(
    NotificationModel notification,
    bool isRead,
  ) {
    if (isRead) return AppColors.border;
    if (notification.priority == NotificationPriority.critical) {
      return AppColors.critical;
    }
    if (notification.type == NotificationType.callout ||
        notification.priority == NotificationPriority.high) {
      return AppColors.activeCallout;
    }
    if (notification.type == NotificationType.equipment) {
      return AppColors.equipmentWarning;
    }
    if (notification.type == NotificationType.availability ||
        notification.type == NotificationType.minimumCrew ||
        notification.type == NotificationType.readiness) {
      return AppColors.ready;
    }
    return AppColors.deepSeaBlue;
  }

  StatusBadgeType _notificationBadgeType(NotificationModel notification) {
    switch (notification.type) {
      case NotificationType.callout:
        return StatusBadgeType.activeCallout;
      case NotificationType.equipment:
        return StatusBadgeType.equipmentWarning;
      case NotificationType.availability:
      case NotificationType.minimumCrew:
      case NotificationType.readiness:
        return StatusBadgeType.ready;
      case NotificationType.certificate:
        return StatusBadgeType.delayed;
      default:
        return StatusBadgeType.neutral;
    }
  }

  StatusBadgeType _notificationPriorityBadgeType(String priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return StatusBadgeType.critical;
      case NotificationPriority.high:
        return StatusBadgeType.activeCallout;
      case NotificationPriority.low:
        return StatusBadgeType.neutral;
      default:
        return StatusBadgeType.ready;
    }
  }

  IconData _notificationTypeIcon(String type) {
    switch (type) {
      case NotificationType.callout:
        return Icons.campaign_outlined;
      case NotificationType.equipment:
        return Icons.construction_outlined;
      case NotificationType.availability:
      case NotificationType.readiness:
        return Icons.verified_user_outlined;
      case NotificationType.minimumCrew:
        return Icons.groups_outlined;
      case NotificationType.activity:
        return Icons.event_outlined;
      case NotificationType.certificate:
        return Icons.card_membership_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _notificationCategoryLabel(NotificationModel notification) {
    if (notification.type == NotificationType.activity) {
      final text = '${notification.title} ${notification.message}'
          .toLowerCase();
      if (text.contains('koolitus') || text.contains('treening')) {
        return 'Koolitus';
      }
    }
    return _notificationTypeLabel(notification.type);
  }

  String _notificationTypeLabel(String type) {
    switch (type) {
      case NotificationType.system:
        return 'Süsteem';
      case NotificationType.info:
        return 'Info';
      case NotificationType.warning:
        return 'Hoiatus';
      case NotificationType.equipment:
        return 'Varustus';
      case NotificationType.availability:
        return 'Valmisolek';
      case NotificationType.minimumCrew:
        return 'Miinimumkoosseis';
      case NotificationType.readiness:
        return 'Valmisolek';
      case NotificationType.activity:
        return 'Tegevus';
      case NotificationType.operation:
        return 'Operatsioon';
      case NotificationType.callout:
        return 'Väljakutse';
      case NotificationType.certificate:
        return 'Sertifikaat';
      case NotificationType.other:
        return 'Muu';
      default:
        return 'Süsteem';
    }
  }

  String _notificationPriorityLabel(String priority) {
    switch (priority) {
      case NotificationPriority.low:
        return 'Madal';
      case NotificationPriority.high:
        return 'Kõrge';
      case NotificationPriority.critical:
        return 'Kriitiline';
      default:
        return 'Tavaline';
    }
  }

  String _shortDateTime(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final time = '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';

    if (date == today) return time;
    if (date == today.subtract(const Duration(days: 1))) return 'Eile';
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}';
  }
}
