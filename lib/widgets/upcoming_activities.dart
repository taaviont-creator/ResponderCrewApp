import 'dart:async';
import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../models/activity_schedule.dart';
import '../services/activity_service.dart';

class UpcomingActivities extends StatefulWidget {
  const UpcomingActivities({
    super.key,
    required this.organizationId,
    required this.userId,
    this.service,
  });
  final String organizationId, userId;
  final ActivityService? service;
  @override
  State<UpcomingActivities> createState() => _UpcomingActivitiesState();
}

class _UpcomingActivitiesState extends State<UpcomingActivities> {
  late final _service = widget.service ?? ActivityService();
  late Stream<List<ActivityModel>> _activities;
  late Stream<List<ActivityParticipantModel>> _responses;
  Timer? _clock;
  void _bind() {
    _activities = _service.streamOrganizationActivities(
      organizationId: widget.organizationId,
    );
    _responses = _service.streamUserParticipations(
      organizationId: widget.organizationId,
      userId: widget.userId,
    );
  }

  @override
  void initState() {
    super.initState();
    _bind();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void didUpdateWidget(UpcomingActivities oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.userId != widget.userId) {
      _bind();
      _saving = null;
      _error = null;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String? _saving, _error;
  Future<void> _respond(String activity, bool attend) async {
    setState(() {
      _saving = activity;
      _error = null;
    });
    try {
      await _service.setMyParticipation(
        activityId: activity,
        userId: widget.userId,
        organizationId: widget.organizationId,
        status: attend
            ? ActivityParticipationStatus.attending
            : ActivityParticipationStatus.notAttending,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Vastuse salvestamine ebaõnnestus. Proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ActivityModel>>(
    key: ValueKey('${widget.organizationId}-${widget.userId}'),
    stream: _activities,
    builder: (context, activities) {
      if (activities.hasError) {
        return const Text('Lähiaja tegevusi ei õnnestunud laadida.');
      }
      if (!activities.hasData) return const LinearProgressIndicator();
      final now = DateTime.now();
      final upcoming =
          activities.data!.where((a) => a.isUpcomingOrOngoing(now)).toList()
            ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
      if (upcoming.isEmpty) {
        return const Text('Lähiajal tegevusi ega koolitusi ei ole.');
      }
      return StreamBuilder<List<ActivityParticipantModel>>(
        stream: _responses,
        builder: (context, responses) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) Text(_error!),
            if (responses.hasError)
              const Text('Sinu vastuseid ei õnnestunud laadida.'),
            for (final activity in upcoming.take(3))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(ActivitySchedule.format(activity.startsAt)),
                      if (activity.location.isNotEmpty) Text(activity.location),
                      if (responses.hasData)
                        Text(switch (responses.data!
                            .where((p) => p.activityId == activity.id)
                            .firstOrNull
                            ?.status) {
                          ActivityParticipationStatus.attending ||
                          ActivityParticipationStatus.registered =>
                            'Sinu vastus: osalen',
                          ActivityParticipationStatus.notAttending ||
                          ActivityParticipationStatus.cannotAttend =>
                            'Sinu vastus: ei osale',
                          _ => 'Palun märgi, kas plaanid osaleda.',
                        }),
                      Wrap(
                        spacing: 12,
                        children: [
                          for (final attend in [true, false])
                            OutlinedButton.icon(
                              onPressed:
                                  _saving != null ||
                                      !responses.hasData ||
                                      responses.hasError
                                  ? null
                                  : () => _respond(activity.id, attend),
                              icon: Icon(attend ? Icons.check : Icons.close),
                              label: Text(attend ? 'Osalen' : 'Ei osale'),
                            ),
                        ],
                      ),
                      if (_saving == activity.id)
                        const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
