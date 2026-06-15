import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/availability_model.dart';
import '../models/membership_model.dart';
import '../models/availability_reminder_settings_model.dart';
import '../models/platform_readiness_model.dart';
import '../services/availability_reminder_settings_service.dart';
import '../services/availability_service.dart';
import '../services/membership_service.dart';
import '../services/platform_readiness_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/status_badge.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canViewOrganizationReadiness,
    this.organizationName,
    this.membershipRole,
  });

  final String organizationId;
  final String? organizationName;
  final String? membershipRole;
  final String currentUid;
  final String currentUserName;
  final bool canViewOrganizationReadiness;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  final _availabilityService = AvailabilityService();
  final _availabilityReminderSettingsService =
      AvailabilityReminderSettingsService();
  final _membershipService = MembershipService();
  final _platformReadinessService = PlatformReadinessService();
  final _noteController = TextEditingController();
  var _noteInitialized = false;
  var _isUpdating = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateAvailability(
    String status, {
    int? responseMinutes,
    String? note,
  }) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      await _availabilityService.setMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
        memberName: widget.currentUserName,
        status: status,
        responseMinutes: responseMinutes,
        note: note?.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Valmiduse muutmine ebaõnnestus: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationName = widget.organizationName?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Valmisolek')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          AppSectionCard(
            child: Row(
              children: [
                const Icon(
                  Icons.anchor,
                  color: AppColors.navy,
                  size: 28,
                ),
                const SizedBox(width: 12),
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
                      Text(
                        _roleLabel(widget.membershipRole ?? ''),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: widget.canViewOrganizationReadiness
                      ? 'ADMIN'
                      : 'LIIGE',
                  type: StatusBadgeType.neutral,
                  icon: widget.canViewOrganizationReadiness
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          Text(
            'Minu valmisolek',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Määra oma operatiivne staatus.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildAvailabilityControl(),
          const SizedBox(height: AppTheme.sectionSpacing),
          Text(
            'Meeskonna ülevaade',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.itemSpacing),
          _buildAvailabilityOverview(),
          const SizedBox(height: AppTheme.sectionSpacing),
          _buildAvailabilityReminderSettings(),
          const SizedBox(height: AppTheme.sectionSpacing),
        ],
      ),
    );
  }

  Widget _buildAvailabilityControl() {
    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final availability = snapshot.data;
        final status = availability?.status ?? AvailabilityStatus.offDuty;
        final storedMinutes = availability?.responseMinutes ?? 15;
        final responseMinutes =
            const {15, 30, 60}.contains(storedMinutes) ? storedMinutes : 15;
        final note = availability?.note ?? '';

        if (!_noteInitialized && snapshot.hasData) {
          _noteInitialized = true;
          _noteController.text = note;
        }

        return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _statusBadge(status)),
                  if (availability?.updatedAt != null)
                    Text(
                      'Uuendatud ${_formatClock(availability!.updatedAt!)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _StatusActionButton(
                label: 'VALVES',
                icon: Icons.check_circle_outline,
                selected: status == AvailabilityStatus.onDuty,
                backgroundColor: AppColors.ready,
                foregroundColor: Colors.white,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailability(
                          AvailabilityStatus.onDuty,
                          note: _noteController.text,
                        ),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _StatusActionButton(
                label: 'HILINEN',
                icon: Icons.schedule,
                selected: status == AvailabilityStatus.delayed,
                backgroundColor: AppColors.delayedSurface,
                foregroundColor: AppColors.delayed,
                borderColor: status == AvailabilityStatus.delayed
                    ? AppColors.delayed
                    : AppColors.border,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailability(
                          AvailabilityStatus.delayed,
                          responseMinutes: responseMinutes,
                          note: _noteController.text,
                        ),
              ),
              const SizedBox(height: AppTheme.itemSpacing),
              _StatusActionButton(
                label: 'EI OLE VALVES',
                icon: Icons.cancel_outlined,
                selected: status == AvailabilityStatus.offDuty,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.offDuty,
                borderColor: AppColors.offDuty,
                onPressed: _isUpdating
                    ? null
                    : () => _updateAvailability(
                          AvailabilityStatus.offDuty,
                          note: _noteController.text,
                        ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reageerimise viide',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: responseMinutes,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('+ 15 min')),
                        DropdownMenuItem(value: 30, child: Text('+ 30 min')),
                        DropdownMenuItem(value: 60, child: Text('+ 60 min')),
                      ],
                      onChanged: _isUpdating
                          ? null
                          : (value) {
                              if (value == null) return;
                              _updateAvailability(
                                AvailabilityStatus.delayed,
                                responseMinutes: value,
                                note: _noteController.text,
                              );
                            },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Märkus (valikuline)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Nt: Olen teel sadamasse...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : () => _updateAvailability(
                                  status,
                                  responseMinutes:
                                      status == AvailabilityStatus.delayed
                                          ? responseMinutes
                                          : null,
                                  note: _noteController.text,
                                ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvesta märkus'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUpdating) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
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

  Widget _buildAvailabilityOverview() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _membershipService.streamActiveMembershipsForOrganization(
        widget.organizationId,
      ),
      builder: (context, membershipsSnapshot) {
        if (membershipsSnapshot.connectionState == ConnectionState.waiting &&
            !membershipsSnapshot.hasData) {
          return const _LoadingCard();
        }

        final memberships = membershipsSnapshot.data ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return StreamBuilder<List<AvailabilityModel>>(
          stream: _availabilityService.streamOrganizationAvailability(
            organizationId: widget.organizationId,
          ),
          builder: (context, availabilitySnapshot) {
            final availabilityByUserId = <String, AvailabilityModel>{
              for (final availability
                  in availabilitySnapshot.data ?? const <AvailabilityModel>[])
                if (availability.userId.isNotEmpty)
                  availability.userId: availability,
            };

            final onDuty = <_MemberAvailability>[];
            final delayed = <_MemberAvailability>[];
            final offDuty = <_MemberAvailability>[];

            for (final membershipDoc in memberships) {
              final membership = membershipDoc.data();
              final userId = (membership['userId'] ?? '').toString();
              final item = _MemberAvailability(
                userId: userId,
                role: _roleLabel((membership['role'] ?? '').toString()),
                availability: availabilityByUserId[userId],
              );
              switch (item.status) {
                case AvailabilityStatus.onDuty:
                  onDuty.add(item);
                  break;
                case AvailabilityStatus.delayed:
                  delayed.add(item);
                  break;
                default:
                  offDuty.add(item);
                  break;
              }
            }

            if (memberships.isEmpty) {
              return const _EmptyCard(
                icon: Icons.group_off_outlined,
                message: 'Organisatsioonis ei ole aktiivseid liikmeid.',
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CountCard(
                        label: 'Valves',
                        count: onDuty.length,
                        color: AppColors.ready,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: AppTheme.itemSpacing),
                    Expanded(
                      child: _CountCard(
                        label: 'Hilinen',
                        count: delayed.length,
                        color: AppColors.delayed,
                        icon: Icons.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _CountCard(
                  label: 'Ei ole valves',
                  count: offDuty.length,
                  color: AppColors.offDuty,
                  icon: Icons.cancel_outlined,
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _buildMinimumCrewCard(onDuty.length),
                const SizedBox(height: AppTheme.itemSpacing),
                _MemberGroupCard(
                  title: 'Valves',
                  type: StatusBadgeType.ready,
                  members: onDuty,
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _MemberGroupCard(
                  title: 'Hilinen',
                  type: StatusBadgeType.delayed,
                  members: delayed,
                ),
                const SizedBox(height: AppTheme.itemSpacing),
                _MemberGroupCard(
                  title: 'Ei ole valves',
                  type: StatusBadgeType.offDuty,
                  members: offDuty,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMinimumCrewCard(int onDutyCount) {
    return StreamBuilder<List<PlatformReadinessSummary>>(
      stream: _platformReadinessService.streamOrganizationSummary(
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final summaries =
            snapshot.data ?? const <PlatformReadinessSummary>[];
        if (summaries.isEmpty || summaries.first.minimumCrewRequired <= 0) {
          return const _EmptyCard(
            icon: Icons.info_outline,
            message: 'Miinimumkoosseisu ei ole seadistatud.',
          );
        }

        final requiredCount = summaries.first.minimumCrewRequired;
        final isMet = onDutyCount >= requiredCount;
        final missing = requiredCount - onDutyCount;

        return AppSectionCard(
          accentColor: isMet ? AppColors.ready : AppColors.critical,
          child: Row(
            children: [
              Icon(
                isMet
                    ? Icons.verified_outlined
                    : Icons.warning_amber_rounded,
                color: isMet ? AppColors.ready : AppColors.critical,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Miinimumkoosseis',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMet
                          ? 'Täidetud: $onDutyCount / $requiredCount'
                          : 'Ei ole täidetud. Puudu ${missing > 0 ? missing : 0} liiget.',
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: isMet ? 'TÄIDETUD' : 'HOIATUS',
                type: isMet
                    ? StatusBadgeType.ready
                    : StatusBadgeType.critical,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityReminderSettings() {
    return StreamBuilder<AvailabilityReminderSettingsModel>(
      stream: _availabilityReminderSettingsService.streamMySettings(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final settings = snapshot.data ??
            AvailabilityReminderSettingsModel.defaults(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
            );
        final timeOptions = _reminderTimeOptions(settings.reminderTime);

        Future<void> updateSettings({
          bool? enabled,
          int? intervalHours,
          String? reminderTime,
        }) async {
          try {
            await _availabilityReminderSettingsService.setMySettings(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
              enabled: enabled ?? settings.enabled,
              intervalHours: intervalHours ?? settings.intervalHours,
              reminderTime: reminderTime ?? settings.reminderTime,
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Meeldetuletuse muutmine ebaõnnestus: $e'),
              ),
            );
          }
        }

        return AppSectionCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Valmisoleku meeldetuletused'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Meeldetuletused on lubatud'),
                value: settings.enabled,
                onChanged: (value) => updateSettings(enabled: value),
              ),
              DropdownButtonFormField<int>(
                initialValue: settings.intervalHours,
                decoration: const InputDecoration(labelText: 'Intervall'),
                items: AvailabilityReminderSettingsModel.allowedIntervalHours
                    .map(
                      (hours) => DropdownMenuItem<int>(
                        value: hours,
                        child: Text(_reminderIntervalLabel(hours)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) updateSettings(intervalHours: value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: settings.reminderTime,
                decoration: const InputDecoration(labelText: 'Kellaaeg'),
                items: timeOptions
                    .map(
                      (time) => DropdownMenuItem<String>(
                        value: time,
                        child: Text(time),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) updateSettings(reminderTime: value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _roleLabel(String role) {
    return MembershipRole.isOrgAdmin(role)
        ? 'Organisatsiooni administraator'
        : 'Liige';
  }

  List<String> _reminderTimeOptions(String selectedTime) {
    final times = <String>{
      for (var hour = 0; hour < 24; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
      selectedTime,
    }.toList()
      ..sort();
    return times;
  }

  String _reminderIntervalLabel(int hours) {
    if (hours == 168) return '7 päeva';
    return '$hours tundi';
  }
}

class _MemberAvailability {
  const _MemberAvailability({
    required this.userId,
    required this.role,
    required this.availability,
  });

  final String userId;
  final String role;
  final AvailabilityModel? availability;

  String get status => availability?.status ?? AvailabilityStatus.offDuty;
}

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.primaryActionHeight,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: selected ? 2 : 0,
          side: BorderSide(
            color: borderColor ??
                (selected ? foregroundColor : Colors.transparent),
            width: selected ? 2 : 1,
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      accentColor: color,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _MemberGroupCard extends StatelessWidget {
  const _MemberGroupCard({
    required this.title,
    required this.type,
    required this.members,
  });

  final String title;
  final StatusBadgeType type;
  final List<_MemberAvailability> members;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '$title (${members.length})',
      leading: Icon(_iconFor(type)),
      accentColor: _colorFor(type),
      child: members.isEmpty
          ? Text(
              'Selles grupis liikmeid ei ole.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          : Column(
              children: [
                for (var index = 0; index < members.length; index++) ...[
                  _MemberTile(member: members[index]),
                  if (index < members.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
    );
  }

  IconData _iconFor(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.ready:
        return Icons.check_circle_outline;
      case StatusBadgeType.delayed:
        return Icons.schedule;
      default:
        return Icons.cancel_outlined;
    }
  }

  Color _colorFor(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.ready:
        return AppColors.ready;
      case StatusBadgeType.delayed:
        return AppColors.delayed;
      default:
        return AppColors.offDuty;
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final _MemberAvailability member;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(member.userId)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['name'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final displayName =
            name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Liige');
        final initials = _initials(displayName);
        final minutes = member.availability?.responseMinutes;
        final note = member.availability?.note?.trim();
        final details = <String>[
          member.role,
          if (member.status == AvailabilityStatus.delayed && minutes != null)
            '+ $minutes min',
          if (note != null && note.isNotEmpty) note,
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceBlueStrong,
                foregroundColor: AppColors.navy,
                child: Text(initials),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      details.join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
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
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
