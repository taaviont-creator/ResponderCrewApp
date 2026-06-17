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
                    decoration: const InputDecoration(
                      labelText: 'Algusaeg',
                      hintText: 'nt 2026-05-20 18:00',
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
                      titleError = 'Tegevuse pealkiri on kohustuslik.';
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
        title: titleController.text,
        description: descriptionController.text,
        type: selectedType,
        startTime: startTimeController.text,
        location: locationController.text,
        createdBy: widget.currentUid.trim(),
      );

      if (!mounted) return;
      final successMessage = selectedType == ActivityType.training
          ? 'Koolitus lisatud.'
          : 'Tegevus lisatud.';
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

        Future<void> updateParticipation(String newStatus) async {
          try {
            await _activityService.setMyParticipation(
              activityId: activity.id,
              userId: widget.currentUid,
              organizationId: widget.organizationId,
              status: newStatus,
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Osalemise muutmine ebaonnestus: $e')),
            );
          }
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Osalen'),
              selected: status == ActivityParticipationStatus.attending,
              onSelected: (_) => updateParticipation(
                ActivityParticipationStatus.attending,
              ),
            ),
            ChoiceChip(
              label: const Text('Võib-olla'),
              selected: status == ActivityParticipationStatus.maybe,
              onSelected: (_) => updateParticipation(
                ActivityParticipationStatus.maybe,
              ),
            ),
            ChoiceChip(
              label: const Text('Ei osale'),
              selected: status == ActivityParticipationStatus.notAttending,
              onSelected: (_) => updateParticipation(
                ActivityParticipationStatus.notAttending,
              ),
            ),
          ],
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
      body: StreamBuilder<List<ActivityModel>>(
        stream: _activityService.streamOrganizationActivities(
          organizationId: widget.organizationId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Tegevuste laadimine ebaonnestus: ${snapshot.error}',
              ),
            );
          }

          final activities = snapshot.data ?? const <ActivityModel>[];
          if (activities.isEmpty) {
            return const Center(child: Text('Tegevusi ei ole veel lisatud'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = activities[index];
              final subtitleParts = [
                _activityTypeLabel(activity.type),
                if (activity.startTime.isNotEmpty) activity.startTime,
                if (activity.location.isNotEmpty) activity.location,
              ];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              );
            },
          );
        },
      ),
    );
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
