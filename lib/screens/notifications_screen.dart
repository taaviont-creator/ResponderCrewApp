import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'activities_screen.dart';
import 'availability_screen.dart';
import 'callouts_screen.dart';
import 'certificates_screen.dart';
import 'equipment_screen.dart';

enum _NotificationFilter {
  all,
  unread,
  highPriority,
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canManageNotifications,
    required this.canCreateActivities,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final bool canManageNotifications;
  final bool canCreateActivities;

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
                      labelText: 'Sonum',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tuup',
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
        SnackBar(content: Text('Teavituse lisamine ebaonnestus: $e')),
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
        const SnackBar(content: Text('Teavitus margitud loetuks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loetuks markimine ebaonnestus: $e')),
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
              child: Text('Teavituste laadimine ebaonnestus: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data ?? const <NotificationModel>[];
          if (notifications.isEmpty) {
            return const Center(child: Text('Teavitusi ei ole lisatud'));
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
                  case _NotificationFilter.highPriority:
                    return notification.priority ==
                            NotificationPriority.high ||
                        notification.priority ==
                            NotificationPriority.critical;
                  case _NotificationFilter.all:
                    return true;
                }
              }).toList(growable: false);

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredNotifications.length +
                    (unreadCount > 0 ? 2 : 1) +
                    (filteredNotifications.isEmpty ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Kõik'),
                          selected:
                              _selectedFilter == _NotificationFilter.all,
                          onSelected: (_) => setState(
                            () => _selectedFilter = _NotificationFilter.all,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Lugemata'),
                          selected:
                              _selectedFilter == _NotificationFilter.unread,
                          onSelected: (_) => setState(
                            () => _selectedFilter = _NotificationFilter.unread,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Kõrge tähtsusega'),
                          selected: _selectedFilter ==
                              _NotificationFilter.highPriority,
                          onSelected: (_) => setState(
                            () => _selectedFilter =
                                _NotificationFilter.highPriority,
                          ),
                        ),
                      ],
                    );
                  }

                  if (unreadCount > 0 && index == 1) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _markAllAsRead(
                          notifications: notifications,
                          readNotificationIds: readNotificationIds,
                        ),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Märgi kõik loetuks'),
                      ),
                    );
                  }

                  if (filteredNotifications.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Selle filtriga teavitusi ei ole'),
                      ),
                    );
                  }

                  final notificationIndex =
                      index - (unreadCount > 0 ? 2 : 1);
                  final notification =
                      filteredNotifications[notificationIndex];
                  final isRead =
                      readNotificationIds.contains(notification.id);
                  final isHighPriority =
                      notification.priority == NotificationPriority.high ||
                          notification.priority ==
                              NotificationPriority.critical;
                  final subtitleParts = [
                    isRead ? 'Loetud' : 'Lugemata',
                    _notificationTypeLabel(notification.type),
                    _notificationPriorityLabel(notification.priority),
                    if (notification.createdAt != null)
                      _shortDateTime(notification.createdAt!),
                  ];

                  return ListTile(
                    onTap: () => _openNotification(
                      notification: notification,
                      isRead: isRead,
                    ),
                    tileColor: isRead
                        ? null
                        : Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.35),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(
                      isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: isHighPriority
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${subtitleParts.join(' - ')}\n${notification.message}',
                    ),
                    trailing: isRead
                        ? const Text('Loetud')
                        : TextButton(
                            onPressed: () => _markAsRead(notification),
                            child: const Text('Märgi loetuks'),
                          ),
                  );
                },
              );
            },
          );
        },
      ),
    );
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
        return 'Valvesolek';
      case NotificationType.minimumCrew:
        return 'Miinimummeeskond';
      case NotificationType.readiness:
        return 'Valmisolek';
      case NotificationType.activity:
        return 'Tegevus';
      case NotificationType.operation:
        return 'Operatsioon';
      case NotificationType.callout:
        return 'Valjakutse';
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
    final date = '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final time = '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
