import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../services/activity_service.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageActivities,
    this.openCreateOnLoad = false,
  });

  final String organizationId;
  final String currentUid;
  final bool canManageActivities;
  final bool openCreateOnLoad;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final _activityService = ActivityService();
  final _memberNameFutures = <String, Future<String>>{};

  @override
  void initState() {
    super.initState();
    if (widget.canManageActivities && widget.openCreateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddActivityDialog();
      });
    }
  }

  Future<void> _showAddActivityDialog() async {
    final organizationId = widget.organizationId.trim();
    if (organizationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tegevust ei saa lisada ilma aktiivse ühinguta.'),
        ),
      );
      return;
    }

    if (!widget.canManageActivities) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sul puudub õigus tegevust lisada.')),
      );
      return;
    }

    final titleController = TextEditingController();
    final startTimeController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedType = ActivityType.training;
    String? titleError;
    String? startTimeError;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Lisa tegevus'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    onChanged: (value) {
                      if (titleError != null && value.trim().isNotEmpty) {
                        setDialogState(() => titleError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Pealkiri',
                      errorText: titleError,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Tüüp'),
                    items: ActivityType.values.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(_activityTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startTimeController,
                    onChanged: (value) {
                      if (startTimeError != null && value.trim().isNotEmpty) {
                        setDialogState(() => startTimeError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Algusaeg',
                      hintText: 'nt 2026-05-20 18:00',
                      errorText: startTimeError,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Asukoht'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Kirjeldus'),
                    maxLines: 3,
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
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    setDialogState(() {
                      titleError = 'Pealkiri on kohustuslik.';
                    });
                    return;
                  }
                  if (startTimeController.text.trim().isEmpty) {
                    setDialogState(() {
                      startTimeError = 'Kuupäev on kohustuslik.';
                    });
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Lisa'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true) return;

    try {
      await _activityService.addActivity(
        organizationId: organizationId,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        type: selectedType,
        startTime: startTimeController.text.trim(),
        location: locationController.text.trim(),
        createdBy: widget.currentUid.trim(),
      );

      if (!mounted) return;
      final successMessage = selectedType == ActivityType.training
          ? 'Koolitus salvestatud.'
          : 'Tegevus salvestatud.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tegevuse lisamine ebaonnestus: $e')),
      );
    }
  }

  Future<String> _memberDisplayName(String userId) {
    return _memberNameFutures.putIfAbsent(
      userId,
      () => _activityService.loadParticipantDisplayName(userId),
    );
  }

  Widget _buildActivityParticipationControls({
    required ActivityModel activity,
  }) {
    return StreamBuilder<ActivityParticipantModel?>(
      stream: _activityService.streamMyParticipation(
        activityId: activity.id,
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final status = snapshot.data?.status;
        final selectedStatus = _normalizedOwnParticipationStatus(status);
        final statusText = _ownParticipationStatusLabel(selectedStatus);

        Future<void> updateParticipation(String newStatus) async {
          try {
            await _activityService.setMyParticipation(
              activityId: activity.id,
              userId: widget.currentUid,
              organizationId: widget.organizationId,
              status: newStatus,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Osalemine salvestatud.')),
            );
          } catch (_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Osalemist ei saanud salvestada.'),
              ),
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minu osalemine',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(statusText),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Osalen'),
                    selected: selectedStatus ==
                        ActivityParticipationStatus.registered,
                    onSelected: (_) => updateParticipation(
                      ActivityParticipationStatus.registered,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Ei saa osaleda'),
                    selected: selectedStatus ==
                        ActivityParticipationStatus.cannotAttend,
                    onSelected: (_) => updateParticipation(
                      ActivityParticipationStatus.cannotAttend,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmActivityParticipation({
    required ActivityParticipantModel participant,
    required String attendanceStatus,
    double? hours,
  }) async {
    try {
      await _activityService.confirmParticipation(
        activityId: participant.activityId,
        userId: participant.userId,
        organizationId: widget.organizationId,
        attendanceStatus: attendanceStatus,
        confirmedBy: widget.currentUid,
        hours: hours,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Osalemine kinnitatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Osalemist ei saanud kinnitada.')),
      );
    }
  }

  Future<_HoursInputResult?> _showHoursInputDialog(double? initialHours) async {
    final hoursController = TextEditingController(
      text: initialHours == null ? '' : initialHours.toString(),
    );
    String? hoursError;

    final result = await showDialog<_HoursInputResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Tunnid'),
            content: TextField(
              controller: hoursController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Tunnid',
                errorText: hoursError,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Katkesta'),
              ),
              ElevatedButton(
                onPressed: () {
                  final rawValue = hoursController.text.trim();
                  final normalizedValue = rawValue.replaceAll(',', '.');
                  final hours = rawValue.isEmpty
                      ? null
                      : double.tryParse(normalizedValue);
                  if (rawValue.isNotEmpty && (hours == null || hours < 0)) {
                    setDialogState(() {
                      hoursError = 'Sisesta korrektne tundide arv.';
                    });
                    return;
                  }

                  Navigator.pop(context, _HoursInputResult(hours));
                },
                child: const Text('Kinnita'),
              ),
            ],
          );
        },
      ),
    );

    hoursController.dispose();
    return result;
  }

  Widget _buildActivityConfirmationControls({
    required ActivityModel activity,
    required bool canConfirmParticipation,
  }) {
    if (!canConfirmParticipation) return const SizedBox.shrink();

    return StreamBuilder<List<ActivityParticipantModel>>(
      stream: _activityService.streamActivityParticipants(
        activityId: activity.id,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final participants =
            snapshot.data ?? const <ActivityParticipantModel>[];

        if (snapshot.connectionState == ConnectionState.waiting &&
            participants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: LinearProgressIndicator(),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Osalemise kinnitamine',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (participants.isEmpty)
                const Text('Osalemisi ei ole veel märgitud.')
              else
                ...participants.map(_buildParticipantConfirmationRow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticipantConfirmationRow(
    ActivityParticipantModel participant,
  ) {
    return FutureBuilder<String>(
      future: _memberDisplayName(participant.userId),
      builder: (context, snapshot) {
        final displayName = snapshot.data ?? 'Liige';
        final attendanceLabel =
            _attendanceConfirmationLabel(participant.attendanceStatus);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Liikme valik: '
                '${_participationChoiceLabel(participant.status)}',
              ),
              if (attendanceLabel != null) ...[
                const SizedBox(height: 2),
                Text(attendanceLabel),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final hoursResult = await _showHoursInputDialog(
                        participant.hours,
                      );
                      if (hoursResult == null) return;
                      await _confirmActivityParticipation(
                        participant: participant,
                        attendanceStatus: ActivityAttendanceStatus.confirmed,
                        hours: hoursResult.hours,
                      );
                    },
                    child: const Text('Kinnita osales'),
                  ),
                  OutlinedButton(
                    onPressed: () => _confirmActivityParticipation(
                      participant: participant,
                      attendanceStatus: ActivityAttendanceStatus.absent,
                    ),
                    child: const Text('Märgi puudus'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tegevused ja koolitused'),
      ),
      floatingActionButton: widget.canManageActivities
          ? FloatingActionButton(
              onPressed: _showAddActivityDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<bool>(
        stream: _activityService.streamCanConfirmParticipation(
          organizationId: widget.organizationId,
          userId: widget.currentUid,
        ),
        builder: (context, confirmationSnapshot) {
          final canConfirmParticipation = confirmationSnapshot.data ?? false;

          return StreamBuilder<List<ActivityModel>>(
            stream: _activityService.streamOrganizationActivities(
              organizationId: widget.organizationId,
            ),
            builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Tegevuste laadimine ebaõnnestus.'),
            );
          }

          final activities = snapshot.data ?? const <ActivityModel>[];
          final upcomingActivities = activities
              .where((activity) {
                final startDate = _activityStartDate(activity);
                return startDate == null ||
                    !startDate.isBefore(DateTime.now());
              })
              .toList(growable: false)
            ..sort(_compareUpcomingActivities);
          final pastActivities = activities
              .where((activity) {
                final startDate = _activityStartDate(activity);
                return startDate != null && startDate.isBefore(DateTime.now());
              })
              .toList(growable: false)
            ..sort(_comparePastActivities);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildActivitySection(
                title: 'Tulemas',
                activities: upcomingActivities,
                canConfirmParticipation: canConfirmParticipation,
                emptyText: 'Tulevasi tegevusi või koolitusi ei ole.',
              ),
              const SizedBox(height: 24),
              _buildActivitySection(
                title: 'Toimunud',
                activities: pastActivities,
                canConfirmParticipation: canConfirmParticipation,
                emptyText: 'Toimunud tegevusi või koolitusi ei ole.',
              ),
            ],
          );
            },
          );
        },
      ),
    );
  }

  Widget _buildActivitySection({
    required String title,
    required List<ActivityModel> activities,
    required String emptyText,
    required bool canConfirmParticipation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyText),
          )
        else
          ...activities.map(
            (activity) => _buildActivityListItem(
              activity,
              canConfirmParticipation: canConfirmParticipation,
            ),
          ),
      ],
    );
  }

  Widget _buildActivityListItem(
    ActivityModel activity, {
    required bool canConfirmParticipation,
  }) {
    final kindLabel = _activityKindLabel(activity.type);
    final typeLabel = _activityTypeLabel(activity.type);
    final subtitleParts = [
      kindLabel,
      if (typeLabel != kindLabel) typeLabel,
      if (activity.startTime.isNotEmpty) activity.startTime,
      if (activity.location.isNotEmpty) activity.location,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(activity.title),
          subtitle: Text(
            activity.description.isEmpty
                ? subtitleParts.join(' - ')
                : '${subtitleParts.join(' - ')}\n'
                    '${activity.description}',
          ),
        ),
        _buildActivityParticipationControls(activity: activity),
        _buildActivityConfirmationControls(
          activity: activity,
          canConfirmParticipation: canConfirmParticipation,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  int _compareUpcomingActivities(ActivityModel a, ActivityModel b) {
    final aTime = _activityStartDate(a);
    final bTime = _activityStartDate(b);
    if (aTime == null && bTime == null) return a.title.compareTo(b.title);
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return aTime.compareTo(bTime);
  }

  int _comparePastActivities(ActivityModel a, ActivityModel b) {
    final aTime = _activityStartDate(a);
    final bTime = _activityStartDate(b);
    if (aTime == null && bTime == null) return a.title.compareTo(b.title);
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  }

  DateTime? _activityStartDate(ActivityModel activity) {
    final value = activity.startTime.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value) ??
        DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  String _activityKindLabel(String type) {
    return type == ActivityType.training ? 'Koolitus' : 'Tegevus';
  }

  String? _normalizedOwnParticipationStatus(String? status) {
    switch (status) {
      case ActivityParticipationStatus.registered:
      case ActivityParticipationStatus.attending:
        return ActivityParticipationStatus.registered;
      case ActivityParticipationStatus.cannotAttend:
      case ActivityParticipationStatus.notAttending:
        return ActivityParticipationStatus.cannotAttend;
      default:
        return null;
    }
  }

  String _ownParticipationStatusLabel(String? status) {
    switch (status) {
      case ActivityParticipationStatus.registered:
        return 'Sinu valik: Osalen';
      case ActivityParticipationStatus.cannotAttend:
        return 'Sinu valik: Ei saa osaleda';
      default:
        return 'Osalemine m\u00e4rkimata';
    }
  }

  String _participationChoiceLabel(String status) {
    switch (status) {
      case ActivityParticipationStatus.registered:
      case ActivityParticipationStatus.attending:
        return 'Osalen';
      case ActivityParticipationStatus.cannotAttend:
      case ActivityParticipationStatus.notAttending:
        return 'Ei saa osaleda';
      default:
        return 'Osalemine m\u00e4rkimata';
    }
  }

  String? _attendanceConfirmationLabel(String status) {
    switch (status) {
      case ActivityAttendanceStatus.confirmed:
        return 'Kinnitatud: osales';
      case ActivityAttendanceStatus.absent:
        return 'Kinnitatud: puudus';
      default:
        return null;
    }
  }

  String _activityTypeLabel(String type) {
    switch (type) {
      case ActivityType.training:
        return 'Koolitus';
      case ActivityType.meeting:
        return 'Koosolek';
      case ActivityType.maintenance:
        return 'Hooldus';
      case ActivityType.exercise:
        return 'Harjutus';
      case ActivityType.event:
        return 'Sündmus';
      default:
        return 'Muu';
    }
  }
}

class _HoursInputResult {
  const _HoursInputResult(this.hours);

  final double? hours;
}
