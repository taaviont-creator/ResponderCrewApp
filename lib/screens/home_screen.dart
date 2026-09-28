import '../widgets/home_absence_preview.dart';
import '../widgets/minimum_crew_dialog.dart';
import '../widgets/member_permission_settings.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/availability_model.dart';
import '../models/effective_availability.dart';
import '../models/membership_model.dart';
import '../models/member_request_notification.dart';
import '../models/platform_readiness_model.dart';
import '../models/response_readiness.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/availability_service.dart';
import '../services/callout_alarm_notification_service.dart';
import '../services/command_service.dart';
import '../services/membership_service.dart';
import '../services/notification_service.dart';
import '../services/platform_readiness_service.dart';
import '../services/planned_unavailability_service.dart';
import '../widgets/pending_invites_section.dart';
import '../widgets/home_header.dart';
import 'activities_screen.dart';
import 'admin_home_dashboard.dart';
import 'availability_screen.dart';
import 'callouts_screen.dart';
import 'organization_permits_screen.dart';
import 'certificates_screen.dart';
import '../models/certificate_reminder_open.dart';
import 'equipment_screen.dart';
import 'main_navigation_shell.dart';
import 'members_screen.dart';
import 'member_home_dashboard.dart';
import 'menu_screen.dart';
import 'notifications_screen.dart';
import 'operation_log_screen.dart';
import 'platform_pending_organizations_screen.dart';
import 'platform_readiness_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomePermissions {
  const _HomePermissions({
    required this.isPlatformAdmin,
    required this.isOrganizationAdmin,
    required this.allowMembersToCreateActivities,
    required this.allowMembersToViewStatistics,
    required this.allowMembersToStartOperationLog,
  });

  final bool isPlatformAdmin;
  final bool isOrganizationAdmin;
  final bool allowMembersToCreateActivities;
  final bool allowMembersToViewStatistics;
  final bool allowMembersToStartOperationLog;

  bool get canManageOrganization => isOrganizationAdmin;
  bool get canManageMembers => canManageOrganization;
  bool get canManageOrganizationEquipment =>
      isPlatformAdmin || isOrganizationAdmin;
  bool get canManageOrganizationSettings =>
      isPlatformAdmin || isOrganizationAdmin;
  bool get canCreateCallout => canManageOrganization;
  bool get canManageCertificates => canManageOrganization;
  bool get canViewOrganizationReadiness =>
      isPlatformAdmin || isOrganizationAdmin;
  bool get canManageNotifications => canManageOrganization;
  bool get canCreateActivity =>
      canManageOrganization || allowMembersToCreateActivities;
  bool get canViewStatistics =>
      canManageOrganization || allowMembersToViewStatistics;
  bool get canStartOperationLog =>
      canManageOrganization || allowMembersToStartOperationLog;
  bool get canCloseCallout => isPlatformAdmin || isOrganizationAdmin;
}

class _HomeScreenState extends State<HomeScreen> {
  var _contentNavigatorKey = GlobalKey<NavigatorState>();
  String? _navigatorOrganizationId;
  (String, Widget)? _pendingNotificationPage;

  Future<T?> _pushPage<T>(BuildContext context, Route<T> route) =>
      (_contentNavigatorKey.currentState ?? Navigator.of(context)).push(route);

  final _availabilityService = AvailabilityService();
  final _commandService = CommandService();
  final _membershipService = MembershipService();
  final _notificationService = NotificationService();
  final _platformReadinessService = PlatformReadinessService();
  final _plannedUnavailabilityService = PlannedUnavailabilityService();
  StreamSubscription<CalloutNotificationOpenEvent>? _calloutOpenSubscription;
  StreamSubscription<MemberRequestNotification>? _memberRequestSubscription;
  StreamSubscription<CertificateReminderOpen>? _certificateSubscription;
  String? _pendingCalloutId;
  var _selectedNavigationIndex = 0;
  bool _savingAvailability = false;

  @override
  void initState() {
    super.initState();

    final notificationService = CalloutAlarmNotificationService.instance;
    _certificateSubscription = notificationService.certificateOpenEvents.listen((event) => unawaited(_handleCertificateOpen(event)));
    _memberRequestSubscription = notificationService.memberRequestOpenEvents.listen((event) {
      unawaited(_handleMemberRequestOpen(event));
    });
    _calloutOpenSubscription =
        notificationService.calloutOpenEvents.listen((event) {
      unawaited(_handleCalloutNotificationOpen(event));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final certificate = notificationService.takePendingCertificate();
      if (certificate != null) unawaited(_handleCertificateOpen(certificate));
      final memberRequest = notificationService.takePendingMemberRequest();
      if (memberRequest != null) unawaited(_handleMemberRequestOpen(memberRequest));
      final pendingEvent =
          notificationService.takePendingCalloutOpenEvent();
      if (pendingEvent != null) {
        unawaited(_handleCalloutNotificationOpen(pendingEvent));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_certificateSubscription?.cancel());
    unawaited(_memberRequestSubscription?.cancel());
    final subscription = _calloutOpenSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> _handleCalloutNotificationOpen(
    CalloutNotificationOpenEvent event,
  ) async {
    if (!mounted) return;

    try {
      await _setActiveCommand(event.organizationId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selle väljakutse ühing ei ole enam aktiivne.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    _contentNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      _pendingCalloutId = event.calloutId;
      _pendingNotificationPage = null;
      _selectedNavigationIndex = 1;
    });
  }

  Future<void> _handleCertificateOpen(CertificateReminderOpen event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('memberships').doc(
        _membershipService.membershipId(userId: user.uid, organizationId: event.organizationId)).get();
      final membership = snapshot.data() ?? {};
      final admin = _membershipService.isOrgAdmin(membership);
      if (!_membershipService.isActiveMembership(membership) || (user.uid != event.memberUserId && !admin)) throw StateError('Access denied');
      await _setActiveCommand(event.organizationId);
      if (!mounted) return;
      setState(() {
        _selectedNavigationIndex = 4;
        _pendingNotificationPage = (event.organizationId, CertificatesScreen(
          organizationId: event.organizationId, currentUid: user.uid,
          targetUserId: event.memberUserId, canManageCertificates: admin));
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selle liikme tunnistusi ei saa praegu avada.')));
    }
  }

  Future<void> _handleMemberRequestOpen(MemberRequestNotification event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    try {
      final membership = await FirebaseFirestore.instance.collection('memberships')
          .doc(_membershipService.membershipId(userId: user.uid,
            organizationId: event.organizationId)).get();
      if (!_membershipService.isOrgAdmin(membership.data() ?? {}) ||
          _membershipService.organizationIdFromMembership(membership.data() ?? {}) != event.organizationId) {
        throw StateError('Not an organization admin');
      }
      await _setActiveCommand(event.organizationId);
      if (!mounted) return;
      setState(() {
        _selectedNavigationIndex = 4;
        _pendingNotificationPage = (event.organizationId, MembersScreen(
          organizationId: event.organizationId, currentUid: user.uid, canManageRoles: true));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selle ühingu liitumistaotlusi ei saa praegu avada.'),
      ));
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _setActiveCommand(String commandId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final organizationId = commandId.trim();
    if (organizationId.isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne ühing');
    }

    final membershipSnapshot = await FirebaseFirestore.instance
        .collection('memberships')
        .doc(_membershipService.membershipId(
          userId: user.uid,
          organizationId: organizationId,
        ))
        .get();
    final membership = membershipSnapshot.data();
    if (membership == null ||
        !_membershipService.isActiveMembership(membership) ||
        _membershipService.organizationIdFromMembership(membership) !=
            organizationId) {
      throw Exception('Sul puudub selle ühingu aktiivne liikmelisus');
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'activeOrganizationId': organizationId,
      'activeCommandId': organizationId,
      'commandId': organizationId,
    }, SetOptions(merge: true));
  }

  Future<void> _copyJoinCode(String joinCode) async {
    await Clipboard.setData(ClipboardData(text: joinCode));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liitumiskood kopeeritud')),
    );
  }

  Future<void> _showJoinCommandDialog() async {
    final codeController = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liitu ühinguga'),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Liitumiskood',
            hintText: 'nt AB12CD',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Katkesta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, codeController.text),
            child: const Text('Liitu'),
          ),
        ],
      ),
    );

