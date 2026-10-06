import '../screens/member_profile_screen.dart';
import '../screens/self_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/availability_model.dart';
import '../models/duty_crew.dart';
import '../models/membership_model.dart';
import '../models/response_readiness.dart';
import '../services/membership_service.dart';
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
    this.onOpenDetails,
    this.showOffDuty = false,
    this.compact = false,
    this.memberPreviewLimit,
  });
  final String organizationId, currentUid;
  final VoidCallback? onOpenDetails;
  final bool showOffDuty;
  final bool compact;
  final int? memberPreviewLimit;
  final CrewReadinessStreams Function(String)? streamsForOrganization;
  @override
  State<CrewReadinessCard> createState() => _CrewReadinessCardState();
}

class _CrewReadinessCardState extends State<CrewReadinessCard> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<Map<String, dynamic>>? _members;
  Map<String, dynamic>? _serverState;
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
    _serverState = null;
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
    if (streams.readiness != null) {
      _listen(streams.readiness!, (data) {
        _serverState = data;
        _availability = const [];
        _unavailable = (data['unavailableUserIds'] as List)
            .cast<String>()
            .toSet();
        _minimum = data['minimum'] as int;
      });
    } else {
      _listen(streams.availability, (data) => _availability = data);
      _listen(streams.unavailable, (data) => _unavailable = data);
      _listen(streams.minimum, (data) => _minimum = data);
    }
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

  Future<void> _openProfile(String uid) async {
    final matches = (_members ?? []).where((m) => m['userId'] == uid);
    if (matches.isEmpty) return;
    final membership = matches.first;
    final own = (_members ?? []).where((m) => m['userId'] == widget.currentUid);
    final canManage =
        own.isNotEmpty && MembershipRole.isOrgAdmin(own.first['role']);
    try {
      if (uid == widget.currentUid) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SelfProfileScreen(
              currentUid: widget.currentUid,
              organizationId: widget.organizationId,
              canManageRoles: canManage,
            ),
          ),
        );
        return;
      }
      final user = canManage
          ? (await FirebaseFirestore.instance.doc('users/$uid').get()).data()
          : null;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MemberProfileScreen(
            userData:
                user ??
                {
                  'name': MembershipService().safeDisplayNameFromMembership(
                    membership,
                  ),
                },
            membershipData: membership,
            membershipId: '${uid}_${widget.organizationId}',
            organizationId: widget.organizationId,
            currentUid: widget.currentUid,
            canManageRoles: canManage,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liikme profiili ei saanud avada.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (widget.onOpenDetails == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpenDetails,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            if (widget.memberPreviewLimit == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('Vaata täpsemalt →'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_dutyPaused == true &&
        (_errors.isNotEmpty ||
            _members == null ||
            _availability == null ||
            _unavailable == null ||
            _minimum == null)) {
      return OrganizationDutyPauseCard(reason: _pauseReason);
    }
    if (_errors.isNotEmpty) {
      return AppSectionCard(
        title: 'Ühingu valmidus',
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
        title: 'Ühingu valmidus',
        child: LinearProgressIndicator(),
      );
    }
    return CrewReadinessView(
      authoritative: _serverState,
      organizationPaused: _dutyPaused == true,
      pauseReason: _pauseReason,
      members: _serverState != null
          ? (_serverState!['crew'] as List)
                .map((raw) {
                  final m = Map<String, dynamic>.from(raw as Map);
                  return DutyCrewMember(
                    userId: m['userId'],
                    name: m['name'],
                    status: m['status'],
                    level: m['level'],
                    arrivalMinutes: m['arrivalMinutes'],
                  );
                })
                .where(
                  (m) =>
                      widget.showOffDuty ||
                      m.status != AvailabilityStatus.offDuty,
                )
                .toList()
          : dutyCrew(
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
      compact: widget.compact,
      memberPreviewLimit: widget.memberPreviewLimit,
      onContact: _contact,
      onOpenMember: _openProfile,
      onOpenDetails: widget.onOpenDetails,
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
    this.onOpenMember,
    this.onOpenDetails,
    this.authoritative,
    this.organizationPaused = false,
    this.pauseReason = '',
    this.busyUserId,
    this.showOffDuty = false,
    this.compact = false,
    this.memberPreviewLimit,
  });
  final List<DutyCrewMember> members;
  final bool organizationPaused;
  final String pauseReason;
  final Map<String, dynamic>? authoritative;
  final int minimumCrew;
  final String currentUid;
  final String? busyUserId;
  final bool showOffDuty;
  final bool compact;
  final int? memberPreviewLimit;
  final void Function(String, bool) onContact;
  final ValueChanged<String>? onOpenMember;
  final VoidCallback? onOpenDetails;
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
      organizationPaused: organizationPaused,
      minimumCrewRequired: minimumCrew,
      onDutyCount: onDuty.length,
      secondLevelOnDutyCount: onDuty
          .where((m) => m.level == SeaRescueLevel.level2)
          .length,
    );
    final ready =
        !organizationPaused &&
        (authoritative?['ready'] as bool? ?? readiness.isReady);
    final missing = organizationPaused
        ? ['Ühing on valvest maas']
        : (authoritative?['missing'] as List?)?.cast<String>() ??
              readiness.missingRequirements;
    final secondLevelCount =
        authoritative?['secondLevelOnDutyCount'] as int? ??
        onDuty.where((m) => m.level == SeaRescueLevel.level2).length;
    final eligibleCount =
        authoritative?['onDutyCount'] as int? ?? onDuty.length;
    final status = organizationPaused
        ? 'unavailable'
        : authoritative?['operationalStatus'];
    final statusColor = status == 'unknown'
        ? AppColors.offDuty
        : status == 'delayed'
        ? AppColors.delayed
        : ready
        ? AppColors.ready
        : AppColors.critical;
    final statusText = status == 'unknown'
        ? 'VALMIDUS TEADMATA'
        : status == 'delayed'
        ? 'REAGEERIB VIIVITUSEGA'
        : ready
        ? (compact || memberPreviewLimit != null
              ? 'SAR-valmis'
              : 'REAGEERIMISVALMIS')
        : (compact || memberPreviewLimit != null
              ? 'Ei ole SAR-valmis'
              : 'EI OLE REAGEERIMISVALMIS');
    final ordered = [...onDuty, ...delayed, if (showOffDuty) ...offDuty];
    final visibleMembers = memberPreviewLimit == null
        ? ordered
        : ordered.take(memberPreviewLimit!).toList();
    if (memberPreviewLimit != null) {
      return _dashboardCard(
        context,
        visibleMembers: visibleMembers,
        totalMembers: ordered.length,
        statusColor: statusColor,
        title: organizationPaused
            ? 'Ühing on valvest maas'
            : status == 'unknown'
            ? 'Ühingu valmidus teadmata'
            : status == 'delayed'
            ? 'Ühing reageerib viivitusega'
            : ready
            ? 'Ühing on reageerimisvalmis'
            : 'Ühing ei ole reageerimisvalmis',
        eligibleCount: eligibleCount,
        secondLevelCount: secondLevelCount,
        missing: ready ? const [] : missing,
      );
    }
    return AppSectionCard(
      title: 'Ühingu valmidus',
      padding: const EdgeInsets.all(12),
      leading: Icon(Icons.shield_outlined, color: statusColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact && memberPreviewLimit == null)
            Text(
              'SAR REAGEERIMISVALMIDUS',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          Text(
            statusText,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: statusColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Valves $eligibleCount/$minimumCrew · II aste: $secondLevelCount ${secondLevelCount > 0 ? '✓' : '— puudub'}',
          ),
          if (!ready)
            Text(missing.join(' · '), style: TextStyle(color: statusColor)),
          if (organizationPaused && pauseReason.trim().isNotEmpty)
            Text(pauseReason),
          if (!compact && delayed.isNotEmpty)
            Text('Hilinemisega: ${delayed.length}'),
          if (!compact && showOffDuty) Text('Mitte valves: ${offDuty.length}'),
          if (!compact && members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Valves ega hilinemisega liikmeid praegu ei ole.'),
            ),
          if (!compact)
            for (final group in [onDuty, delayed, if (showOffDuty) offDuty])
              if (group.any(visibleMembers.contains)) ...[
                const SizedBox(height: 8),
                Text(
                  group.first.status == AvailabilityStatus.onDuty
                      ? 'Valves'
                      : group.first.status == AvailabilityStatus.delayed
                      ? 'Hilinemisega'
                      : 'Mitte valves',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                for (final member in group.where(visibleMembers.contains))
                  _row(context, member),
              ],
          if (!compact && visibleMembers.length < ordered.length)
            Text(
              'Veel ${ordered.length - visibleMembers.length} liiget · kogu nimekiri ühingu valmiduse vaates',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required List<DutyCrewMember> visibleMembers,
    required int totalMembers,
    required Color statusColor,
    required String title,
    required int eligibleCount,
    required int secondLevelCount,
    required List<String> missing,
  }) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    Widget summary(String text, bool met) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: met ? AppColors.readySurface : AppColors.criticalSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: met ? AppColors.ready : AppColors.critical,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: statusColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: statusColor),
                  ),
                ),
                if (onOpenDetails != null && !largeText) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onOpenDetails,
                    child: const Text('Detailid'),
                  ),
                ],
              ],
            ),
            if (onOpenDetails != null && largeText)
              TextButton(
                onPressed: onOpenDetails,
                child: const Text('Detailid'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                summary(
                  'Valves: $eligibleCount / $minimumCrew',
                  eligibleCount >= minimumCrew,
                ),
                summary(
                  'II aste: ${secondLevelCount > 0 ? 'olemas' : 'puudub'}',
                  secondLevelCount > 0,
                ),
              ],
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(missing.join(' · '), style: TextStyle(color: statusColor)),
            ],
            if (organizationPaused && pauseReason.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(pauseReason),
            ],
            const SizedBox(height: 12),
            if (visibleMembers.isEmpty)
              const Text('Valves ega hilinemisega liikmeid praegu ei ole.')
            else
              LayoutBuilder(
                builder: (context, bounds) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in visibleMembers)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: bounds.maxWidth.clamp(0, 380),
                        ),
                        child: _memberPill(context, member),
                      ),
                  ],
                ),
              ),
            if (visibleMembers.length < totalMembers) ...[
              const SizedBox(height: 8),
              Text(
                'Veel ${totalMembers - visibleMembers.length} liiget · vaata detaile',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberPill(BuildContext context, DutyCrewMember member) {
    final delayed = member.status == AvailabilityStatus.delayed;
    final offDuty = member.status == AvailabilityStatus.offDuty;
    final color = delayed
        ? AppColors.delayed
        : offDuty
        ? AppColors.offDuty
        : AppColors.ready;
    final background = delayed
        ? AppColors.delayedSurface
        : offDuty
        ? AppColors.offDutySurface
        : const Color(0xFFE8F5F2);
    final level = member.level == SeaRescueLevel.level2
        ? 'II aste'
        : member.level == SeaRescueLevel.level1
        ? 'I aste'
        : null;
    final status = delayed
        ? (member.arrivalMinutes == null
              ? 'Hilinemise aeg täpsustamata'
              : 'Hilinemisega (+${member.arrivalMinutes} min)')
        : offDuty
        ? 'Mitte valves'
        : 'Valves';
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final details = Semantics(
      label: '${member.userId == currentUid ? 'Mina. ' : ''}$status',
      child: InkWell(
        onTap: onOpenMember == null ? null : () => onOpenMember!(member.userId),
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    member.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: color),
                  ),
                  if (level != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBlueStrong,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        level,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.actionBlue,
                        ),
                      ),
                    ),
                ],
              ),
              if (delayed || offDuty)
                Text(
                  status,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
            ],
          ),
        ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Helista: ${member.name}',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          color: AppColors.actionBlue,
          onPressed: busyUserId != null
              ? null
              : () => onContact(member.userId, false),
          icon: const Icon(Icons.phone_outlined),
        ),
        IconButton(
          tooltip: 'SMS: ${member.name}',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          color: color,
          onPressed: busyUserId != null
              ? null
              : () => onContact(member.userId, true),
          icon: const Icon(Icons.sms_outlined),
        ),
      ],
    );
    return Material(
      key: ValueKey('crew-pill-${member.userId}'),
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.circle, size: 10, color: color),
                ),
                const SizedBox(width: 8),
                Flexible(child: details),
                if (!largeText) ...[const SizedBox(width: 4), actions],
              ],
            ),
            if (largeText) actions,
            if (busyUserId == member.userId)
              const SizedBox(width: 96, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, DutyCrewMember member) {
    final narrow = MediaQuery.textScalerOf(context).scale(14) > 20;
    final delayed = member.status == AvailabilityStatus.delayed;
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
    final details = InkWell(
      onTap: onOpenMember == null ? null : () => onOpenMember!(member.userId),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: details),
              if (!narrow) ...[const SizedBox(width: 4), actions],
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
    this.readiness,
  });
  final Stream<Map<String, dynamic>> organization;
  final Stream<List<Map<String, dynamic>>> members;
  final Stream<List<AvailabilityModel>> availability;
  final Stream<Set<String>> unavailable;
  final Stream<int> minimum;
  final Stream<Map<String, dynamic>>? readiness;

  factory CrewReadinessStreams.live(String org) => CrewReadinessStreams(
    organization: FirebaseFirestore.instance
        .collection('commands')
        .doc(org)
        .snapshots()
        .map((doc) => doc.data() ?? {}),
    members: MembershipService()
        .streamActiveMembershipsForOrganization(org)
        .map((docs) => docs.map((doc) => doc.data()).toList()),
    availability: const Stream.empty(),
    unavailable: const Stream.empty(),
    minimum: const Stream.empty(),
    readiness: ReadinessAvailabilityService().streamReadiness(org),
  );
}
