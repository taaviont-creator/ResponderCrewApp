import '../widgets/own_profile_editor.dart';
import '../services/member_contact_service.dart';
import 'equipment_screen.dart';
import 'certificates_screen.dart';
import 'activities_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/activity_model.dart';
import '../models/availability_model.dart';
import '../models/certificate_model.dart';
import '../models/equipment_model.dart';
import '../models/effective_availability.dart';
import '../models/membership_model.dart';
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

  @override
  void initState() {
    super.initState();
    _name = _stringValue(widget.userData['name'], 'Nimi puudub');
    _phone = _optionalString(widget.userData['phone']);
    _membershipRole = MembershipRole.normalize(widget.membershipData['role']);
    _seaRescueLevel = SeaRescueLevel.normalize(
      widget.membershipData['seaRescueLevel'],
    );
  }

  @override
  void didUpdateWidget(MemberProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _name = _stringValue(widget.userData['name'], 'Nimi puudub');
    _phone = _optionalString(widget.userData['phone']);
    _membershipRole = MembershipRole.normalize(widget.membershipData['role']);
    _seaRescueLevel = SeaRescueLevel.normalize(widget.membershipData['seaRescueLevel']);
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

  String get _targetUid => _stringValue(widget.membershipData['userId'], '');

  bool get _isOwnProfile =>
      _targetUid.isNotEmpty && _targetUid == widget.currentUid;

  bool get _canManageProfileMembership {
    if (!widget.canManageRoles) return false;
    if (widget.currentUid.trim().isEmpty) return false;
    if (_targetUid.isEmpty) return false;

    final membershipOrganizationId =
        _membershipService.organizationIdFromMembership(widget.membershipData);
    return membershipOrganizationId == widget.organizationId;
  }

  bool get _canEditRole => _canManageProfileMembership && !_isOwnProfile;

  Future<void> _contact(bool sms) async {
    try {
      final uri = await MemberContactService().contactUri(organizationId: widget.organizationId, userId: _targetUid, sms: sms);
      if (!mounted) return;
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) throw StateError('Contact unavailable');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kontakti ei saanud avada. Telefoninumber võib puududa.')));
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
        return 'Hilinen';
      case AvailabilityStatus.offDuty:
        return 'Ei ole valves';
      default:
        return 'Valmisolek märkimata';
    }
  }

  Widget _buildAvailabilitySection() {
    if (_targetUid.isEmpty || widget.organizationId.trim().isEmpty) {
      return const _ProfileRow(
        label: 'Valmisolek',
        value: 'Ei ole valves',
      );
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
      stream: _availabilityService.streamOrganizationAvailability(organizationId: widget.organizationId)
          .map((items) { for (final item in items) { if (item.userId == _targetUid) return item; } return null; }),
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
                  periods: periodsSnapshot.data ??
                      const <PlannedUnavailabilityModel>[],
                  rules: rulesSnapshot.data ??
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

                return _ProfileRow(
                  label: 'Valmisolek',
                  value: lines.join('\n'),
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

  String _equipmentCategoryLabel(String category) {
    switch (category) {
      case EquipmentCategory.vessel:
        return 'Alus';
      case EquipmentCategory.engine:
        return 'Mootor';
      case EquipmentCategory.rescue:
        return 'Päästevarustus';
      case EquipmentCategory.medical:
        return 'Meditsiin';
      case EquipmentCategory.radio:
        return 'Raadio';
      case EquipmentCategory.safety:
        return 'Ohutus';
      default:
        return 'Muu';
    }
  }

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

  Widget _buildEquipmentSection() {
    if (_targetUid.isEmpty ||
        widget.organizationId.trim().isEmpty ||
        widget.currentUid.trim().isEmpty) {
      return const _ProfileRow(
        label: 'Varustus',
        value: 'Varustust ei ole.',
      );
    }

    return StreamBuilder<List<EquipmentModel>>(
      stream: _equipmentService.streamVisibleEquipment(
        organizationId: widget.organizationId,
        currentUserId: widget.currentUid,
        canViewMemberPersonalEquipment: _canManageProfileMembership,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _ProfileRow(label: 'Varustus', value: 'Laadimine ebaõnnestus.');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final equipment = snapshot.data ?? const <EquipmentModel>[];
        final issuedEquipment = equipment
            .where(
              (item) =>
                  item.scope == EquipmentScope.organization &&
                  item.assignedToUserId == _targetUid,
            )
            .toList(growable: false);
        final personalEquipment = _canViewTargetPersonalEquipment
            ? equipment
                .where(
                  (item) =>
                      item.scope == EquipmentScope.personal &&
                      item.ownerUserId == _targetUid,
                )
                .toList(growable: false)
            : const <EquipmentModel>[];

        if (issuedEquipment.isEmpty && personalEquipment.isEmpty) {
          return const _ProfileRow(
            label: 'Varustus',
            value: 'Varustust ei ole.',
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Varustus',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (issuedEquipment.isNotEmpty)
                  _EquipmentGroup(
                    title: 'Väljastatud varustus',
                    equipment: issuedEquipment,
                    categoryLabel: _equipmentCategoryLabel,
                    statusLabel: _equipmentStatusLabel,
                    showIssuedLabel: true,
                  ),
                if (personalEquipment.isNotEmpty)
                  _EquipmentGroup(
                    title: 'Isiklik varustus',
                    equipment: personalEquipment,
                    categoryLabel: _equipmentCategoryLabel,
                    statusLabel: _equipmentStatusLabel,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _canViewTargetCertificates =>
      _isOwnProfile || _canManageProfileMembership;

  String _certificateTypeLabel(String type) {
    switch (type) {
      case CertificateType.firstAid:
        return 'Esmaabi';
      case CertificateType.seaRescue:
        return 'Merepääste';
      case CertificateType.radio:
        return 'Raadioside';
      case CertificateType.navigation:
        return 'Navigatsioon';
      case CertificateType.boatOperator:
        return 'Väikelaevajuht';
      case CertificateType.safety:
        return 'Ohutus';
      default:
        return 'Muu';
    }
  }

  String _certificateStatusLabel(String status) {
    switch (status) {
      case CertificateStatus.expiringSoon:
        return 'Aegumas';
      case CertificateStatus.expired:
        return 'Aegunud';
      case CertificateStatus.missing:
        return 'Puudub';
      default:
        return 'Kehtiv';
    }
  }

  String _certificateDisplayStatus(CertificateModel certificate) {
    final expiresAt = certificate.expiresAt.trim();
    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (expiresAt.isEmpty || parsedExpiry == null) {
      return certificate.status;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(
      parsedExpiry.year,
      parsedExpiry.month,
      parsedExpiry.day,
    );
    if (expiryDate.isBefore(today)) return CertificateStatus.expired;
    if (!expiryDate.isAfter(today.add(const Duration(days: 30)))) {
      return CertificateStatus.expiringSoon;
    }
    return certificate.status;
  }

  Widget _buildCertificatesSection() {
    if (!_canViewTargetCertificates) {
      return const SizedBox.shrink();
    }
    if (_targetUid.isEmpty || widget.organizationId.trim().isEmpty) {
      return const _ProfileRow(
        label: 'Tunnistused',
        value: 'Tunnistusi ei ole.',
      );
    }

    return StreamBuilder<List<CertificateModel>>(
      stream: _certificateService.streamMyCertificates(
        organizationId: widget.organizationId,
        userId: _targetUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _ProfileRow(label: 'Tunnistused', value: 'Laadimine ebaõnnestus.');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final certificates = snapshot.data ?? const <CertificateModel>[];
        if (certificates.isEmpty) {
          return const _ProfileRow(
            label: 'Tunnistused',
            value: 'Tunnistusi ei ole.',
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Tunnistused',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...certificates.map(
                  (certificate) => _CertificateTile(
                    certificate: certificate,
                    typeLabel: _certificateTypeLabel(certificate.type),
                    statusLabel: _certificateStatusLabel(
                      _certificateDisplayStatus(certificate),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _canViewTargetParticipation =>
      _isOwnProfile || _canManageProfileMembership;

  DateTime? _activityDate(ActivityModel activity) {
    final parsedStart = DateTime.tryParse(activity.startTime.trim());
    return parsedStart ?? activity.createdAt;
  }

  String _activityDateLabel(ActivityModel activity) {
    final startTime = activity.startTime.trim();
    if (startTime.isNotEmpty) return startTime;

    final createdAt = activity.createdAt;
    if (createdAt == null) return '';
    return [
      createdAt.year.toString().padLeft(4, '0'),
      createdAt.month.toString().padLeft(2, '0'),
      createdAt.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  String _hoursLabel(double hours) {
    if (hours == hours.roundToDouble()) {
      return hours.toStringAsFixed(0);
    }
    return hours.toStringAsFixed(1);
  }

  Widget _buildActivityContributionSection() {
    if (!_canViewTargetParticipation) {
      return const SizedBox.shrink();
    }
    if (_targetUid.isEmpty || widget.organizationId.trim().isEmpty) {
      return const _ProfileRow(
        label: 'Tegevused ja koolitused',
        value: 'Kinnitatud osalemisi ei ole.',
      );
    }

    return StreamBuilder<List<ActivityModel>>(
      stream: _activityService.streamOrganizationActivities(
        organizationId: widget.organizationId,
      ),
      builder: (context, activitiesSnapshot) {
        if (activitiesSnapshot.hasError) return const _ProfileRow(label: 'Tegevused', value: 'Laadimine ebaõnnestus.');
        if (!activitiesSnapshot.hasData) return const LinearProgressIndicator();
        final activities = activitiesSnapshot.data ?? const <ActivityModel>[];
        final activityById = {
          for (final activity in activities) activity.id: activity,
        };

        return StreamBuilder<List<ActivityParticipantModel>>(
          stream: _activityService.streamUserParticipations(
            organizationId: widget.organizationId,
            userId: _targetUid,
          ),
          builder: (context, participantsSnapshot) {
            if (participantsSnapshot.hasError) return const _ProfileRow(label: 'Osalemised', value: 'Laadimine ebaõnnestus.');
            if (!participantsSnapshot.hasData) return const LinearProgressIndicator();
            final confirmedParticipations = (participantsSnapshot.data ??
                    const <ActivityParticipantModel>[])
                .where(
                  (participant) =>
                      participant.attendanceStatus ==
                          ActivityAttendanceStatus.confirmed &&
                      activityById.containsKey(participant.activityId),
                )
                .toList();

            if (confirmedParticipations.isEmpty) {
              return const _ProfileRow(
                label: 'Tegevused ja koolitused',
                value: 'Kinnitatud osalemisi ei ole.',
              );
            }

            confirmedParticipations.sort((a, b) {
              final aDate = _activityDate(activityById[a.activityId]!);
              final bDate = _activityDate(activityById[b.activityId]!);
              if (aDate == null && bDate == null) {
                return a.activityId.compareTo(b.activityId);
              }
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

            final confirmedHours = confirmedParticipations.fold<double>(
              0,
              (sum, participant) => sum + (participant.hours ?? 0),
            );
            final latestParticipations =
                confirmedParticipations.take(3).toList(growable: false);

            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Tegevused ja koolitused',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        [
                          'Kinnitatud osalemisi: ${confirmedParticipations.length}',
                          'Kinnitatud tunnid: ${_hoursLabel(confirmedHours)}',
                        ].join('\n'),
                      ),
                    ),
                    ...latestParticipations.map(
                      (participant) => _ActivityContributionTile(
                        activity: activityById[participant.activityId]!,
                        participant: participant,
                        dateLabel: _activityDateLabel(
                          activityById[participant.activityId]!,
                        ),
                        hoursLabel: participant.hours == null
                            ? null
                            : _hoursLabel(participant.hours!),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editOwnProfile() async {
    if (!_isOwnProfile) return;
    final saved = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => OwnProfileEditor(name: _name, phone: _phone ?? '', save: (name, phone) async {
        await _userService.updateOwnBasicProfile(uid: widget.currentUid, name: name, phone: phone);
        if (mounted) setState(() { _name = name; _phone = _optionalString(phone); });
      }));
    if (saved == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Andmed salvestatud.')));
  }

  Future<String?> _showSeaRescueLevelDialog() {
    final selectedLevel = SeaRescueLevel.normalize(_seaRescueLevel);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Merepääste aste'),
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
        const SnackBar(content: Text('Merepääste aste salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merepääste astet ei saanud salvestada.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Roll salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rolli ei saanud salvestada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _stringValue(widget.userData['email'], 'E-post puudub');
    final role = _roleLabel(_membershipRole);
    final seaRescueLevel = _seaRescueLevelLabel(_seaRescueLevel);
    final status = _membershipStatusLabel(widget.membershipData);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'Minu profiil' : 'Liikme profiil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name, style: Theme.of(context).textTheme.headlineSmall),
              Text('$role · $seaRescueLevel'),
              const SizedBox(height: 12),
              if (_isOwnProfile) FilledButton.icon(onPressed: _editOwnProfile,
                icon: const Icon(Icons.edit_outlined), label: const Text('Muuda minu andmeid'))
              else Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: () => _contact(false), icon: const Icon(Icons.phone_outlined), label: const Text('Helista')),
                OutlinedButton.icon(onPressed: () => _contact(true), icon: const Icon(Icons.sms_outlined), label: const Text('SMS')),
              ]),
            ]))),
          if (_isOwnProfile || _canManageProfileMembership) Card(child: Column(children: [
            _ProfileRow(label: 'E-post', value: email),
            _ProfileRow(label: 'Telefon', value: _phone ?? 'Telefoni pole lisatud.'),
          ])),
          _ProfileRow(label: 'Liikmesus', value: status),
          _buildAvailabilitySection(),
          if (_canManageProfileMembership) ...[
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('Halda liiget'),
                  ),
                  ListTile(
                    title: const Text('Muuda merepääste astet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changeSeaRescueLevel,
                  ),
                  if (_canEditRole)
                    ListTile(
                      title: const Text('Muuda rolli'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changeRole,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _profileSection('Varustus', _buildEquipmentSection(), onOpen: _isOwnProfile ? () => Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => EquipmentScreen(organizationId: widget.organizationId,
              currentUid: widget.currentUid, canManageEquipment: widget.canManageRoles))) : null),
          if (_canViewTargetCertificates) _profileSection('Tunnistused', _buildCertificatesSection(),
            onOpen: _isOwnProfile ? () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CertificatesScreen(
              organizationId: widget.organizationId, currentUid: widget.currentUid, canManageCertificates: widget.canManageRoles))) : null),
          if (_canViewTargetParticipation) _profileSection('Tegevused ja koolitused', _buildActivityContributionSection(),
            onOpen: _isOwnProfile ? () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ActivitiesScreen(
              organizationId: widget.organizationId, currentUid: widget.currentUid, canManageActivities: widget.canManageRoles))) : null),
        ],
      ),
    );
  }
  Widget _profileSection(String title, Widget child, {VoidCallback? onOpen}) => Card(child: ExpansionTile(
    title: Text(title), children: [if (onOpen != null) Align(alignment: Alignment.centerRight,
      child: TextButton(onPressed: onOpen, child: const Text('Ava'))), child]));
}

class _SeaRescueLevelOption extends StatelessWidget {
  const _SeaRescueLevelOption({
    required this.level,
    required this.label,
  });

  final String level;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: level,
      title: Text(label),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.label,
  });

  final String role;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: role,
      title: Text(label),
    );
  }
}

class _EquipmentGroup extends StatelessWidget {
  const _EquipmentGroup({
    required this.title,
    required this.equipment,
    required this.categoryLabel,
    required this.statusLabel,
    this.showIssuedLabel = false,
  });

  final String title;
  final List<EquipmentModel> equipment;
  final String Function(String category) categoryLabel;
  final String Function(String status) statusLabel;
  final bool showIssuedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        ...equipment.map(
          (item) => ListTile(
            dense: true,
            title: Text(item.name.isEmpty ? 'Varustus' : item.name),
            subtitle: Text(
              [
                'Kategooria: ${categoryLabel(item.category)}',
                'Staatus: ${statusLabel(item.status)}',
                if (showIssuedLabel) 'Väljastatud liikmele',
              ].join('\n'),
            ),
          ),
        ),
      ],
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({
    required this.certificate,
    required this.typeLabel,
    required this.statusLabel,
  });

  final CertificateModel certificate;
  final String typeLabel;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final title = certificate.title.trim().isEmpty
        ? typeLabel
        : certificate.title.trim();
    final expiresAt = certificate.expiresAt.trim();

    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(
        [
          if (certificate.title.trim().isNotEmpty) typeLabel,
          if (expiresAt.isNotEmpty) 'Kehtib kuni: $expiresAt',
          'Staatus: $statusLabel',
        ].join('\n'),
      ),
    );
  }
}

class _ActivityContributionTile extends StatelessWidget {
  const _ActivityContributionTile({
    required this.activity,
    required this.participant,
    required this.dateLabel,
    required this.hoursLabel,
  });

  final ActivityModel activity;
  final ActivityParticipantModel participant;
  final String dateLabel;
  final String? hoursLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(activity.title.trim().isEmpty
          ? 'Tegevused ja koolitused'
          : activity.title.trim()),
      subtitle: Text(
        [
          if (dateLabel.isNotEmpty) 'Kuupäev: $dateLabel',
          if (participant.hours != null && hoursLabel != null)
            'Tunnid: $hoursLabel',
        ].join('\n'),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
