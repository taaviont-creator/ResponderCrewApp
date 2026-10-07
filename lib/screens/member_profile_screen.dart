import '../models/activity_schedule.dart';
import '../models/statistics_model.dart';
import '../services/statistics_service.dart';
import '../widgets/certificate_editor.dart';
import '../widgets/member_profile_section.dart';
import '../widgets/member_duty_calendar.dart';
import 'contribution_form_screen.dart';
import 'availability_screen.dart';
import '../widgets/app_date_field.dart';
import '../widgets/app_layout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../widgets/own_profile_editor.dart';
import '../services/member_contact_service.dart';
import 'equipment_screen.dart';
import 'activities_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/activity_model.dart';
import '../models/availability_model.dart';
import '../models/certificate_model.dart';
import '../models/certificate_access.dart';
import '../models/equipment_model.dart';
import '../models/effective_availability.dart';
import '../models/membership_model.dart';
import '../models/membership_tenure.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/activity_service.dart';
import '../services/availability_service.dart';
import '../services/certificate_service.dart';
import '../services/equipment_service.dart';
import '../services/membership_service.dart';
import '../services/planned_unavailability_service.dart';
import '../services/user_service.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.userData,
    required this.membershipData,
    required this.membershipId,
    required this.organizationId,
    required this.currentUid,
    required this.canManageRoles,
  });

  final Map<String, dynamic> userData;
  final Map<String, dynamic> membershipData;
  final String membershipId;
  final String organizationId;
  final String currentUid;
  final bool canManageRoles;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final _activityService = ActivityService();
  final _availabilityService = AvailabilityService();
  final _certificateService = CertificateService();
  final _equipmentService = EquipmentService();
  final _membershipService = MembershipService();
  final _plannedUnavailabilityService = PlannedUnavailabilityService();
  final _userService = UserService();

  late String _name;
  late String? _phone;
  late String _membershipRole;
  late String _seaRescueLevel;
  late DateTime? _membershipStartedAt;
  bool _savingMembershipDate = false;
  late Future<Map<String, dynamic>> _organization;
  late Future<ContributionReport?> _statistics;

  void _loadContext() {
    _organization = FirebaseFirestore.instance
        .collection('commands')
        .doc(widget.organizationId)
        .get()
        .then((doc) => doc.data() ?? <String, dynamic>{});
    _statistics = _loadStatistics()..ignore();
  }

  Future<ContributionReport?> _loadStatistics() async {
    if (!_canViewTargetParticipation) return null;
    final settings = await _organization;
    if (!widget.canManageRoles &&
        settings['allowMembersToViewStatistics'] != true) {
      return null;
    }
    final today = ActivitySchedule.inEstonia(DateTime.now());
    return StatisticsService().load(
      organizationId: widget.organizationId,
      from: DateTime(today.year),
      to: today,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadContext();
    _name = _stringValue(widget.userData['name'], 'Nimi puudub');
    _phone = _optionalString(widget.userData['phone']);
    _membershipRole = MembershipRole.normalize(widget.membershipData['role']);
    _seaRescueLevel = SeaRescueLevel.normalize(
      widget.membershipData['seaRescueLevel'],
    );
    _membershipStartedAt = _dateValue(
      widget.membershipData['membershipStartedAt'],
    );
  }

  @override
  void didUpdateWidget(MemberProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.currentUid != widget.currentUid) {
      _loadContext();
    }
    _name = _stringValue(widget.userData['name'], 'Nimi puudub');
    _phone = _optionalString(widget.userData['phone']);
    _membershipRole = MembershipRole.normalize(widget.membershipData['role']);
    _seaRescueLevel = SeaRescueLevel.normalize(
      widget.membershipData['seaRescueLevel'],
    );
    _membershipStartedAt = _dateValue(
      widget.membershipData['membershipStartedAt'],
    );
  }

  String _stringValue(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  DateTime? _dateValue(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    return null;
  }

  String get _targetUid => _stringValue(widget.membershipData['userId'], '');

  bool get _isOwnProfile =>
      _targetUid.isNotEmpty && _targetUid == widget.currentUid;

  bool get _canManageProfileMembership {
    if (!widget.canManageRoles) return false;
    if (_isOwnProfile && !MembershipRole.isOrgAdmin(_membershipRole)) {
      return false;
    }
    if (widget.currentUid.trim().isEmpty) return false;
    if (_targetUid.isEmpty) return false;

    final membershipOrganizationId = _membershipService
        .organizationIdFromMembership(widget.membershipData);
    return membershipOrganizationId == widget.organizationId;
  }

  bool get _canEditRole => _canManageProfileMembership;

  CertificateAccess get _certificateAccess => CertificateAccess(
    organizationId: widget.organizationId,
    currentUid: widget.currentUid,
    targetUid: _targetUid,
    organizationAdmin: _canManageProfileMembership,
  );

  bool get _canEditMembershipStartDate =>
      _isOwnProfile || _canManageProfileMembership;

  Future<void> _contact(bool sms) async {
    try {
      final uri = await MemberContactService().contactUri(
        organizationId: widget.organizationId,
        userId: _targetUid,
        sms: sms,
      );
      if (!mounted) return;
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Contact unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kontakti ei saanud avada. Telefoninumber võib puududa.',
            ),
          ),
        );
      }
    }
  }

  String _roleLabel(Object? role) {
    if (MembershipRole.isOrgAdmin(role)) {
      return 'Organisatsiooni administraator';
    }
    if (MembershipRole.isMember(role)) {
      return 'Liige';
    }
    return 'Roll puudub';
  }

  String _seaRescueLevelLabel(Object? level) {
    switch (SeaRescueLevel.normalize(level)) {
      case SeaRescueLevel.level1:
        return 'I aste';
      case SeaRescueLevel.level2:
        return 'II aste';
      default:
        return 'Määramata';
    }
  }

  String _membershipStatusLabel(Map<String, dynamic> membership) {
    final status = _stringValue(membership['status'], '');
    if (status == 'active') return 'Aktiivne';
    if (status == 'pending') return 'Ootel';
    if (status == 'removed') return 'Eemaldatud';
    if (status == 'rejected') return 'Tagasi lükatud';
    if (status.isNotEmpty) return status;

    if (membership['isActive'] == true) {
      return 'Aktiivne';
    }
    if (membership['isActive'] == false) {
      return 'Mitteaktiivne';
    }
    return 'Staatus puudub';
  }

  String _availabilityStatusLabel(Object? status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return 'Valves';
      case AvailabilityStatus.delayed:
        return 'Hilinemisega';
      case AvailabilityStatus.offDuty:
        return 'Mitte valves';
      default:
        return 'Valmisolek märkimata';
    }
  }

  Widget _buildAvailabilitySection() {
    if (_targetUid.isEmpty || widget.organizationId.trim().isEmpty) {
      return const _ProfileRow(label: 'Valmisolek', value: 'Mitte valves');
    }

    final periodsStream = _isOwnProfile
        ? _plannedUnavailabilityService.streamMyPeriods(
            organizationId: widget.organizationId,
          )
        : _plannedUnavailabilityService.streamOrganizationPeriods(
            organizationId: widget.organizationId,
          );
    final rulesStream = _isOwnProfile
        ? _plannedUnavailabilityService.streamMyRules(
            organizationId: widget.organizationId,
          )
        : _plannedUnavailabilityService.streamOrganizationRules(
            organizationId: widget.organizationId,
          );

    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService
          .streamOrganizationAvailability(organizationId: widget.organizationId)
          .map((items) {
            for (final item in items) {
              if (item.userId == _targetUid) return item;
            }
            return null;
          }),
      builder: (context, availabilitySnapshot) {
        return StreamBuilder<List<PlannedUnavailabilityModel>>(
          stream: periodsStream,
          builder: (context, periodsSnapshot) {
            return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
              stream: rulesStream,
              builder: (context, rulesSnapshot) {
                if (availabilitySnapshot.hasError ||
                    periodsSnapshot.hasError ||
                    rulesSnapshot.hasError) {
                  return const _ProfileRow(
                    label: 'Valmisolek',
                    value: 'Valmisoleku laadimine ebaõnnestus',
                  );
                }

                final availability = availabilitySnapshot.data;
                final manualStatus =
                    availability?.status ?? AvailabilityStatus.offDuty;
                final effectiveStatus = EffectiveAvailability.resolve(
                  userId: _targetUid,
                  manualStatus: manualStatus,
                  periods:
                      periodsSnapshot.data ??
                      const <PlannedUnavailabilityModel>[],
                  rules:
                      rulesSnapshot.data ??
                      const <PlannedUnavailabilityRuleModel>[],
                );

                final lines = <String>[
                  _availabilityStatusLabel(effectiveStatus),
                ];
                final responseMinutes = availability?.responseMinutes;
                if (effectiveStatus == AvailabilityStatus.delayed &&
                    responseMinutes != null &&
                    responseMinutes > 0) {
                  lines.add('Hilinemine: $responseMinutes min');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Praegu: ${lines.join(' · ')}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    MemberDutyCalendar(
                      userId: _targetUid,
                      status: manualStatus,
                      periods: periodsSnapshot.data ?? const [],
                      rules: rulesSnapshot.data ?? const [],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  bool get _canViewTargetPersonalEquipment =>
      _isOwnProfile || _canManageProfileMembership;

  String _equipmentCategoryLabel(String category) =>
      EquipmentCategory.label(category);

  String _equipmentStatusLabel(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return 'Vajab hooldust';
      case EquipmentStatus.broken:
        return 'Katki';
      case EquipmentStatus.outOfService:
        return 'Kasutusest väljas';
      default:
        return 'Korras';
    }
  }

  bool get _canViewTargetCertificates =>
      _isOwnProfile || _canManageProfileMembership;
  bool get _canViewTargetParticipation =>
      _isOwnProfile || _canManageProfileMembership;

  void _openEquipment({EquipmentModel? item, bool add = false}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EquipmentScreen(
            organizationId: widget.organizationId,
            currentUid: widget.currentUid,
            canManageEquipment: _canManageProfileMembership,
            initialView: _isOwnProfile ? 'mine' : 'members',
            editOnOpen: item,
            openPersonalCreateOnLoad: add && _isOwnProfile,
          ),
        ),
      );

  Widget _buildEquipmentSection() => StreamBuilder<List<EquipmentModel>>(
    stream: _equipmentService.streamVisibleEquipment(
      organizationId: widget.organizationId,
      currentUserId: widget.currentUid,
      canViewMemberPersonalEquipment: _canManageProfileMembership,
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Varustust ei õnnestunud laadida.');
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final items = snapshot.data!
          .where(
            (e) =>
                e.scope == EquipmentScope.organization &&
                    e.assignedToUserId == _targetUid ||
                _canViewTargetPersonalEquipment &&
                    e.scope == EquipmentScope.personal &&
                    e.ownerUserId == _targetUid,
          )
          .toList();
      if (items.isEmpty) {
        return const Text('Varustust pole veel lisatud ega väljastatud.');
      }
      return Column(
        children: [
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: Text(
                [
                  item.isPersonal ? 'Isiklik' : 'Ühingult väljastatud',
                  _equipmentCategoryLabel(item.category),
                  if (item.note.isNotEmpty) item.note,
                ].join(' · '),
              ),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(_equipmentStatusLabel(item.status)),
                  if (item.isPersonal && _isOwnProfile ||
                      _canManageProfileMembership)
                    IconButton(
                      tooltip: 'Muuda varustust',
                      onPressed: () => _openEquipment(item: item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Future<void> _editCertificate([CertificateModel? certificate]) async {
    if (!_certificateAccess.canAdd ||
        (certificate != null && !_certificateAccess.canEdit(certificate))) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CertificateEditor(
        existing: certificate,
        save: (draft) => _certificateService.addCertificate(
          certificateId: certificate?.id,
          organizationId: widget.organizationId,
          userId: _targetUid,
          userName: _name,
          title: draft.title,
          type: draft.type,
          issuer: draft.issuer,
          issuedAt: draft.issuedAt,
          expiresAt: draft.expiresAt,
          status: draft.status,
          note: draft.note,
          number: draft.number,
          noExpiry: draft.noExpiry,
          createdBy: widget.currentUid,
        ),
      ),
    );
  }

  Future<void> _archiveCertificate(CertificateModel certificate) async {
    if (!_certificateAccess.canEdit(certificate)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eemalda tunnistus profiilist?'),
        content: Text(certificate.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tühista'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eemalda'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _certificateService.archiveCertificate(certificate.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tunnistust ei saanud eemaldada.')),
        );
      }
    }
  }

  Widget _buildCertificatesSection() => StreamBuilder<List<CertificateModel>>(
    stream: _certificateService.streamMyCertificates(
      organizationId: widget.organizationId,
      userId: _targetUid,
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Tunnistusi ei õnnestunud laadida.');
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final items = snapshot.data!;
      if (items.isEmpty) return const Text('Tunnistusi pole veel lisatud.');
      return Column(
        children: [
          for (final c in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${c.title} · ${c.validityLabel}'),
              subtitle: Text(
                [
                  if (c.issuer.isNotEmpty) c.issuer,
                  if (c.number.isNotEmpty) 'Nr ${c.number}',
                  if (c.issuedAt.isNotEmpty)
                    'Väljastatud ${calendarDateLabel(parseCalendarDate(c.issuedAt))}',
                  c.noExpiry
                      ? 'Tähtajatu'
                      : parseCalendarDate(c.expiresAt) == null
                      ? 'Aegumiskuupäev teadmata'
                      : 'Kehtib kuni ${calendarDateLabel(parseCalendarDate(c.expiresAt))}',
                  if (c.note.isNotEmpty) c.note,
                ].join(' · '),
              ),
              trailing: _certificateAccess.canEdit(c)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Muuda tunnistust',
                          onPressed: () => _editCertificate(c),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eemalda tunnistus',
                          onPressed: () => _archiveCertificate(c),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    )
                  : null,
            ),
        ],
      );
    },
  );

  Future<void> _addContribution({bool training = false}) async {
    if (!_isOwnProfile && !_canManageProfileMembership) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionFormScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          canManage: _canManageProfileMembership,
          initialMemberId: _targetUid,
          initialType: training ? 'training' : null,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _statistics = _loadStatistics()..ignore());
    }
  }

  Widget _contributionButton({bool training = false}) =>
      _canManageProfileMembership || _isOwnProfile
      ? OutlinedButton.icon(
          onPressed: () => _addContribution(training: training),
          icon: const Icon(Icons.add),
          label: Text(training ? 'Lisa koolitus' : 'Lisa panus'),
        )
      : const SizedBox.shrink();

  Widget _buildTrainingSection() => _buildParticipationList(trainingOnly: true);

  Widget _buildParticipationList({
    bool trainingOnly = false,
  }) => StreamBuilder<List<ActivityModel>>(
    stream: _activityService.streamOrganizationActivities(
      organizationId: widget.organizationId,
    ),
    builder: (context, activities) => StreamBuilder<List<ActivityParticipantModel>>(
      stream: _activityService.streamUserParticipations(
        organizationId: widget.organizationId,
        userId: _targetUid,
      ),
      builder: (context, participation) {
        if (activities.hasError || participation.hasError) {
          return const Text('Koolitusi ei õnnestunud laadida.');
        }
        if (!activities.hasData || !participation.hasData) {
          return const LinearProgressIndicator();
        }
        final confirmed = {
          for (final p in participation.data!)
            if (p.attendanceStatus == ActivityAttendanceStatus.confirmed)
              p.activityId: p,
        };
        final items =
            activities.data!
                .where(
                  (a) =>
                      (!trainingOnly || a.type == ActivityType.training) &&
                      confirmed.containsKey(a.id),
                )
                .toList()
              ..sort(
                (a, b) => (b.startsAt ?? DateTime(1900)).compareTo(
                  a.startsAt ?? DateTime(1900),
                ),
              );
        if (items.isEmpty) {
          return Text(
            trainingOnly
                ? 'Kinnitatud koolitusi pole veel.'
                : 'Kinnitatud tegevusi pole veel.',
          );
        }
        return Column(
          children: [
            for (final a in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.teal,
                ),
                title: Text(a.title),
                subtitle: Text(
                  '${ActivitySchedule.format(a.startsAt)} · ${statisticsHours(confirmed[a.id]?.hours)}',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ActivitiesScreen(
                      contributionsOnly: a.isContribution,
                      organizationId: widget.organizationId,
                      currentUid: widget.currentUid,
                      canManageActivities: _canManageProfileMembership,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _buildContributionSection() => FutureBuilder<ContributionReport?>(
    future: _statistics,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () =>
              setState(() => _statistics = _loadStatistics()..ignore()),
          child: const Text('Panuste laadimine ebaõnnestus. Proovi uuesti'),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LinearProgressIndicator();
      }
      final matches =
          snapshot.data?.members
              .where((m) => m.userId == _targetUid)
              .toList() ??
          [];
      if (matches.isEmpty) {
        return _buildParticipationList();
      }
      final member = matches.first;
      final entries = member.entries
        ..sort(
          (a, b) => (b['date']?.toString() ?? '').compareTo(
            a['date']?.toString() ?? '',
          ),
        );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Panus: ${statisticsHours(member.number('contributionHours'))}',
              ),
              Text('Valves: ${statisticsHours(member.dutyHours)}'),
              Text('Väljakutseid: ${member.number('calloutCount')}'),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty) const Text('Sel aastal panuseid ei ole.'),
          for (final entry in entries.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry['title']?.toString() ?? 'Tegevus'),
              subtitle: Text(
                [
                  parseCalendarDate(
                            entry['date']?.toString().split('T').first ?? '',
                          ) ==
                          null
                      ? 'Kuupäev teadmata'
                      : calendarDateLabel(
                          parseCalendarDate(
                            entry['date']!.toString().split('T').first,
                          ),
                        ),
                  statisticsHours(entry['hours'] as num?),
                  entry['confirmed'] == true
                      ? 'Kinnitatud'
                      : 'Ootab kinnitamist',
                ].join(' · '),
              ),
            ),
          if (entries.length > 10)
            ExpansionTile(
              title: Text('Veel ${entries.length - 10} panust'),
              children: [
                for (final entry in entries.skip(10))
                  ListTile(
                    title: Text(entry['title']?.toString() ?? 'Tegevus'),
                    subtitle: Text(
                      '${entry['date'] ?? ''} · ${statisticsHours(entry['hours'] as num?)}',
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );

  Future<void> _editOwnProfile(String field) async {
    if (!_isOwnProfile) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OwnProfileEditor(
        field: field,
        name: _name,
        phone: _phone ?? '',
        save: (name, phone) async {
          await _userService.updateOwnBasicProfile(
            uid: widget.currentUid,
            name: name,
            phone: phone,
            field: field,
          );
          if (mounted) {
            setState(() {
              _name = name;
              _phone = _optionalString(phone);
            });
          }
        },
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Andmed salvestatud.')));
    }
  }

  Future<void> _saveMembershipStartDate(DateTime selected) async {
    if (!_canEditMembershipStartDate ||
        _targetUid.isEmpty ||
        _savingMembershipDate) {
      return;
    }
    setState(() => _savingMembershipDate = true);
    try {
      await _membershipService.updateMembershipStartDate(
        membershipId: widget.membershipId,
        targetUserId: _targetUid,
        organizationId: widget.organizationId,
        startedAt: selected,
      );
      if (!mounted) return;
      setState(() => _membershipStartedAt = membershipDateOnly(selected));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liitumise kuupäev salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Liitumise kuupäeva ei saanud salvestada.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingMembershipDate = false);
    }
  }

  Future<void> _editMemberPhone() async {
    if (!_canManageProfileMembership || _isOwnProfile || _targetUid.isEmpty) {
      return;
    }
    final phone = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PhoneEditorDialog(phone: _phone ?? ''),
    );
    if (phone == null) return;

    try {
      await _userService.updateMemberPhone(targetUid: _targetUid, phone: phone);
      if (!mounted) return;
      setState(() => _phone = _optionalString(phone));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefoninumber salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefoninumbrit ei saanud salvestada.')),
      );
    }
  }

  Future<String?> _showSeaRescueLevelDialog() {
    final selectedLevel = SeaRescueLevel.normalize(_seaRescueLevel);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Merepäästja aste'),
          children: [
            RadioGroup<String>(
              groupValue: selectedLevel,
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SeaRescueLevelOption(
                    level: SeaRescueLevel.none,
                    label: _seaRescueLevelLabel(SeaRescueLevel.none),
                  ),
                  _SeaRescueLevelOption(
                    level: SeaRescueLevel.level1,
                    label: _seaRescueLevelLabel(SeaRescueLevel.level1),
                  ),
                  _SeaRescueLevelOption(
                    level: SeaRescueLevel.level2,
                    label: _seaRescueLevelLabel(SeaRescueLevel.level2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeSeaRescueLevel() async {
    if (_targetUid.isEmpty) return;

    final level = await _showSeaRescueLevelDialog();
    if (level == null) return;

    try {
      await _membershipService.updateSeaRescueLevel(
        membershipId: widget.membershipId,
        targetUserId: _targetUid,
        organizationId: widget.organizationId,
        seaRescueLevel: level,
      );

      if (!mounted) return;
      setState(() => _seaRescueLevel = level);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merepäästja aste salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merepäästja astet ei saanud salvestada.'),
        ),
      );
    }
  }

  Future<String?> _showRoleDialog() {
    final selectedRole = MembershipRole.normalize(_membershipRole);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Muuda rolli'),
          children: [
            RadioGroup<String>(
              groupValue: selectedRole,
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoleOption(
                    role: MembershipRole.member,
                    label: _roleLabel(MembershipRole.member),
                  ),
                  _RoleOption(
                    role: MembershipRole.orgAdmin,
                    label: _roleLabel(MembershipRole.orgAdmin),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeRole() async {
    if (!_canEditRole || _targetUid.isEmpty) return;

    final role = await _showRoleDialog();
    if (role == null) return;

    try {
      await _membershipService.updateMembershipRole(
        membershipId: widget.membershipId,
        targetUserId: _targetUid,
        organizationId: widget.organizationId,
        role: role,
      );

      if (!mounted) return;
      setState(() => _membershipRole = role);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Roll salvestatud.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FirebaseFunctionsException
                ? error.message ?? 'Rolli ei saanud salvestada.'
                : 'Rolli ei saanud salvestada.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _stringValue(widget.userData['email'], '');
    final canSeeContact = _isOwnProfile || _canManageProfileMembership;
    final initial = _name.trim().isEmpty
        ? '?'
        : _name.trim().substring(0, 1).toUpperCase();
    return AppScaffold(
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'Minu profiil' : 'Liikme profiil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 26, child: Text(initial)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${_roleLabel(_membershipRole)} · ${_membershipStatusLabel(widget.membershipData)}',
                            ),
                            if (!_canManageProfileMembership)
                              Text(_seaRescueLevelLabel(_seaRescueLevel)),
                            if (canSeeContact && email.isNotEmpty)
                              SelectableText(email),
                            if (canSeeContact)
                              Text(_phone ?? 'Telefon lisamata'),
                          ],
                        ),
                      ),
                      if (_isOwnProfile)
                        IconButton(
                          tooltip: 'Muuda nime',
                          onPressed: () => _editOwnProfile('name'),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!_isOwnProfile) ...[
                        OutlinedButton.icon(
                          onPressed: () => _contact(false),
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('Helista'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _contact(true),
                          icon: const Icon(Icons.sms_outlined),
                          label: const Text('SMS'),
                        ),
                      ],
                      if (canSeeContact)
                        OutlinedButton.icon(
                          onPressed: _isOwnProfile
                              ? () => _editOwnProfile('phone')
                              : _editMemberPhone,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Muuda telefoni'),
                        ),
                      if (_canEditRole)
                        TextButton(
                          onPressed: _changeRole,
                          child: const Text('Muuda rolli'),
                        ),
                    ],
                  ),
                  if (_membershipStartedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Ühingus: ${membershipTenureLabel(_membershipStartedAt!)} · alates ${membershipDateLabel(_membershipStartedAt!)}',
                      ),
                    ),
                  if (_canViewTargetParticipation)
                    FutureBuilder<ContributionReport?>(
                      future: _statistics,
                      builder: (context, snapshot) {
                        final members =
                            snapshot.data?.members
                                .where((m) => m.userId == _targetUid)
                                .toList() ??
                            [];
                        if (members.isEmpty) return const SizedBox.shrink();
                        final member = members.first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              Text(
                                '${DateTime.now().year}: ${statisticsHours(member.number('contributionHours'))} panust',
                              ),
                              Text(
                                '${statisticsHours(member.dutyHours)} valves',
                              ),
                              Text(
                                '${member.number('calloutCount')} väljakutset',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_canEditMembershipStartDate)
            MemberProfileSection(
              title: 'Ühingusse liitumise kuupäev',
              icon: Icons.event_outlined,
              subtitle:
                  'Tegelik ühinguga liitumise kuupäev staaži arvestamiseks.',
              child: AppDateField(
                label: _savingMembershipDate
                    ? 'Salvestan kuupäeva…'
                    : 'Liitumise kuupäev',
                value: _membershipStartedAt,
                enabled: _canEditMembershipStartDate && !_savingMembershipDate,
                lastDate: DateTime.now(),
                onChanged: (date) {
                  if (date != null) _saveMembershipStartDate(date);
                },
              ),
            ),
          MemberProfileSection(
            title: 'Valvegraafik',
            icon: Icons.calendar_month_outlined,
            actions: [
              if (_isOwnProfile)
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AvailabilityScreen(
                        organizationId: widget.organizationId,
                        currentUid: widget.currentUid,
                        currentUserName: _name,
                        canViewOrganizationReadiness: true,
                        openPlanningOnStart: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Planeeri'),
                ),
            ],
            child: _buildAvailabilitySection(),
          ),
          if (_canManageProfileMembership)
            MemberProfileSection(
              title: 'Merepääste aste',
              icon: Icons.school_outlined,
              actions: [
                if (_canManageProfileMembership)
                  OutlinedButton.icon(
                    onPressed: _changeSeaRescueLevel,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Muuda'),
                  ),
              ],
              child: Text(_seaRescueLevelLabel(_seaRescueLevel)),
            ),
          MemberProfileSection(
            title: 'Isiklik ja väljastatud varustus',
            icon: Icons.inventory_2_outlined,
            actions: [
              if (_isOwnProfile)
                OutlinedButton.icon(
                  onPressed: () => _openEquipment(add: true),
                  icon: const Icon(Icons.add),
                  label: const Text('Lisa'),
                ),
              if (_canManageProfileMembership && !_isOwnProfile)
                TextButton(
                  onPressed: () => _openEquipment(),
                  child: const Text('Halda väljastamist'),
                ),
            ],
            child: _buildEquipmentSection(),
          ),
          if (_canViewTargetCertificates)
            MemberProfileSection(
              title: 'Tunnistused',
              icon: Icons.school_outlined,
              actions: [
                if (_certificateAccess.canAdd)
                  OutlinedButton.icon(
                    onPressed: () => _editCertificate(),
                    icon: const Icon(Icons.add),
                    label: const Text('Lisa tunnistus'),
                  ),
              ],
              child: _buildCertificatesSection(),
            ),
          if (_canViewTargetParticipation) ...[
            MemberProfileSection(
              title: 'Läbitud koolitused',
              icon: Icons.task_alt,
              actions: [_contributionButton(training: true)],
              child: _buildTrainingSection(),
            ),
            MemberProfileSection(
              title: 'Viimased panused',
              icon: Icons.volunteer_activism_outlined,
              subtitle: '${DateTime.now().year}. aasta · aktiivses ühingus',
              actions: [_contributionButton()],
              child: _buildContributionSection(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeaRescueLevelOption extends StatelessWidget {
  const _SeaRescueLevelOption({required this.level, required this.label});

  final String level;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(value: level, title: Text(label));
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.role, required this.label});

  final String role;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(value: role, title: Text(label));
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(label), subtitle: Text(value));
  }
}

class _PhoneEditorDialog extends StatefulWidget {
  const _PhoneEditorDialog({required this.phone});

  final String phone;

  @override
  State<_PhoneEditorDialog> createState() => _PhoneEditorDialogState();
}

class _PhoneEditorDialogState extends State<_PhoneEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _phone = TextEditingController(
    text: widget.phone,
  );

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Muuda telefoninumbrit'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefon',
            hintText: '+372 555 1234',
          ),
          validator: (value) =>
              value != null &&
                  value.trim().isNotEmpty &&
                  phoneContactUri(value, sms: false) == null
              ? 'Sisesta korrektne telefoninumber.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Katkesta'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, _phone.text.trim());
            }
          },
          child: const Text('Salvesta'),
        ),
      ],
    );
  }
}
