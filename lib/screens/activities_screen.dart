import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../models/activity_schedule.dart';
import '../services/activity_service.dart';
import '../widgets/app_layout.dart';
import '../widgets/activity_calendar.dart';
import '../widgets/activity_editor.dart';
import '../widgets/activity_attendance_row.dart';
import 'contribution_form_screen.dart';
import '../models/statistics_model.dart';
import '../widgets/app_date_field.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageActivities,
    this.openCreateOnLoad = false,
    this.service,
    this.contributionsOnly = false,
  });
  final String organizationId, currentUid;
  final bool canManageActivities, openCreateOnLoad;
  final ActivityService? service;
  final bool contributionsOnly;
  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late final _service = widget.service ?? ActivityService();
  late Stream<List<ActivityModel>> _activities;
  late Stream<bool> _canConfirm;
  late Stream<List<ActivityMember>> _members;
  late Stream<List<ActivityParticipantModel>> _myResponses;
  bool _calendar = true, _showPast = false;
  bool _pendingOnly = false;
  DateTime _selected = ActivitySchedule.inEstonia(DateTime.now());
  String? _savingResponse;
  void _bind() {
    _activities = _service.streamOrganizationActivities(
      organizationId: widget.organizationId,
    );
    _canConfirm = _service.streamCanConfirmParticipation(
      organizationId: widget.organizationId,
      userId: widget.currentUid,
    );
    _members = _service.streamActiveMembers(widget.organizationId);
    _myResponses = widget.contributionsOnly && widget.canManageActivities
        ? _service.streamOrganizationParticipations(widget.organizationId)
        : _service.streamUserParticipations(
            organizationId: widget.organizationId,
            userId: widget.currentUid,
          );
  }

  Future<void> _addContribution() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionFormScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          canManage: widget.canManageActivities,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bind();
    if (widget.openCreateOnLoad && widget.canManageActivities) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _edit();
      });
    }
  }

  @override
  void didUpdateWidget(ActivitiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.currentUid != widget.currentUid) {
      _bind();
      _savingResponse = null;
    }
  }

  Future<void> _edit([ActivityModel? activity]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActivityEditor(
        service: _service,
        organizationId: widget.organizationId,
        userId: widget.currentUid,
        activity: activity,
        initialDay: _calendar ? _selected : null,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tegevus salvestatud.')));
    }
  }

  Future<void> _respond(ActivityModel activity, bool attending) async {
    setState(() => _savingResponse = activity.id);
    try {
      await _service.setMyParticipation(
        activityId: activity.id,
        userId: widget.currentUid,
        organizationId: widget.organizationId,
        status: attending
            ? ActivityParticipationStatus.attending
            : ActivityParticipationStatus.notAttending,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vastust ei saanud salvestada. Proovi uuesti.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingResponse = null);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    contentMaxWidth: 850,
    appBar: AppBar(
      title: Text(
        widget.contributionsOnly ? 'Panus' : 'Tegevused ja koolitused',
      ),
    ),
    floatingActionButton: widget.contributionsOnly || widget.canManageActivities
        ? FloatingActionButton.extended(
            onPressed: widget.contributionsOnly ? _addContribution : _edit,
            icon: const Icon(Icons.add),
            label: Text(
              widget.contributionsOnly ? 'Lisa panus' : 'Planeeri tegevus',
            ),
          )
        : null,
    body: StreamBuilder<List<ActivityModel>>(
      key: ValueKey(widget.organizationId),
      stream: _activities,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Tegevuste laadimine ebaõnnestus.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!
            .where((a) => a.isContribution == widget.contributionsOnly)
            .toList();
        final now = DateTime.now();
        final unknown = all.where((a) => a.startsAt == null).toList();
        final upcoming = all.where((a) => a.isUpcomingOrOngoing(now)).toList()
          ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
        final past =
            all
                .where((a) => a.startsAt != null && !a.isUpcomingOrOngoing(now))
                .toList()
              ..sort((a, b) => b.startsAt!.compareTo(a.startsAt!));
        final dayActivities = all.where((a) => a.occursOn(_selected)).toList()
          ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
        final shown = _calendar ? dayActivities : (_showPast ? past : upcoming);
        return StreamBuilder<bool>(
          stream: _canConfirm,
          builder: (context, rights) => StreamBuilder<List<ActivityParticipantModel>>(
            stream: _myResponses,
            builder: (context, responses) => widget.contributionsOnly
                ? _contributions(all, rights.data == true, responses)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Kalender'),
                            selected: _calendar,
                            onSelected: (_) => setState(() => _calendar = true),
                          ),
                          ChoiceChip(
                            label: const Text('Nimekiri'),
                            selected: !_calendar,
                            onSelected: (_) =>
                                setState(() => _calendar = false),
                          ),
                        ],
                      ),
                      if (_calendar) ...[
                        ActivityCalendar(
                          activities: all,
                          selectedDay: _selected,
                          onSelected: (day) => setState(() => _selected = day),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ActivitySchedule.date(_selected),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ] else
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('Tulemas (${upcoming.length})'),
                              selected: !_showPast,
                              onSelected: (_) =>
                                  setState(() => _showPast = false),
                            ),
                            ChoiceChip(
                              label: Text('Toimunud (${past.length})'),
                              selected: _showPast,
                              onSelected: (_) =>
                                  setState(() => _showPast = true),
                            ),
                          ],
                        ),
                      if (responses.hasError)
                        const Text(
                          'Sinu osalemisvastuseid ei õnnestunud laadida.',
                        ),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            _calendar
                                ? 'Sellel päeval tegevusi ega koolitusi ei ole.'
                                : 'Tegevusi ega koolitusi ei ole.',
                          ),
                        ),
                      for (final activity in shown)
                        _card(activity, rights.data == true, responses),
                      if (unknown.isNotEmpty)
                        ExpansionTile(
                          title: Text('Täpsustamata ajaga (${unknown.length})'),
                          subtitle: const Text(
                            'Need tegevused vajavad kalendrisse jõudmiseks korrektset aega.',
                          ),
                          children: [
                            for (final activity in unknown)
                              _card(activity, rights.data == true, responses),
                          ],
                        ),
                    ],
                  ),
          ),
        );
      },
    ),
  );

  Widget _contributions(
    List<ActivityModel> all,
    bool admin,
    AsyncSnapshot<List<ActivityParticipantModel>> snapshot,
  ) {
    if (snapshot.hasError) {
      return const Center(
        child: Text('Panuste laadimine ebaõnnestus. Ava vaade uuesti.'),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = snapshot.data!;
    bool pending(ActivityModel a) => rows.any(
      (p) =>
          p.activityId == a.id &&
          p.attendanceStatus == ActivityAttendanceStatus.notConfirmed,
    );
    final items =
        all
            .where(
              (a) =>
                  (admin ||
                      rows.any(
                        (p) =>
                            p.activityId == a.id &&
                            p.userId == widget.currentUid,
                      )) &&
                  (!_pendingOnly || pending(a)),
            )
            .toList()
          ..sort(
            (a, b) => (b.startsAt ?? DateTime(1900)).compareTo(
              a.startsAt ?? DateTime(1900),
            ),
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          admin
              ? 'Tehtud vabatahtlik töö ja liikmete esitatud panused.'
              : 'Sinu tehtud töö. Kinnitatud tunnid lähevad statistikasse.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(admin ? 'Kõik panused' : 'Minu panused'),
              selected: !_pendingOnly,
              onSelected: (_) => setState(() => _pendingOnly = false),
            ),
            ChoiceChip(
              label: Text(
                'Ootab kinnitamist (${all.where((a) => (admin || rows.any((p) => p.activityId == a.id && p.userId == widget.currentUid)) && pending(a)).length})',
              ),
              selected: _pendingOnly,
              onSelected: (_) => setState(() => _pendingOnly = true),
            ),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _pendingOnly
                  ? 'Kinnitamist ootavaid panuseid ei ole.'
                  : 'Panuseid pole veel. Lisa esimene tehtud töö.',
            ),
          ),
        for (final a in items) _card(a, admin, snapshot),
      ],
    );
  }

  Widget _card(
    ActivityModel activity,
    bool admin,
    AsyncSnapshot<List<ActivityParticipantModel>> responses,
  ) {
    final response = responses.data
        ?.where(
          (r) => r.activityId == activity.id && r.userId == widget.currentUid,
        )
        .firstOrNull;
    final attending = [
      ActivityParticipationStatus.attending,
      ActivityParticipationStatus.registered,
    ].contains(response?.status);
    final declined = [
      ActivityParticipationStatus.notAttending,
      ActivityParticipationStatus.cannotAttend,
    ].contains(response?.status);
    return Card(
      child: ExpansionTile(
        key: PageStorageKey('${widget.organizationId}-${activity.id}'),
        title: Text(activity.title),
        subtitle: Text(
          '${activityTypeLabels[activity.type] ?? 'Tegevus'} · ${activity.isContribution ? calendarDateLabel(activity.startsAt == null ? null : ActivitySchedule.inEstonia(activity.startsAt!)) : ActivitySchedule.format(activity.startsAt)}${activity.location.isEmpty ? '' : '\n${activity.location}'}${activity.isContribution ? '\n${_contributionSummary(activity, admin, responses.data ?? [])}' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (activity.description.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(activity.description),
            ),
          if (activity.endsAt != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Lõpp: ${ActivitySchedule.format(activity.endsAt)}'),
            ),
          if (activity.startsAt == null && activity.startTime.isNotEmpty)
            Text('Sisestatud aeg: ${activity.startTime}'),
          if (admin && !activity.isContribution)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _edit(activity),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Muuda tegevust'),
              ),
            ),
          if (activity.isUpcomingOrOngoing(DateTime.now()))
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Osalen'),
                  selected: attending,
                  onSelected:
                      _savingResponse != null ||
                          !responses.hasData ||
                          responses.hasError
                      ? null
                      : (_) => _respond(activity, true),
                ),
                ChoiceChip(
                  label: const Text('Ei osale'),
                  selected: declined,
                  onSelected:
                      _savingResponse != null ||
                          !responses.hasData ||
                          responses.hasError
                      ? null
                      : (_) => _respond(activity, false),
                ),
              ],
            ),
          if (_savingResponse == activity.id) const LinearProgressIndicator(),
          if (response?.attendanceStatus == ActivityAttendanceStatus.confirmed)
            Text(
              'Sinu osalemine on kinnitatud${response!.hours == null ? '' : ' · ${response.hours!.toStringAsFixed(1)} t'}',
            ),
          if (response?.attendanceStatus == ActivityAttendanceStatus.absent)
            const Text('Sinu osalemine: ei osalenud'),
          if (admin) _attendance(activity),
        ],
      ),
    );
  }

  String _contributionSummary(
    ActivityModel activity,
    bool admin,
    List<ActivityParticipantModel> participants,
  ) {
    final rows = participants
        .where(
          (p) =>
              p.activityId == activity.id &&
              (admin || p.userId == widget.currentUid),
        )
        .toList();
    final confirmed = rows
        .where((p) => p.attendanceStatus == ActivityAttendanceStatus.confirmed)
        .toList();
    final pending = rows
        .where(
          (p) => p.attendanceStatus == ActivityAttendanceStatus.notConfirmed,
        )
        .toList();
    if (!admin && rows.isNotEmpty) {
      return '${statisticsHours(rows.first.hours)} · ${pending.isNotEmpty
          ? 'Ootab admini kinnitust'
          : confirmed.isNotEmpty
          ? 'Kinnitatud'
          : 'Ei kinnitatud'}';
    }
    return '${rows.length} liiget · ${statisticsHours(confirmed.fold<double>(0, (sum, p) => sum + (p.hours ?? 0)))} kinnitatud${pending.isEmpty ? '' : ' · ${pending.length} ootel'}';
  }

  Widget _attendance(
    ActivityModel activity,
  ) => StreamBuilder<List<ActivityMember>>(
    stream: _members,
    builder: (context, members) => StreamBuilder<List<ActivityParticipantModel>>(
      stream: _service.streamActivityParticipants(
        activityId: activity.id,
        organizationId: widget.organizationId,
      ),
      builder: (context, participants) {
        if (members.hasError || participants.hasError) {
          return const Text('Osalejate laadimine ebaõnnestus.');
        }
        if (!members.hasData || !participants.hasData) {
          return const LinearProgressIndicator();
        }
        final rows = participants.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 24),
            Text(
              'Osalemise kinnitamine',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              activity.isContribution
                  ? 'Kinnita tehtud töö ja tunnid. Linnuke salvestatakse kohe.'
                  : 'Märgi kohal olnud liikmed. Linnuke salvestatakse kohe.',
            ),
            for (final member in members.data!.where(
              (m) =>
                  !activity.isContribution || rows.any((p) => p.userId == m.id),
            ))
              _attendanceRow(
                activity,
                member,
                rows.where((p) => p.userId == member.id).firstOrNull,
              ),
            for (final old in rows.where(
              (p) => !members.data!.any((m) => m.id == p.userId),
            ))
              FutureBuilder<String>(
                future: _service.loadParticipantDisplayName(old.userId),
                builder: (context, name) => _attendanceRow(
                  activity,
                  ActivityMember(
                    old.userId,
                    '${name.data ?? 'Endine liige'} · mitteaktiivne',
                  ),
                  old,
                  canEdit: false,
                ),
              ),
            if (members.data!.isEmpty && rows.isEmpty)
              const Text('Aktiivseid liikmeid ei ole.'),
          ],
        );
      },
    ),
  );
  Widget _attendanceRow(
    ActivityModel activity,
    ActivityMember member,
    ActivityParticipantModel? participant, {
    bool canEdit = true,
  }) => ActivityAttendanceRow(
    key: ValueKey('${activity.id}-${member.id}'),
    name: member.name,
    responseLabel: switch (participant?.status) {
      ActivityParticipationStatus.attendedSelfReported => 'Esitatud panus',
      ActivityParticipationStatus.attending ||
      ActivityParticipationStatus.registered => 'Plaanib osaleda',
      ActivityParticipationStatus.notAttending ||
      ActivityParticipationStatus.cannotAttend => 'Ei plaani osaleda',
      _ => 'Osalemissoov märkimata',
    },
    canEdit: canEdit,
    confirmed:
        participant?.attendanceStatus == ActivityAttendanceStatus.confirmed,
    hours: participant?.hours,
    onSave: (checked, hours) => _service.confirmParticipation(
      activityId: activity.id,
      userId: member.id,
      organizationId: widget.organizationId,
      attendanceStatus: checked
          ? ActivityAttendanceStatus.confirmed
          : ActivityAttendanceStatus.absent,
      confirmedBy: widget.currentUid,
      hours: hours,
    ),
  );
}
