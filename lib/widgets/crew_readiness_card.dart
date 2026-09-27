import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/availability_model.dart';
import '../models/duty_crew.dart';
import '../models/membership_model.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../models/response_readiness.dart';
import '../services/availability_service.dart';
import '../services/membership_service.dart';
import '../services/platform_readiness_service.dart';
import '../services/planned_unavailability_service.dart';
import '../services/member_contact_service.dart';
import '../theme/app_theme.dart';
import 'app_section_card.dart';

class CrewReadinessCard extends StatefulWidget {
  const CrewReadinessCard({
    super.key,
    required this.organizationId,
    required this.currentUid,
  });
  final String organizationId, currentUid;
  @override
  State<CrewReadinessCard> createState() => _CrewReadinessCardState();
}

class _CrewReadinessCardState extends State<CrewReadinessCard> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<Map<String, dynamic>>? _members;
  List<AvailabilityModel>? _availability;
  List<PlannedUnavailabilityModel>? _periods;
  List<PlannedUnavailabilityRuleModel>? _rules;
  int? _minimum;
  String? _error, _busy;
  Timer? _timer;
  int _generation = 0;
  void _listen<T>(Stream<T> stream, void Function(T) update) {
    final generation = _generation;
    _subscriptions.add(
      stream.listen(
        (data) {
          if (mounted && generation == _generation) {
            setState(() => update(data));
          }
        },
        onError: (Object _) {
          if (mounted && generation == _generation) {
            setState(
              () => _error =
                  'Meeskonna andmeid ei õnnestunud laadida. Kontrolli ühendust.',
            );
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
    _periods = null;
    _rules = null;
    _minimum = null;
    _error = null;
    final org = widget.organizationId;
    _listen(
      MembershipService().streamActiveMembershipsForOrganization(org),
      (docs) => _members = docs.map((d) => d.data()).toList(),
    );
    _listen(
      AvailabilityService().streamOrganizationAvailability(organizationId: org),
      (data) => _availability = data,
    );
    final planned = PlannedUnavailabilityService();
    _listen(
      planned.streamOrganizationPeriods(organizationId: org),
      (data) => _periods = data,
    );
    _listen(
      planned.streamOrganizationRules(organizationId: org),
      (data) => _rules = data,
    );
    _listen(
      PlatformReadinessService().streamOrganizationSummary(organizationId: org),
      (data) => _minimum = data.isEmpty ? 0 : data.first.minimumCrewRequired,
    );
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
    if (_error != null) {
      return AppSectionCard(
        title: 'Ühingu reageerimisvalmidus',
        child: Column(
          children: [
            Text(_error!),
            TextButton(
              onPressed: () => setState(_subscribe),
              child: const Text('Proovi uuesti'),
            ),
          ],
        ),
      );
    }
    if (_members == null ||
        _availability == null ||
        _periods == null ||
        _rules == null ||
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
        periods: _periods!,
        rules: _rules!,
        now: DateTime.now(),
      ),
      minimumCrew: _minimum!,
      currentUid: widget.currentUid,
      busyUserId: _busy,
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
  });
  final List<DutyCrewMember> members;
  final int minimumCrew;
  final String currentUid;
  final String? busyUserId;
  final void Function(String, bool) onContact;
  @override
  Widget build(BuildContext context) {
    final onDuty = members
        .where((m) => m.status == AvailabilityStatus.onDuty)
        .toList();
    final delayed = members
        .where((m) => m.status == AvailabilityStatus.delayed)
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
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Valves ega hilinemisega liikmeid praegu ei ole.'),
            ),
          for (final group in [onDuty, delayed])
            if (group.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                group.first.status == AvailabilityStatus.onDuty
                    ? 'Valves'
                    : 'Hilinemisega',
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
              ? 'Saabumisaeg täpsustamata'
              : 'Saabub ${member.arrivalMinutes} min pärast')
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
                        color: delayed ? AppColors.delayed : AppColors.ready,
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
