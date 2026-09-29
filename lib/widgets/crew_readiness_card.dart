import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/availability_model.dart';
import '../models/duty_crew.dart';
import '../models/membership_model.dart';
import '../models/response_readiness.dart';
import '../services/availability_service.dart';
import '../services/membership_service.dart';
import '../services/platform_readiness_service.dart';
import '../services/readiness_availability_service.dart';
import '../services/member_contact_service.dart';
import '../theme/app_theme.dart';
import 'app_section_card.dart';

class CrewReadinessCard extends StatefulWidget {
  const CrewReadinessCard({
    super.key,
    required this.organizationId,
    required this.currentUid,
    this.streamsForOrganization,
    this.showOffDuty = false,
  });
  final String organizationId, currentUid;
  final bool showOffDuty;
  final CrewReadinessStreams Function(String)? streamsForOrganization;
  @override
  State<CrewReadinessCard> createState() => _CrewReadinessCardState();
}

class _CrewReadinessCardState extends State<CrewReadinessCard> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<Map<String, dynamic>>? _members;
  List<AvailabilityModel>? _availability;
  Set<String>? _unavailable;
  final _errors = <Object>{};
  int? _minimum;
  bool? _dutyPaused;
  String _pauseReason = '';
  String? _busy;
  Timer? _timer;
  int _generation = 0;
  void _listen<T>(Stream<T> stream, void Function(T) update) {
    final generation = _generation;
    final source = Object();
    _subscriptions.add(
      stream.listen(
        (data) {
          if (mounted && generation == _generation) {
            setState(() {
              _errors.remove(source);
              update(data);
            });
          }
        },
        onError: (Object _) {
          if (mounted && generation == _generation) {
            setState(() => _errors.add(source));
          }
        },
      ),
    );
  }

  void _subscribe() {
    _generation++;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _members = null;
    _availability = null;
    _unavailable = null;
    _minimum = null;
    _dutyPaused = null;
    _errors.clear();
    _pauseReason = '';
    final org = widget.organizationId;
    final streams =
        widget.streamsForOrganization?.call(org) ??
        CrewReadinessStreams.live(org);
    _listen(streams.organization, (data) {
      _dutyPaused = data['dutyPaused'] == true;
      _pauseReason = data['dutyPauseReason'] as String? ?? '';
    });
    _listen(streams.members, (data) => _members = data);
    _listen(streams.availability, (data) => _availability = data);
    _listen(streams.unavailable, (data) => _unavailable = data);
    _listen(streams.minimum, (data) => _minimum = data);
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(CrewReadinessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) _subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  Future<void> _contact(String uid, bool sms) async {
    if (_busy != null) return;
    final org = widget.organizationId;
    setState(() => _busy = uid);
    try {
      final uri = await MemberContactService().contactUri(
        organizationId: org,
        userId: uid,
        sms: sms,
      );
      if (!mounted || widget.organizationId != org) return;
      if (uri == null) {
        _message('Liikmel pole korrektset telefoninumbrit lisatud.');
        return;
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message(
          sms
              ? 'Sõnumirakendust ei õnnestunud avada.'
              : 'Helistajat ei õnnestunud avada.',
        );
      }
    } catch (_) {
      _message(
        'Kontakti ei õnnestunud avada. Kontrolli ühendust ja liikmesust.',
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dutyPaused == true) {
      return OrganizationDutyPauseCard(reason: _pauseReason);
    }
    if (_errors.isNotEmpty) {
      return AppSectionCard(
        title: 'Ühingu reageerimisvalmidus',
        child: Column(
          children: [
            const Text(
              'Meeskonna andmeid ei õnnestunud laadida. Kontrolli ühendust.',
            ),
            TextButton(
              onPressed: () => setState(_subscribe),
              child: const Text('Proovi uuesti'),
            ),
          ],
        ),
      );
    }
    if (_dutyPaused == null ||
        _members == null ||
        _availability == null ||
        _unavailable == null ||
        _minimum == null) {
      return const AppSectionCard(
        title: 'Ühingu reageerimisvalmidus',
        child: LinearProgressIndicator(),
      );
    }
    return CrewReadinessView(
      members: dutyCrew(
        memberships: _members!,
        availability: _availability!,
        periods: const [],
        rules: const [],
        unavailableUserIds: _unavailable!,
        includeOffDuty: widget.showOffDuty,
        now: DateTime.now(),
      ),
      minimumCrew: _minimum!,
      currentUid: widget.currentUid,
      busyUserId: _busy,
      showOffDuty: widget.showOffDuty,
      onContact: _contact,
    );
  }
}

class CrewReadinessView extends StatelessWidget {
  const CrewReadinessView({
    super.key,
    required this.members,
    required this.minimumCrew,
    required this.currentUid,
    required this.onContact,
    this.busyUserId,
    this.showOffDuty = false,
  });
  final List<DutyCrewMember> members;
  final int minimumCrew;
  final String currentUid;
  final String? busyUserId;
  final bool showOffDuty;
  final void Function(String, bool) onContact;
  @override
  Widget build(BuildContext context) {
    final onDuty = members
        .where((m) => m.status == AvailabilityStatus.onDuty)
        .toList();
    final delayed = members
        .where((m) => m.status == AvailabilityStatus.delayed)
        .toList();
    final offDuty = members
        .where((m) => m.status == AvailabilityStatus.offDuty)
        .toList();
    final readiness = ResponseReadiness.evaluate(
      minimumCrewRequired: minimumCrew,
      onDutyCount: onDuty.length,
      secondLevelOnDutyCount: onDuty
          .where((m) => m.level == SeaRescueLevel.level2)
          .length,
    );
    return AppSectionCard(
      title: 'Ühingu reageerimisvalmidus',
      leading: Icon(
        Icons.shield_outlined,
        color: readiness.isReady ? AppColors.ready : AppColors.delayed,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            readiness.isReady
                ? 'SAR: reageerimisvalmis'
                : 'SAR: ${readiness.missingRequirements.join(' · ')}',
            style: TextStyle(
              color: readiness.isReady ? AppColors.ready : AppColors.delayed,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Valves ${onDuty.length}${minimumCrew > 0 ? ' · vajalik vähemalt $minimumCrew' : ''} · hilinemisega ${delayed.length}',
          ),
          if (showOffDuty) Text('Mitte valves: ${offDuty.length}'),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Valves ega hilinemisega liikmeid praegu ei ole.'),
            ),
          for (final group in [onDuty, delayed, if (showOffDuty) offDuty])
            if (group.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                group.first.status == AvailabilityStatus.onDuty
                    ? 'Valves'
                    : group.first.status == AvailabilityStatus.delayed
                    ? 'Hilinemisega'
                    : 'Mitte valves',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final member in group) _row(context, member),
            ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, DutyCrewMember member) {
    final narrow =
        MediaQuery.sizeOf(context).width < 390 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    final delayed = member.status == AvailabilityStatus.delayed;
    final initials = member.name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.substring(0, 1))
        .join()
        .toUpperCase();
    final status = delayed
        ? (member.arrivalMinutes == null
              ? 'Hilinemise aeg täpsustamata'
              : 'Hilinemisega (+${member.arrivalMinutes} min)')
        : member.status == AvailabilityStatus.offDuty
        ? 'Mitte valves'
        : 'Valves';
    final level = member.level == SeaRescueLevel.level2
        ? 'II aste'
        : member.level == SeaRescueLevel.level1
        ? 'I aste'
        : 'Aste puudub';
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Helista: ${member.name}',
          onPressed: busyUserId != null
              ? null
              : () => onContact(member.userId, false),
          icon: const Icon(Icons.phone_outlined),
        ),
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'SMS: ${member.name}',
          onPressed: busyUserId != null
              ? null
              : () => onContact(member.userId, true),
          icon: const Icon(Icons.sms_outlined),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlueStrong,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceBlue,
                child: Text(initials, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${member.name}${member.userId == currentUid ? ' · Mina' : ''}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '$status · $level',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: delayed
                            ? AppColors.delayed
                            : member.status == AvailabilityStatus.offDuty
                            ? AppColors.offDuty
                            : AppColors.ready,
                      ),
                    ),
                  ],
                ),
              ),
              if (!narrow) actions,
            ],
          ),
          if (narrow) Align(alignment: Alignment.centerRight, child: actions),
          if (busyUserId == member.userId) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class OrganizationDutyPauseCard extends StatelessWidget {
  const OrganizationDutyPauseCard({super.key, required this.reason});
  final String reason;
  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: 'Ühing on valvest maas',
    leading: const Icon(Icons.pause_circle_outline),
    child: Text(
      reason.trim().isEmpty ? 'Ühingu valveaja arvestus on peatatud.' : reason,
    ),
  );
}

class CrewReadinessStreams {
  const CrewReadinessStreams({
    required this.organization,
    required this.members,
    required this.availability,
    required this.unavailable,
    required this.minimum,
  });
  final Stream<Map<String, dynamic>> organization;
  final Stream<List<Map<String, dynamic>>> members;
  final Stream<List<AvailabilityModel>> availability;
  final Stream<Set<String>> unavailable;
  final Stream<int> minimum;

  factory CrewReadinessStreams.live(String org) => CrewReadinessStreams(
    organization: FirebaseFirestore.instance
        .collection('commands')
        .doc(org)
        .snapshots()
        .map((doc) => doc.data() ?? {}),
    members: MembershipService()
        .streamActiveMembershipsForOrganization(org)
        .map((docs) => docs.map((doc) => doc.data()).toList()),
    availability: AvailabilityService().streamOrganizationAvailability(
      organizationId: org,
    ),
    unavailable: ReadinessAvailabilityService().streamUnavailableMembers(org),
    minimum: PlatformReadinessService()
        .streamOrganizationSummary(organizationId: org)
        .map((data) => data.isEmpty ? 0 : data.first.minimumCrewRequired),
  );
}