    if (code == null || code.trim().isEmpty) return;

    try {
      final result = await _commandService.joinCommand(joinCode: code.trim());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == JoinCommandResult.alreadyMember
                ? 'Oled juba selle ühingu liige.'
                : 'Liitumistaotlus saadetud. Oota ühingu administraatori kinnitust.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is JoinCommandException
          ? error.message
          : error is FirebaseException &&
                  (error.code == 'unavailable' ||
                      error.code == 'deadline-exceeded')
              ? 'Ühendus puudub. Kontrolli internetti ja proovi uuesti.'
              : 'Liitumistaotlust ei saanud saata. Proovi uuesti või võta ühendust ühingu administraatoriga.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _showCreateCommandDialog() async {
    final nameController = TextEditingController();

    final commandName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uus ühing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uus ühing saadetakse platvormi haldurile kinnitamiseks. '
              'Ühingut saab kasutada pärast kinnitamist.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ühingu nimi',
                hintText: 'nt Purtse',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Katkesta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Loo'),
          ),
        ],
      ),
    );

    if (commandName == null || commandName.trim().isEmpty) return;

    try {
      await _commandService.createCommand(name: commandName.trim());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ühing loodud ja saadetud kinnitamisele.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ühingu loomine ebaõnnestus.')),
      );
    }
  }

  Future<void> _showSwitchOrganizationDialog({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
    required String? currentActiveCommandId,
  }) async {
    final items = <Map<String, String>>[];

    for (final membershipDoc in membershipDocs) {
      final membership = membershipDoc.data();
      // TODO: Move organization switching into a dedicated screen.
      final commandId =
          _membershipService.organizationIdFromMembership(membership) ?? '';
      if (commandId.isEmpty) continue;

      try {
        final commandSnap = await FirebaseFirestore.instance
            .collection('commands')
            .doc(commandId)
            .get();

        final commandData = commandSnap.data();
        final commandName = (commandData?['name'] ?? commandId) as String;

        items.add({
          'commandId': commandId,
          'commandName': commandName,
          'available': _membershipService.isActiveMembership(membership) && commandData?['status'] == 'approved' ? 'yes' : 'no',
          'status': commandData?['status'] == 'pending' ? 'Ühing ootab platvormi halduri kinnitust' : 'Liikmesus ootab kinnitust',
        });
      } catch (_) {
        items.add({
          'commandId': commandId,
          'commandName': commandId,
          'available': 'no',
          'status': 'Ühingu andmete laadimine ebaõnnestus',
        });
      }
    }

    if (!mounted) return;

    final selectedCommandId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vali aktiivne ühing'),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? const Text('Ühtegi ühingut ei leitud')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final commandId = item['commandId']!;
                    final commandName = item['commandName']!;
                    final isSelected = commandId == currentActiveCommandId;

                    return ListTile(
                      title: Text(commandName),
                      subtitle: item['available'] == 'yes' ? null : Text(item['status']!),
                      trailing:
                          isSelected ? const Icon(Icons.check_circle) : null,
                      onTap: item['available'] == 'yes' ? () => Navigator.pop(context, commandId) : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sulge'),
          ),
        ],
      ),
    );

    if (selectedCommandId == null || selectedCommandId.isEmpty) return;

    try {
      await _setActiveCommand(selectedCommandId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktiivne ühing muudetud')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktiivse ühingu vahetamine ebaõnnestus.'),
        ),
      );
    }
  }

  Future<void> _showLeaveOrganizationDialog({
    required String commandId,
    required String? commandName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lahku ühingust'),
        content: Text(
          'Kas soovid lahkuda ühingust '
          '"${commandName ?? commandId}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Katkesta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lahku'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _commandService.leaveCommand(commandId: commandId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lahkusid ühingust')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ühingust lahkumine ebaõnnestus.')),
      );
    }
  }

  List<Widget> _buildAppBarActions({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
    required String? currentActiveCommandId,
    required String? currentCommandName,
  }) {
    final organizationCount =
        _organizationIdsFromMembershipDocs(membershipDocs).length;
    final canSelectOrganization = organizationCount > 0 &&
        (organizationCount > 1 ||
            currentActiveCommandId == null ||
            currentActiveCommandId.isEmpty);

    return [
      PopupMenuButton<String>(
        tooltip: 'Toimingud',
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'switch':
              _showSwitchOrganizationDialog(
                membershipDocs: membershipDocs,
                currentActiveCommandId: currentActiveCommandId,
              );
              break;
            case 'join':
              _showJoinCommandDialog();
              break;
            case 'create':
              _showCreateCommandDialog();
              break;
            case 'leave':
              if (currentActiveCommandId == null ||
                  currentActiveCommandId.isEmpty) {
                return;
              }
              _showLeaveOrganizationDialog(
                commandId: currentActiveCommandId,
                commandName: currentCommandName,
              );
              break;
            case 'signOut':
              _signOut();
              break;
          }
        },
        itemBuilder: (context) => [
          if (canSelectOrganization)
            const PopupMenuItem(
              value: 'switch',
              child: Text('Vaheta ühingut'),
            ),
          const PopupMenuItem(
            value: 'join',
            child: Text('Liitu koodiga'),
          ),
          const PopupMenuItem(
            value: 'create',
            child: Text('Loo ühing'),
          ),
          if (currentActiveCommandId != null &&
              currentActiveCommandId.isNotEmpty)
            const PopupMenuItem(
              value: 'leave',
              child: Text('Lahku ühingust'),
            ),
          const PopupMenuItem(
            value: 'signOut',
            child: Text('Logi välja'),
          ),
        ],
      ),
    ];
  }

  Set<String> _organizationIdsFromMembershipDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  ) {
    final organizationIds = <String>{};

    for (final membershipDoc in membershipDocs) {
      final organizationId =
          _membershipService.organizationIdFromMembership(membershipDoc.data());
      if (organizationId != null && organizationId.isNotEmpty) {
        organizationIds.add(organizationId);
      }
    }

    return organizationIds;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeMembershipDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  ) {
    return membershipDocs.where((membershipDoc) {
      final membership = membershipDoc.data();
      return _membershipService.isActiveMembership(membership) &&
          _membershipService.organizationIdFromMembership(membership) != null;
    }).toList(growable: false);
  }

  bool _hasPendingMembership(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  ) {
    return membershipDocs.any((membershipDoc) {
      final status =
          (membershipDoc.data()['status'] ?? '').toString().toLowerCase();
      return status == 'pending' ||
          status == 'awaitingapproval' ||
          status == 'waitingapproval';
    });
  }

  bool _hasDisabledMembership(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  ) {
    return membershipDocs.any((membershipDoc) {
      final membership = membershipDoc.data();
      final status = (membership['status'] ?? '').toString().toLowerCase();
      return membership['isActive'] == false ||
          status == 'disabled' ||
          status == 'inactive' ||
          status == 'removed' ||
          status == 'rejected';
    });
  }

  Widget _buildCompactOperationalHeader({
    required String displayName,
    required String? commandId,
    required String? commandName,
    required bool isPlatformAdmin,
    required String? membershipRole,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
    Widget? availabilityControl,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      HomeGreeting(displayName: displayName,
        role: MembershipRole.isOrgAdmin(membershipRole) ? 'Ühingu admin' : 'Liige'),
      if (availabilityControl != null) ...[
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: availabilityControl)),
      ],
    ]);
  }

  Widget _buildMissingOrganizationState({
    required bool hasMemberships,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
    String? title,
    String? message,
  }) {
    final effectiveTitle = title ?? 'Aktiivne ühing puudub.';
    final effectiveMessage = message ??
        (hasMemberships
            ? 'Vali aktiivne ühing, et mooduleid kasutada.'
            : 'Vali või liitu ühinguga, et mooduleid kasutada.');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            effectiveTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(effectiveMessage),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasMemberships)
                ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Vali ühing'),
                  onPressed: () => _showSwitchOrganizationDialog(
                    membershipDocs: membershipDocs,
                    currentActiveCommandId: null,
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text('Loo uus ühing'),
                onPressed: _showCreateCommandDialog,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key),
                label: const Text('Liitu ühinguga'),
                onPressed: _showJoinCommandDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedOrganizationState({
    required String status,
    required String? organizationName,
    required bool isPlatformAdmin,
  }) {
    final isRejected = status == 'rejected';
    final title = isRejected
        ? 'Ühingu taotlus on tagasi lükatud.'
        : 'Ühing ootab kinnitamist.';
    final message = isRejected
        ? 'Vali teine ühing või loo uus taotlus.'
        : 'Ühing ootab platvormi halduri kinnitust. '
            'Pärast kinnitamist saad rakendust kasutada.';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (organizationName != null && organizationName.trim().isNotEmpty) ...[
            Text(
              organizationName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.group_add),
            label: const Text('Loo uus ühing'),
            onPressed: _showCreateCommandDialog,
          ),
          if (isPlatformAdmin) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.apartment_outlined),
              label: const Text('Ootel ühingud'),
              onPressed: () {
                _pushPage(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlatformPendingOrganizationsScreen(
                      isPlatformAdmin: true,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSection({
    required User user,
    required String displayName,
    required String? commandId,
    required String? commandName,
    required String? joinCode,
    required bool canSeeJoinCode,
    required bool isPlatformAdmin,
    required String? membershipRole,
    required bool allowMembersToCreateActivities,
    required bool allowMembersToViewStatistics,
    required bool allowMembersToStartOperationLog,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  }) {
    final isOrganizationAdmin = MembershipRole.isOrgAdmin(membershipRole);
    final permissions = _HomePermissions(
      isPlatformAdmin: isPlatformAdmin,
      isOrganizationAdmin: isOrganizationAdmin,
      allowMembersToCreateActivities: allowMembersToCreateActivities,
      allowMembersToViewStatistics: allowMembersToViewStatistics,
      allowMembersToStartOperationLog: allowMembersToStartOperationLog,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactOperationalHeader(
            displayName: displayName,
            commandId: commandId,
            commandName: commandName,
            isPlatformAdmin: isPlatformAdmin,
            membershipRole: membershipRole,
            membershipDocs: membershipDocs,
          ),
          if (commandId != null && commandId.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAvailabilityControl(
              user: user,
              organizationId: commandId,
              memberName: displayName,
            ),
            if (permissions.canManageOrganization) ...[
              const SizedBox(height: 16),
              _buildReadinessSummary(organizationId: commandId),
            ],
          ],
          if (canSeeJoinCode && joinCode != null && joinCode.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Liitumiskood'),
                          const SizedBox(height: 4),
                          Text(
                            joinCode,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyJoinCode(joinCode),
                      icon: const Icon(Icons.copy),
                      tooltip: 'Kopeeri kood',
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (permissions.canManageOrganizationSettings &&
              commandId != null &&
              commandId.isNotEmpty) ...[
            if (permissions.canManageOrganization) ...[
              const SizedBox(height: 12),
              _buildMinimumCrewSettingsCard(
                organizationId: commandId,
                organizationName: commandName,
                currentUid: user.uid,
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Liikmete õigused',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Määra, mida tavaliikmed saavad selles ühingus teha.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Liikmed võivad lisada tegevusi/koolitusi',
                    ),
                    value: allowMembersToCreateActivities,
                    onChanged: (value) => _updateMemberPermissions(
                      organizationId: commandId,
                      allowMembersToCreateActivities: value,
                      allowMembersToViewStatistics:
                          allowMembersToViewStatistics,
                      allowMembersToStartOperationLog:
                          allowMembersToStartOperationLog,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Liikmed võivad näha statistikat',
                    ),
                    value: allowMembersToViewStatistics,
                    onChanged: (value) => _updateMemberPermissions(
                      organizationId: commandId,
                      allowMembersToCreateActivities:
                          allowMembersToCreateActivities,
                      allowMembersToViewStatistics: value,
                      allowMembersToStartOperationLog:
                          allowMembersToStartOperationLog,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Liikmed võivad alustada operatsioonilogi',
                    ),
                    value: allowMembersToStartOperationLog,
                    onChanged: (value) => _updateMemberPermissions(
                      organizationId: commandId,
                      allowMembersToCreateActivities:
                          allowMembersToCreateActivities,
                      allowMembersToViewStatistics:
                          allowMembersToViewStatistics,
                      allowMembersToStartOperationLog: value,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPlatformAdmin ||
              (permissions.canViewOrganizationReadiness &&
                  commandId != null &&
                  commandId.isNotEmpty)) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.health_and_safety),
              label: const Text('Valmisoleku seaded'),
              onPressed: () {
                _pushPage(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlatformReadinessScreen(
                      currentUid: user.uid,
                      activeOrganizationId: commandId,
                      activeOrganizationName: commandName,
                      canManageOwnSummary: permissions.canManageOrganization,
                      isPlatformAdmin: isPlatformAdmin,
                    ),
                  ),
                );
              },
            ),
          ],
          if (isPlatformAdmin) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.apartment_outlined),
              label: const Text('Ootel ühingud'),
              onPressed: () {
                _pushPage(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlatformPendingOrganizationsScreen(
                      isPlatformAdmin: true,
                    ),
                  ),
                );
              },
            ),
          ],
          if (commandId != null && commandId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Moodulid',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (permissions.canManageMembers)
                  _buildModuleButton(
                    icon: Icons.group,
                    label: 'Liikmed',
                    onPressed: () => _pushPage(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MembersScreen(
                          organizationId: commandId,
                          currentUid: user.uid,
                          canManageRoles: permissions.canManageMembers,
                        ),
                      ),
                    ),
                  ),
                _buildModuleButton(
                  icon: Icons.campaign,
                  label: 'Väljakutsed',
                  onPressed: () => _pushPage(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalloutsScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        currentUserName: displayName,
                        canManageCallouts: permissions.canCreateCallout,
                        canCloseCallouts: permissions.canCloseCallout,
                        canStartOperationLog:
                            permissions.canStartOperationLog,
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.check_circle,
                  label: 'Valmisolek',
                  onPressed: () => _pushPage(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvailabilityScreen(
                        organizationId: commandId,
                        organizationName: commandName,
                        membershipRole: membershipRole,
                        currentUid: user.uid,
                        currentUserName: displayName,
                        canViewOrganizationReadiness:
                            permissions.canViewOrganizationReadiness,
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.inventory_2,
                  label: permissions.canManageOrganizationEquipment
                      ? 'Varustus'
                      : 'Minu varustus',
                  onPressed: () => _pushPage(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EquipmentScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        canManageEquipment:
                            permissions.canManageOrganizationEquipment,
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.assignment,
                  label: 'Operatsioonilogi',
                  onPressed: () => _pushPage(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OperationLogScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        currentUserName: displayName,
                        canViewCalloutResponseSummary:
                            permissions.canManageOrganization,
                        canStartOperationLog:
                            permissions.canStartOperationLog,
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.event,
                  label: 'Tegevused ja koolitused',
                  onPressed: () => _pushPage(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivitiesScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        canManageActivities: permissions.canCreateActivity,
                      ),
                    ),
                  ),
                ),
                if (permissions.canViewStatistics)
                  _buildModuleButton(
                    icon: Icons.insights,
                    label: 'Statistika',
                    onPressed: () {
                      _pushPage(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StatisticsScreen(
                            organizationId: commandId,
                            currentUid: user.uid,
                            canViewStatistics: true,
                            canViewOrganizationCertificates:
                                permissions.canManageOrganization,
                          ),
                        ),
                      );
                    },
                  ),
                StreamBuilder<int>(
                  stream: _notificationService.streamUnreadNotificationCount(
                    userId: user.uid,
                    organizationId: commandId,
                  ),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return _buildModuleButton(
                      icon: Icons.notifications,
                      label: unreadCount > 0
                          ? 'Teavitused ($unreadCount)'
                          : 'Teavitused',
                      onPressed: () => _pushPage(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                            organizationId: commandId,
                            currentUid: user.uid,
                            currentUserName: displayName,
                            canManageNotifications:
                                permissions.canManageNotifications,
                            canCreateActivities:
                                permissions.canCreateActivity,
                            canStartOperationLog:
                                permissions.canStartOperationLog,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrganizationSettingsContent({
    required User user,
    required String? commandId,
    required String? commandName,
    required String? joinCode,
    required bool canSeeJoinCode,
    required bool isPlatformAdmin,
    required String? membershipRole,
    required bool allowMembersToCreateActivities,
    required bool allowMembersToViewStatistics,
    required bool allowMembersToStartOperationLog,
  }) {
    final isOrganizationAdmin = MembershipRole.isOrgAdmin(membershipRole);
    final permissions = _HomePermissions(
      isPlatformAdmin: isPlatformAdmin,
      isOrganizationAdmin: isOrganizationAdmin,
      allowMembersToCreateActivities: allowMembersToCreateActivities,
      allowMembersToViewStatistics: allowMembersToViewStatistics,
      allowMembersToStartOperationLog: allowMembersToStartOperationLog,
    );
    final organizationId = commandId?.trim() ?? '';
    final hasOrganization = organizationId.isNotEmpty;
    final visibleJoinCode = canSeeJoinCode ? joinCode?.trim() ?? '' : '';
    final hasJoinCode = visibleJoinCode.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ühing',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(
                  commandName?.trim().isNotEmpty == true
                      ? commandName!.trim()
                      : 'Nimi puudub',
                ),
              ),
              if (hasJoinCode) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Liitumiskood'),
                  subtitle: Text(visibleJoinCode),
                  trailing: IconButton(
                    onPressed: () => _copyJoinCode(visibleJoinCode),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Kopeeri kood',
                  ),
                ),
              ],
            ],
          ),
        ),
        if (permissions.canManageOrganizationSettings && hasOrganization) ...[
          Card(child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Ühingu load ja tunnistused'),
            subtitle: const Text('Raadioside- ja muud ühingule väljastatud load'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pushPage(context, MaterialPageRoute<void>(builder: (_) => OrganizationPermitsScreen(
              organizationId: organizationId, currentUid: user.uid))),
          )),
          if (permissions.canManageOrganization) ...[
            const SizedBox(height: 16),
            Text(
              'Valmisoleku seaded',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildMinimumCrewSettingsCard(
              organizationId: organizationId,
              organizationName: commandName,
              currentUid: user.uid,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Liikmete õigused',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildMemberPermissionSettingsCard(
            organizationId: organizationId,
            allowMembersToCreateActivities: allowMembersToCreateActivities,
            allowMembersToViewStatistics: allowMembersToViewStatistics,
            allowMembersToStartOperationLog:
                allowMembersToStartOperationLog,
          ),
        ],
      ],
    );
  }

  Widget _buildMemberPermissionSettingsCard({
    required String organizationId,
    required bool allowMembersToCreateActivities,
    required bool allowMembersToViewStatistics,
    required bool allowMembersToStartOperationLog,
  }) {
    return MemberPermissionSettings(
      key: ValueKey(organizationId),
      settings: FirebaseFirestore.instance.collection('commands').doc(organizationId)
          .snapshots().map((snapshot) => snapshot.data() ?? <String, dynamic>{}),
      save: (field, value) => _commandService.updateMemberPermission(
        organizationId: organizationId, field: field, value: value),
    );
  }

  Future<void> _updateMemberPermissions({
    required String organizationId,
    required bool allowMembersToCreateActivities,
    required bool allowMembersToViewStatistics,
    required bool allowMembersToStartOperationLog,
  }) async {
    try {
      await _commandService.updateMemberPermissions(
        organizationId: organizationId,
        allowMembersToCreateActivities: allowMembersToCreateActivities,
        allowMembersToViewStatistics: allowMembersToViewStatistics,
        allowMembersToStartOperationLog: allowMembersToStartOperationLog,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seadete muutmine ebaõnnestus.')),
      );
    }
  }

  Widget _buildMinimumCrewSettingsCard({
    required String organizationId,
    required String? organizationName,
    required String currentUid,
  }) {
    return StreamBuilder<List<PlatformReadinessSummary>>(
      stream: _platformReadinessService.streamOrganizationSummary(
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        final summaries =
            snapshot.data ?? const <PlatformReadinessSummary>[];
        final summary = summaries.isEmpty ? null : summaries.first;
        final minimumCrewRequired = summary?.minimumCrewRequired ?? 0;

        return Card(
          child: ListTile(
            title: const Text('Miinimumkoosseis'),
            subtitle: Text(
              'Miinimum valves liikmete arv: $minimumCrewRequired',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _showMinimumCrewDialog(
              organizationId: organizationId,
              organizationName: organizationName,
              currentUid: currentUid,
              minimumCrewRequired: minimumCrewRequired,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMinimumCrewDialog({
    required String organizationId,
    required String? organizationName,
    required String currentUid,
    required int minimumCrewRequired,
  }) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => MinimumCrewDialog(initialValue: minimumCrewRequired),
    );

    if (value == null) return;

    try {
      await _platformReadinessService.saveMinimumCrewRequired(
        organizationId: organizationId,
        organizationName: organizationName ?? organizationId,
        minimumCrewRequired: value,
        lastUpdatedBy: currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miinimumkoosseis salvestatud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seadete muutmine ebaõnnestus.')),
      );
    }
  }

  Widget _buildReadinessSummary({
    required String organizationId,
  }) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _membershipService.streamActiveMembershipsForOrganization(
        organizationId,
      ),
      builder: (context, membershipsSnapshot) {
        final activeMemberships = membershipsSnapshot.data ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return StreamBuilder<List<AvailabilityModel>>(
          stream: _availabilityService.streamOrganizationAvailability(
            organizationId: organizationId,
          ),
          builder: (context, availabilitySnapshot) {
            final availabilityByUserId = <String, AvailabilityModel>{};
            for (final availability
                in availabilitySnapshot.data ?? const <AvailabilityModel>[]) {
              if (availability.userId.isNotEmpty) {
                availabilityByUserId[availability.userId] = availability;
              }
            }

            return StreamBuilder<List<PlannedUnavailabilityModel>>(
              stream: _plannedUnavailabilityService.streamOrganizationPeriods(
                organizationId: organizationId,
              ),
              builder: (context, periodsSnapshot) {
                return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
                  stream: _plannedUnavailabilityService.streamOrganizationRules(
                    organizationId: organizationId,
                  ),
                  builder: (context, rulesSnapshot) {
                    final now = DateTime.now();
                    final periods = periodsSnapshot.data ??
                        const <PlannedUnavailabilityModel>[];
                    final rules = rulesSnapshot.data ??
                        const <PlannedUnavailabilityRuleModel>[];
                    var onDutyCount = 0;
                    var delayedCount = 0;
                    var offDutyCount = 0;
                    var effectiveOnDutySecondLevelCount = 0;

                    for (final membershipDoc in activeMemberships) {
                      final membershipData = membershipDoc.data();
                      final userId =
                          (membershipData['userId'] ?? '').toString();
                      final availability = availabilityByUserId[userId];
                      final manualStatus =
                          availability?.status ?? AvailabilityStatus.offDuty;
                      final status = EffectiveAvailability.resolve(
                        userId: userId,
                        manualStatus: manualStatus,
                        periods: periods,
                        rules: rules,
                        now: now,
                      );

                      if (status == AvailabilityStatus.onDuty) {
                        onDutyCount++;
                        if (SeaRescueLevel.isLevel2(
                          membershipData['seaRescueLevel'],
                        )) {
                          effectiveOnDutySecondLevelCount++;
                        }
                      } else if (status == AvailabilityStatus.delayed) {
                        delayedCount++;
                      } else {
                        offDutyCount++;
                      }
                    }

                    return StreamBuilder<List<PlatformReadinessSummary>>(
                      stream: _platformReadinessService.streamOrganizationSummary(
                        organizationId: organizationId,
                      ),
                      builder: (context, readinessSnapshot) {
                        final summaries = readinessSnapshot.data ??
                            const <PlatformReadinessSummary>[];
                        final summary =
                            summaries.isEmpty ? null : summaries.first;
                        final minimumCrewRequired =
                            summary?.minimumCrewRequired ?? 0;
                        final readiness = ResponseReadiness.evaluate(
                          minimumCrewRequired: minimumCrewRequired,
                          onDutyCount: onDutyCount,
                          secondLevelOnDutyCount:
                              effectiveOnDutySecondLevelCount,
                        );
                        final secondLevelMet = readiness.secondLevelMet;
                        final responseReady = readiness.isReady;
                        final readinessColor = responseReady
                            ? Colors.green.shade700
                            : Colors.red.shade700;

                        return Card(
                          child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Valmisoleku kokkuvõte'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Text('Valves: $onDutyCount'),
                                Text('Hilinemisega: $delayedCount'),
                                Text('Mitte valves: $offDutyCount'),
                                Text(
                                  'II aste valves: '
                                  '$effectiveOnDutySecondLevelCount',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              responseReady
                                  ? 'Ühing on reageerimisvalmis'
                                  : 'Ühing ei ole reageerimisvalmis',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: readinessColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (!secondLevelMet) ...[
                              const SizedBox(height: 4),
                              Text(
                                'II astme merepäästja puudub',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.red[700]),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Valves liikmete arv arvestab aktiivseid '
                              'planeeritud valveväliseid aegu.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
      },
    );
  }

  Widget _buildModuleButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Widget _buildAvailabilityControl({
    required User user,
    required String organizationId,
    required String memberName,
    bool compact = false,
  }) {
    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: user.uid,
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Valmisolekut ei õnnestunud laadida. Kontrolli ühendust.');
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const LinearProgressIndicator();
        final availability = snapshot.data;
        final status = availability?.status ?? AvailabilityStatus.offDuty;
        final responseMinutes = availability?.responseMinutes ?? 15;

        Future<void> updateAvailability(
          String newStatus, {
          int? minutes,
        }) async {
          if (_savingAvailability) return;
          setState(() => _savingAvailability = true);
          try {
            await _availabilityService.setMyAvailability(
              userId: user.uid,
              organizationId: organizationId,
              memberName: memberName,
              status: newStatus,
              responseMinutes: minutes,
            );
          } catch (_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Valmisoleku muutmine ebaõnnestus. Kontrolli ühendust.')),
            );
          } finally {
            if (mounted) setState(() => _savingAvailability = false);
          }
        }

        return StreamBuilder<List<PlannedUnavailabilityModel>>(
          stream: _plannedUnavailabilityService.streamMyPeriods(
            organizationId: organizationId,
          ),
          builder: (context, periodsSnapshot) {
            return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
              stream: _plannedUnavailabilityService.streamMyRules(
                organizationId: organizationId,
              ),
              builder: (context, rulesSnapshot) {
                if (periodsSnapshot.hasError || rulesSnapshot.hasError) return const Text('Planeeritud valveväliseid aegu ei õnnestunud laadida. Valmisolekut ei saa kinnitada.');
                if (!periodsSnapshot.hasData || !rulesSnapshot.hasData) return const LinearProgressIndicator();
                final now = DateTime.now();
                final periods = periodsSnapshot.data ??
                    const <PlannedUnavailabilityModel>[];
                final rules = rulesSnapshot.data ??
                    const <PlannedUnavailabilityRuleModel>[];
                final hasActiveSchedule =
                    EffectiveAvailability.isPlannedUnavailable(
                  userId: user.uid,
                  periods: periods,
                  rules: rules,
                  now: now,
                );
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minu staatus',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (_savingAvailability) const Text('Salvestan valmisolekut… Serveri kinnitus on ootel.'),
                    if (hasActiveSchedule) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Planeeritud valveväline aeg on aktiivne',
                      ),
                      const Text('Nähtav staatus: Mitte valves'),
                      Text(
                        'Käsitsi valitud staatus: '
                        '${_availabilityStatusLabel(status)}',
                      ),
                    ],
                    const SizedBox(height: 8),
                    PersonalStatusChoices(status: status, minutes: responseMinutes,
                      saving: _savingAvailability, plannedUnavailable: hasActiveSchedule,
                      onSelect: (value) => updateAvailability(value,
                        minutes: value == AvailabilityStatus.delayed ? responseMinutes : null)),
                    if (!hasActiveSchedule &&
                        status == AvailabilityStatus.delayed) ...[
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        value: responseMinutes,
                        items: const [
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 min'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 min'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('60 min'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null || _savingAvailability) return;
                          updateAvailability(
                            AvailabilityStatus.delayed,
                            minutes: value,
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    HomeAbsencePreview(userId: user.uid, periods: periods, rules: rules,
                      onPlan: () => _pushPage(context, MaterialPageRoute<void>(
                        builder: (_) => AvailabilityScreen(organizationId: organizationId,
                          currentUid: user.uid, currentUserName: memberName,
                          canViewOrganizationReadiness: false, planningOnly: true, openPlanningOnStart: true)))),
                  ],
                );
                if (compact) return content;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _availabilityStatusLabel(String status) {
    switch (status) {
      case AvailabilityStatus.onDuty:
        return 'Valves';
      case AvailabilityStatus.delayed:
        return 'Hilinemisega';
      default:
        return 'Mitte valves';
    }
  }

  String _membershipRoleFromData(Map<String, dynamic> membership) {
    return MembershipRole.normalize(membership['role']);
  }

  String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Pole sisselogitud kasutajat')),
      );
    }

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('RespondCrew')),
            body: const Center(
              child: Text('Kasutaja profiili laadimine ebaõnnestus.'),
            ),
          );
        }

        final userData = userSnapshot.data?.data();
        if (userData == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('RespondCrew')),
            body: const Center(
              child: Text('Kasutaja profiili ei leitud.'),
            ),
          );
        }

        final name = _stringValue(userData['name']) ?? '';

        final isPlatformAdmin =
            PlatformRole.isPlatformAdmin(userData['systemRole']);

        final displayName = name.isEmpty ? (user.email ?? 'kasutaja') : name;

        return StreamBuilder<
            List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _membershipService.streamMembershipsForUser(user.uid),
          builder: (context, membershipsSnapshot) {
            if (membershipsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('RespondCrew'),
                  actions: _buildAppBarActions(
                    membershipDocs: const [],
                    currentActiveCommandId: null,
                    currentCommandName: null,
                  ),
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            if (membershipsSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('RespondCrew'),
                  actions: _buildAppBarActions(
                    membershipDocs: const [],
                    currentActiveCommandId: null,
                    currentCommandName: null,
                  ),
                ),
                body: const Center(
                  child: Text('Liikmelisuste laadimine ebaõnnestus.'),
                ),
              );
            }

            final allMembershipDocs = membershipsSnapshot.data ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final membershipDocs = _activeMembershipDocs(allMembershipDocs);
            final visibleMembershipDocs = allMembershipDocs.where((doc) =>
              _membershipService.isActiveMembership(doc.data()) || doc.data()['status'] == 'pending').toList();

            String? activeCommandId;
            String? myMembershipRole;
            String? mySeaRescueLevel;

            if (membershipDocs.isNotEmpty) {
              final requestedOrganizationId =
                  _membershipService.resolveActiveOrganizationId(
                userData: userData,
                memberships: membershipDocs,
              );
              final activeMembership = requestedOrganizationId == null
                  ? null
                  : _membershipService.membershipForOrganizationId(
                      organizationId: requestedOrganizationId,
                      memberships: membershipDocs,
                    );

              activeCommandId = activeMembership == null
                  ? null
                  : requestedOrganizationId;
              mySeaRescueLevel = activeMembership?['seaRescueLevel'] as String?;
              myMembershipRole = activeMembership == null
                  ? null
                  : _membershipRoleFromData(activeMembership);
            } else {
              activeCommandId = null;
              myMembershipRole = null;
            }

            final isOrganizationAdmin =
                MembershipRole.isOrgAdmin(myMembershipRole);
            final canSeeJoinCode =
                isPlatformAdmin || isOrganizationAdmin;

            if (activeCommandId == null || activeCommandId.isEmpty) {
              final hasPendingMembership =
                  _hasPendingMembership(allMembershipDocs);
              final hasDisabledMembership =
                  _hasDisabledMembership(allMembershipDocs);
              final missingOrganizationTitle = hasPendingMembership
                  ? 'Ootad kinnitust.'
                  : hasDisabledMembership
                      ? 'Sinu liikmelisus ei ole aktiivne.'
                      : null;
              final missingOrganizationMessage = hasPendingMembership
                  ? 'Liitumistaotluse kinnitab ühingu administraator, '
                      'uue ühingu kinnitab platvormi haldur. '
                      'Pärast kinnitamist saad rakendust kasutada.'
                  : hasDisabledMembership
                      ? 'Vali teine ühing, liitu koodiga või loo uus taotlus.'
                      : null;

              return Scaffold(
                appBar: AppBar(
                  title: const Text('RespondCrew'),
                  actions: _buildAppBarActions(
                    membershipDocs: visibleMembershipDocs,
                    currentActiveCommandId: activeCommandId,
                    currentCommandName: null,
                  ),
                ),
                body: ListView(
                  children: [
                    _buildHeaderSection(
                      user: user,
                      displayName: displayName,
                      commandId: activeCommandId,
                      commandName: null,
                      joinCode: null,
                      canSeeJoinCode: canSeeJoinCode,
                      isPlatformAdmin: isPlatformAdmin,
                      membershipRole: myMembershipRole,
                      allowMembersToCreateActivities: false,
                      allowMembersToViewStatistics: false,
                      allowMembersToStartOperationLog: false,
                      membershipDocs: visibleMembershipDocs,
                    ),
                    const PendingInvitesSection(),
                    _buildMissingOrganizationState(
                      hasMemberships: membershipDocs.isNotEmpty,
                      membershipDocs: visibleMembershipDocs,
                      title: missingOrganizationTitle,
                      message: missingOrganizationMessage,
                    ),
                  ],
                ),
              );
            }

            final String selectedOrganizationId = activeCommandId;
            final organizationCount =
                _organizationIdsFromMembershipDocs(visibleMembershipDocs).length;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('commands')
                  .doc(selectedOrganizationId)
                  .snapshots(),
              builder: (context, commandSnapshot) {
                if (commandSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !commandSnapshot.hasData) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('RespondCrew'),
                      actions: _buildAppBarActions(
                        membershipDocs: visibleMembershipDocs,
                        currentActiveCommandId: selectedOrganizationId,
                        currentCommandName: null,
                      ),
                    ),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }

                final commandData = commandSnapshot.data?.data();
                final commandName = commandData?['name'] as String?;
                final joinCode = commandData?['joinCode'] as String?;
                final commandStatus =
                    (commandData?['status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                final organizationIsBlocked =
                    commandStatus == 'pending' || commandStatus == 'rejected';
                final allowMembersToCreateActivities =
                    commandData?['allowMembersToCreateActivities'] == true;
                final allowMembersToViewStatistics =
                    commandData?['allowMembersToViewStatistics'] == true;
                final allowMembersToStartOperationLog =
                    commandData?['allowMembersToStartOperationLog'] == true || SeaRescueLevel.isLevel2(mySeaRescueLevel);

                final permissions = _HomePermissions(
                  isPlatformAdmin: isPlatformAdmin,
                  isOrganizationAdmin: isOrganizationAdmin,
                  allowMembersToCreateActivities:
                      allowMembersToCreateActivities,
                  allowMembersToViewStatistics:
                      allowMembersToViewStatistics,
                  allowMembersToStartOperationLog:
                      allowMembersToStartOperationLog,
                );

                if (organizationIsBlocked) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('RespondCrew'),
                      actions: _buildAppBarActions(
                        membershipDocs: visibleMembershipDocs,
                        currentActiveCommandId: selectedOrganizationId,
                        currentCommandName: commandName,
                      ),
                    ),
                    body: ListView(
                      children: [
                        const PendingInvitesSection(),
                        _buildBlockedOrganizationState(
                          status: commandStatus,
                          organizationName: commandName,
                          isPlatformAdmin: isPlatformAdmin,
                        ),
                      ],
                    ),
                  );
                }

                void openNotifications() => _pushPage(context, MaterialPageRoute<void>(builder: (_) => NotificationsScreen(
                    organizationId: selectedOrganizationId,
                    currentUid: user.uid,
                    currentUserName: displayName,
                    canManageNotifications: permissions.canManageNotifications,
                    canCreateActivities: permissions.canCreateActivity,
                    canStartOperationLog: permissions.canStartOperationLog,
                  )));
                final homeContent = Scaffold(
                  appBar: AppBar(
                    title: HomeOrganizationTitle(name: commandName ?? 'Ühing',
                      onSwitch: organizationCount > 1 ? () => _showSwitchOrganizationDialog(
                        membershipDocs: visibleMembershipDocs, currentActiveCommandId: selectedOrganizationId) : null),
                    actions: [IconButton(tooltip: 'Teavitused', icon: const Icon(Icons.notifications_outlined), onPressed: openNotifications),
                    ..._buildAppBarActions(
                      membershipDocs: visibleMembershipDocs,
                      currentActiveCommandId: selectedOrganizationId,
                      currentCommandName: commandName,
                    )],
                  ),
                  body: permissions.canManageOrganization
                      ? AdminHomeDashboard(
                          organizationId: selectedOrganizationId,
                          currentUid: user.uid,
                          topHeader: _buildCompactOperationalHeader(
                            displayName: displayName,
                            commandId: selectedOrganizationId,
                            commandName: commandName,
                            isPlatformAdmin: isPlatformAdmin,
                            membershipRole: myMembershipRole,
                            membershipDocs: visibleMembershipDocs,
                            availabilityControl: _buildAvailabilityControl(
                              user: user,
                              organizationId: selectedOrganizationId,
                              memberName: displayName,
                              compact: true,
                            ),
                          ),
                          onCreateCallout: () {
                            _pushPage(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CalloutsScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  currentUserName: displayName,
                                  canManageCallouts:
                                      permissions.canCreateCallout,
                                  canCloseCallouts:
                                      permissions.canCloseCallout,
                                  canStartOperationLog:
                                      permissions.canStartOperationLog,
                                  openCreateOnLoad: true,
                                ),
                              ),
                            );
                          },
                          onCreateActivity: () {
                            _pushPage(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivitiesScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageActivities:
                                      permissions.canCreateActivity,
                                  openCreateOnLoad: true,
                                ),
                              ),
                            );
                          },
                          onCreateEquipment: () {
                            _pushPage(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EquipmentScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageEquipment: permissions
                                      .canManageOrganizationEquipment,
                                  openOrganizationCreateOnLoad: true,
                                ),
                              ),
                            );
                          },
                          onOpenMembers: () => _pushPage(context, MaterialPageRoute<void>(builder: (_) => MembersScreen(
                            organizationId: selectedOrganizationId, currentUid: user.uid,
                            canManageRoles: permissions.canManageMembers))),
                          onOpenCallout: (id) => setState(() { _pendingCalloutId = id; _selectedNavigationIndex = 1; }),
                          onOpenCallouts: () {
                            setState(() => _selectedNavigationIndex = 1);
                          },
                          onOpenEquipment: () {
                            _pushPage(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EquipmentScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageEquipment: permissions
                                      .canManageOrganizationEquipment,
                                ),
                              ),
                            );
                          },
                          onOpenNotifications: () {
                            openNotifications();
                          },
                        )
                      : MemberHomeDashboard(
                          organizationId: selectedOrganizationId,
                          currentUid: user.uid,
                          topHeader: _buildCompactOperationalHeader(
                            displayName: displayName,
                            commandId: selectedOrganizationId,
                            commandName: commandName,
                            isPlatformAdmin: isPlatformAdmin,
                            membershipRole: myMembershipRole,
                            membershipDocs: visibleMembershipDocs,
                            availabilityControl: _buildAvailabilityControl(
                              user: user,
                              organizationId: selectedOrganizationId,
                              memberName: displayName,
                              compact: true,
                            ),
                          ),
                          onOpenMembers: () => _pushPage(context, MaterialPageRoute<void>(builder: (_) => MembersScreen(
                            organizationId: selectedOrganizationId, currentUid: user.uid,
                            canManageRoles: permissions.canManageMembers))),
                          onOpenCallout: (id) => setState(() { _pendingCalloutId = id; _selectedNavigationIndex = 1; }),
                          onOpenCallouts: () {
                            setState(() => _selectedNavigationIndex = 1);
                          },
                          onOpenNotifications: () {
                            openNotifications();
                          },
                          onOpenActivities: () {
                            _pushPage(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivitiesScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageActivities:
                                      permissions.canCreateActivity,
                                ),
                              ),
                            );
                          },
                        ),
                );

                final screens = <Widget>[
                  homeContent,
                  CalloutsScreen(
                    organizationId: selectedOrganizationId,
                    currentUid: user.uid,
                    currentUserName: displayName,
                    canManageCallouts: permissions.canCreateCallout,
                    canCloseCallouts: permissions.canCloseCallout,
                    canStartOperationLog: permissions.canStartOperationLog,
                    initialCalloutId: _pendingCalloutId,
                    onInitialCalloutOpened: () {
                      if (!mounted) return;
                      setState(() => _pendingCalloutId = null);
                    },
                  ),
                  for (final planningOnly in [false, true])
                    AvailabilityScreen(
                      key: ValueKey(planningOnly),
                      organizationId: selectedOrganizationId,
                      organizationName: commandName,
                      membershipRole: myMembershipRole,
                      currentUid: user.uid,
                      currentUserName: displayName,
                      canViewOrganizationReadiness: permissions.canViewOrganizationReadiness,
                      planningOnly: planningOnly,
                    ),
                  MenuScreen(
                    onOpenNotifications: openNotifications,
                    organizationId: selectedOrganizationId,
                    organizationName: commandName,
                    currentUid: user.uid,
                    currentUserName: displayName,
                    isOrganizationAdmin: permissions.canManageOrganization,
                    isPlatformAdmin: isPlatformAdmin,
                    canCreateActivities: permissions.canCreateActivity,
                    canViewStatistics: permissions.canViewStatistics,
                    canStartOperationLog: permissions.canStartOperationLog,
                    onOpenOrganizationSettings: () {
                      _pushPage(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text(
                                'Ühingu seaded',
                              ),
                            ),
                            body: _buildOrganizationSettingsContent(
                              user: user,
                              commandId: selectedOrganizationId,
                              commandName: commandName,
                              joinCode: joinCode,
                              canSeeJoinCode: canSeeJoinCode,
                              isPlatformAdmin: isPlatformAdmin,
                              membershipRole: myMembershipRole,
                              allowMembersToCreateActivities:
                                  allowMembersToCreateActivities,
                              allowMembersToViewStatistics:
                                  allowMembersToViewStatistics,
                              allowMembersToStartOperationLog:
                                  allowMembersToStartOperationLog,
                            ),
                          ),
                        ),
                      );
                    },
                    onSwitchOrganization: organizationCount > 1
                        ? () => _showSwitchOrganizationDialog(
                              membershipDocs: visibleMembershipDocs,
                              currentActiveCommandId: selectedOrganizationId,
                            )
                        : null,
                  ),
                ];

                if (_navigatorOrganizationId != selectedOrganizationId) {
                  _navigatorOrganizationId = selectedOrganizationId;
                  _contentNavigatorKey = GlobalKey<NavigatorState>();
                }
                final pendingPage = _pendingNotificationPage;
                if (pendingPage != null && pendingPage.$1 == selectedOrganizationId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _pendingNotificationPage != pendingPage) return;
                    final navigator = _contentNavigatorKey.currentState;
                    if (navigator == null) return;
                    _pendingNotificationPage = null;
                    navigator.popUntil((route) => route.isFirst);
                    navigator.push(MaterialPageRoute<void>(builder: (_) => pendingPage.$2));
                  });
                }
                return MainNavigationShell(
                  key: ValueKey('${user.uid}:$selectedOrganizationId'),
                  navigatorKey: _contentNavigatorKey,
                  currentIndex: _selectedNavigationIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedNavigationIndex = index);
                  },
                  child: screens[_selectedNavigationIndex],
                );
              },
            );
          },
        );
      },
    );
  }
}
