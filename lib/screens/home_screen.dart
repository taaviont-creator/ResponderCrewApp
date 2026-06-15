import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/availability_model.dart';
import '../services/availability_service.dart';
import '../services/command_service.dart';
import '../services/membership_service.dart';
import '../services/notification_service.dart';
import 'activities_screen.dart';
import 'admin_home_dashboard.dart';
import 'availability_screen.dart';
import 'callouts_screen.dart';
import 'certificates_screen.dart';
import 'equipment_screen.dart';
import 'main_navigation_shell.dart';
import 'members_screen.dart';
import 'member_home_dashboard.dart';
import 'menu_screen.dart';
import 'notifications_screen.dart';
import 'operation_log_screen.dart';
import 'platform_readiness_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _availabilityService = AvailabilityService();
  final _commandService = CommandService();
  final _membershipService = MembershipService();
  final _notificationService = NotificationService();
  var _selectedNavigationIndex = 0;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _setActiveCommand(String commandId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final organizationId = commandId.trim();
    if (organizationId.isEmpty) {
      throw Exception('Selle toimingu jaoks puudub aktiivne organisatsioon');
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
      throw Exception('Sul puudub selle organisatsiooni aktiivne liikmelisus');
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
        title: const Text('Liitu komandoga'),
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
      await _commandService.joinCommand(joinCode: code.trim());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liitusid komandoga!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viga: $e')),
      );
    }
  }

  Future<void> _showCreateCommandDialog() async {
    final nameController = TextEditingController();

    final commandName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uus komando'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Komando nimi',
            hintText: 'nt Purtse',
          ),
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
        const SnackBar(content: Text('Komando loodud ja liidetud!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viga: $e')),
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
        });
      } catch (_) {
        items.add({
          'commandId': commandId,
          'commandName': commandId,
        });
      }
    }

    if (!mounted) return;

    final selectedCommandId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vali aktiivne organisatsioon'),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? const Text('Ühtegi organisatsiooni ei leitud')
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
                      subtitle: Text(commandId),
                      trailing:
                          isSelected ? const Icon(Icons.check_circle) : null,
                      onTap: () => Navigator.pop(context, commandId),
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
        const SnackBar(content: Text('Aktiivne organisatsioon muudetud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viga: $e')),
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
        title: const Text('Lahku organisatsioonist'),
        content: Text(
          'Kas soovid lahkuda organisatsioonist '
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
        const SnackBar(content: Text('Lahkusid organisatsioonist')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viga: $e')),
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
      IconButton(
        onPressed: _signOut,
        icon: const Icon(Icons.logout),
        tooltip: 'Logi välja',
      ),
      IconButton(
        icon: const Icon(Icons.swap_horiz),
        tooltip: 'Vaheta organisatsiooni',
        onPressed: !canSelectOrganization
            ? null
            : () => _showSwitchOrganizationDialog(
                  membershipDocs: membershipDocs,
                  currentActiveCommandId: currentActiveCommandId,
                ),
      ),
      IconButton(
        icon: const Icon(Icons.exit_to_app),
        tooltip: 'Lahku organisatsioonist',
        onPressed: currentActiveCommandId == null || currentActiveCommandId.isEmpty
            ? null
            : () => _showLeaveOrganizationDialog(
                  commandId: currentActiveCommandId,
                  commandName: currentCommandName,
                ),
      ),
      IconButton(
        icon: const Icon(Icons.vpn_key),
        tooltip: 'Liitu koodiga',
        onPressed: _showJoinCommandDialog,
      ),
      IconButton(
        icon: const Icon(Icons.group_add),
        tooltip: 'Loo komando',
        onPressed: _showCreateCommandDialog,
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

  Future<List<Map<String, String>>> _loadOrganizationItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  ) async {
    final organizationIds = _organizationIdsFromMembershipDocs(membershipDocs);

    final items = <Map<String, String>>[];

    for (final organizationId in organizationIds) {
      try {
        final commandSnap = await FirebaseFirestore.instance
            .collection('commands')
            .doc(organizationId)
            .get();
        final commandData = commandSnap.data();
        final commandName = (commandData?['name'] ?? organizationId) as String;

        items.add({
          'id': organizationId,
          'name': commandName,
        });
      } catch (_) {
        items.add({
          'id': organizationId,
          'name': organizationId,
        });
      }
    }

    items.sort((a, b) => a['name']!.compareTo(b['name']!));
    return items;
  }

  Widget _buildOrganizationSelector({
    required String? activeOrganizationId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  }) {
    return FutureBuilder<List<Map<String, String>>>(
      future: _loadOrganizationItems(membershipDocs),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, String>>[];
        if (items.length <= 1) {
          return const SizedBox.shrink();
        }

        final selectedId = items.any((item) => item['id'] == activeOrganizationId)
            ? activeOrganizationId
            : null;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButton<String>(
            value: selectedId,
            hint: const Text('Vali organisatsioon'),
            isExpanded: true,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item['id'],
                child: Text(item['name']!),
              );
            }).toList(),
            onChanged: (value) async {
              if (value == null || value == activeOrganizationId) return;

              try {
                await _setActiveCommand(value);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Organisatsiooni vahetamine ebaõnnestus: $e',
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMissingOrganizationState({
    required bool hasMemberships,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasMemberships ? 'Vali organisatsioon' : 'Organisatsioon puudub',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            hasMemberships
                ? 'Enne jätkamist vali aktiivne organisatsioon.'
                : 'Sul puudub aktiivne organisatsiooni liikmelisus. '
                    'Loo uus organisatsioon või liitu olemasolevaga.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasMemberships)
                ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Vali organisatsioon'),
                  onPressed: () => _showSwitchOrganizationDialog(
                    membershipDocs: membershipDocs,
                    currentActiveCommandId: null,
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text('Loo uus organisatsioon'),
                onPressed: _showCreateCommandDialog,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key),
                label: const Text('Liitu organisatsiooniga'),
                onPressed: _showJoinCommandDialog,
              ),
            ],
          ),
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
    required bool isPlatformOwner,
    required String? membershipRole,
    required bool allowMembersToCreateActivities,
    required bool allowMembersToViewStatistics,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  }) {
    final isOrganizationAdmin = membershipRole == 'admin';
    final canCreateActivities =
        isOrganizationAdmin || allowMembersToCreateActivities;
    final canViewStatistics =
        isOrganizationAdmin || allowMembersToViewStatistics;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tere, $displayName',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Komando ID: ${commandId ?? "PUUDUB"}'),
          if (commandName != null && commandName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Komando nimi: $commandName'),
          ],
          if (commandId != null && commandId.isNotEmpty)
            _buildOrganizationSelector(
              activeOrganizationId: commandId,
              membershipDocs: membershipDocs,
            ),
          const SizedBox(height: 4),
          Text(
            'Minu roll: ${membershipRole ?? "puudub"}'
            '${isPlatformOwner ? " • platformOwner" : ""}',
          ),
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
          if (isOrganizationAdmin &&
              commandId != null &&
              commandId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
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
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPlatformOwner ||
              (isOrganizationAdmin &&
                  commandId != null &&
                  commandId.isNotEmpty)) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.health_and_safety),
              label: const Text('Platvormi valmidus'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlatformReadinessScreen(
                      currentUid: user.uid,
                      activeOrganizationId: commandId,
                      activeOrganizationName: commandName,
                      canManageOwnSummary: membershipRole == 'admin',
                      isPlatformOwner: isPlatformOwner,
                    ),
                  ),
                );
              },
            ),
          ],
          if (commandId != null && commandId.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAvailabilityControl(
              user: user,
              organizationId: commandId,
              memberName: displayName,
            ),
            if (isOrganizationAdmin) ...[
              const SizedBox(height: 16),
              _buildReadinessSummary(organizationId: commandId),
            ],
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
                if (isOrganizationAdmin)
                  _buildModuleButton(
                    icon: Icons.group,
                    label: 'Liikmed',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MembersScreen(
                          organizationId: commandId,
                          currentUid: user.uid,
                          canManageRoles: true,
                        ),
                      ),
                    ),
                  ),
                _buildModuleButton(
                  icon: Icons.campaign,
                  label: 'Valjakutsed',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalloutsScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        currentUserName: displayName,
                        canManageCallouts: membershipRole == 'admin',
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.check_circle,
                  label: 'Valmisolek',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvailabilityScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        currentUserName: displayName,
                        canViewOrganizationReadiness: isOrganizationAdmin,
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.inventory_2,
                  label: isOrganizationAdmin ? 'Varustus' : 'Minu varustus',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EquipmentScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        canManageEquipment: membershipRole == 'admin',
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.assignment,
                  label: 'Operatsioonilogi',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OperationLogScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        currentUserName: displayName,
                        canViewCalloutResponseSummary:
                            membershipRole == 'admin',
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.event,
                  label: 'Tegevused',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivitiesScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        canManageActivities: canCreateActivities,
                      ),
                    ),
                  ),
                ),
                _buildModuleButton(
                  icon: Icons.card_membership,
                  label: isOrganizationAdmin
                      ? 'Kvalifikatsioonid'
                      : 'Minu kvalifikatsioonid',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CertificatesScreen(
                        organizationId: commandId,
                        currentUid: user.uid,
                        canManageCertificates: membershipRole == 'admin',
                      ),
                    ),
                  ),
                ),
                if (canViewStatistics)
                  _buildModuleButton(
                    icon: Icons.insights,
                    label: 'Statistika',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StatisticsScreen(
                            organizationId: commandId,
                            currentUid: user.uid,
                            canViewStatistics: true,
                            canViewOrganizationCertificates:
                                isOrganizationAdmin,
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
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                            organizationId: commandId,
                            currentUid: user.uid,
                            currentUserName: displayName,
                            canManageNotifications:
                                membershipRole == 'admin',
                            canCreateActivities: canCreateActivities,
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

  Future<void> _updateMemberPermissions({
    required String organizationId,
    required bool allowMembersToCreateActivities,
    required bool allowMembersToViewStatistics,
  }) async {
    try {
      await _commandService.updateMemberPermissions(
        organizationId: organizationId,
        allowMembersToCreateActivities: allowMembersToCreateActivities,
        allowMembersToViewStatistics: allowMembersToViewStatistics,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seadete muutmine ebaõnnestus: $e')),
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

            var onDutyCount = 0;
            var delayedCount = 0;
            var offDutyCount = 0;

            for (final membershipDoc in activeMemberships) {
              final userId = (membershipDoc.data()['userId'] ?? '').toString();
              final availability = availabilityByUserId[userId];
              final status = availability?.status ?? AvailabilityStatus.offDuty;

              if (status == AvailabilityStatus.onDuty) {
                onDutyCount++;
              } else if (status == AvailabilityStatus.delayed) {
                delayedCount++;
              } else {
                offDutyCount++;
              }
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Valmisoleku kokkuvote'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text('On duty: $onDutyCount'),
                        Text('Delayed: $delayedCount'),
                        Text('Off duty: $offDutyCount'),
                      ],
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
  }) {
    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: user.uid,
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        final availability = snapshot.data;
        final status = availability?.status ?? AvailabilityStatus.offDuty;
        final responseMinutes = availability?.responseMinutes ?? 15;

        Future<void> updateAvailability(
          String newStatus, {
          int? minutes,
        }) async {
          try {
            await _availabilityService.setMyAvailability(
              userId: user.uid,
              organizationId: organizationId,
              memberName: memberName,
              status: newStatus,
              responseMinutes: minutes,
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Valmiduse muutmine ebaõnnestus: $e')),
            );
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Minu valmisolek'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Off duty'),
                      selected: status == AvailabilityStatus.offDuty,
                      onSelected: (_) => updateAvailability(
                        AvailabilityStatus.offDuty,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('On duty'),
                      selected: status == AvailabilityStatus.onDuty,
                      onSelected: (_) => updateAvailability(
                        AvailabilityStatus.onDuty,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Delayed'),
                      selected: status == AvailabilityStatus.delayed,
                      onSelected: (_) => updateAvailability(
                        AvailabilityStatus.delayed,
                        minutes: responseMinutes,
                      ),
                    ),
                  ],
                ),
                if (status == AvailabilityStatus.delayed) ...[
                  const SizedBox(height: 8),
                  DropdownButton<int>(
                    value: responseMinutes,
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      updateAvailability(
                        AvailabilityStatus.delayed,
                        minutes: value,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _membershipRoleFromData(Map<String, dynamic> membership) {
    final role = membership['role'];
    return role is String && role.isNotEmpty ? role : 'member';
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
            body: Center(child: Text('Viga: ${userSnapshot.error}')),
          );
        }

        final userData = userSnapshot.data?.data();
        if (userData == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('RespondCrew')),
            body: const Center(
              child: Text('Kasutaja profiili ei leitud Firestore’ist'),
            ),
          );
        }

        final name = _stringValue(userData['name']) ?? '';

        final activeOrganizationIdFromUser =
            _stringValue(userData['activeOrganizationId']);
        final systemRole = _stringValue(userData['systemRole']) ?? '';
        final isPlatformOwner = systemRole == 'platformOwner';

        final displayName = name.isEmpty ? (user.email ?? 'kasutaja') : name;

        return StreamBuilder<
            List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _membershipService.streamActiveMembershipsForUser(user.uid),
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
                body: Center(
                  child: Text(
                    'Viga membershipite laadimisel: ${membershipsSnapshot.error}',
                  ),
                ),
              );
            }

            final membershipDocs = membershipsSnapshot.data ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            String? activeCommandId;
            String? myMembershipRole;

            if (membershipDocs.isNotEmpty) {
              final requestedOrganizationId =
                  activeOrganizationIdFromUser?.trim();
              final activeMembership = requestedOrganizationId == null ||
                      requestedOrganizationId.isEmpty
                  ? null
                  : _membershipService.membershipForOrganizationId(
                      organizationId: requestedOrganizationId,
                      memberships: membershipDocs,
                    );

              activeCommandId = activeMembership == null
                  ? null
                  : requestedOrganizationId;
              myMembershipRole = activeMembership == null
                  ? null
                  : _membershipRoleFromData(activeMembership);
            } else {
              activeCommandId = null;
              myMembershipRole = null;
            }

            final canSeeJoinCode =
                isPlatformOwner || (myMembershipRole == 'admin');

            if (activeCommandId == null || activeCommandId.isEmpty) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('RespondCrew'),
                  actions: _buildAppBarActions(
                    membershipDocs: membershipDocs,
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
                      isPlatformOwner: isPlatformOwner,
                      membershipRole: myMembershipRole,
                      allowMembersToCreateActivities: false,
                      allowMembersToViewStatistics: false,
                      membershipDocs: membershipDocs,
                    ),
                    _buildMissingOrganizationState(
                      hasMemberships: membershipDocs.isNotEmpty,
                      membershipDocs: membershipDocs,
                    ),
                  ],
                ),
              );
            }

            final String selectedOrganizationId = activeCommandId;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('commands')
                  .doc(selectedOrganizationId)
                  .snapshots(),
              builder: (context, commandSnapshot) {
                final commandData = commandSnapshot.data?.data();
                final commandName = commandData?['name'] as String?;
                final joinCode = commandData?['joinCode'] as String?;
                final allowMembersToCreateActivities =
                    commandData?['allowMembersToCreateActivities'] == true;
                final allowMembersToViewStatistics =
                    commandData?['allowMembersToViewStatistics'] == true;

                final isOrganizationAdmin = myMembershipRole == 'admin';
                final canCreateActivities =
                    isOrganizationAdmin || allowMembersToCreateActivities;
                final canViewStatistics =
                    isOrganizationAdmin || allowMembersToViewStatistics;

                final homeContent = Scaffold(
                  appBar: AppBar(
                    title: const Text('RespondCrew'),
                    actions: _buildAppBarActions(
                      membershipDocs: membershipDocs,
                      currentActiveCommandId: selectedOrganizationId,
                      currentCommandName: commandName,
                    ),
                  ),
                  body: isOrganizationAdmin
                      ? AdminHomeDashboard(
                          organizationId: selectedOrganizationId,
                          organizationName: commandName,
                          onCreateCallout: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CalloutsScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  currentUserName: displayName,
                                  canManageCallouts: true,
                                  openCreateOnLoad: true,
                                ),
                              ),
                            );
                          },
                          onCreateActivity: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivitiesScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageActivities: true,
                                  openCreateOnLoad: true,
                                ),
                              ),
                            );
                          },
                          onCreateEquipment: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EquipmentScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageEquipment: true,
                                  openOrganizationCreateOnLoad: true,
                                ),
                              ),
                            );
                          },
                          onOpenCallouts: () {
                            setState(() => _selectedNavigationIndex = 2);
                          },
                          onOpenEquipment: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EquipmentScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageEquipment: true,
                                ),
                              ),
                            );
                          },
                          onOpenNotifications: () {
                            setState(() => _selectedNavigationIndex = 3);
                          },
                          onOpenOrganizationSettings: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text(
                                      'Organisatsiooni seaded',
                                    ),
                                  ),
                                  body: ListView(
                                    children: [
                                      _buildHeaderSection(
                                        user: user,
                                        displayName: displayName,
                                        commandId: selectedOrganizationId,
                                        commandName: commandName,
                                        joinCode: joinCode,
                                        canSeeJoinCode: canSeeJoinCode,
                                        isPlatformOwner: isPlatformOwner,
                                        membershipRole: myMembershipRole,
                                        allowMembersToCreateActivities:
                                            allowMembersToCreateActivities,
                                        allowMembersToViewStatistics:
                                            allowMembersToViewStatistics,
                                        membershipDocs: membershipDocs,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : MemberHomeDashboard(
                          organizationId: selectedOrganizationId,
                          organizationName: commandName,
                          currentUid: user.uid,
                          currentUserName: displayName,
                          onOpenCallouts: () {
                            setState(() => _selectedNavigationIndex = 2);
                          },
                          onOpenNotifications: () {
                            setState(() => _selectedNavigationIndex = 3);
                          },
                          onOpenActivities: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivitiesScreen(
                                  organizationId: selectedOrganizationId,
                                  currentUid: user.uid,
                                  canManageActivities: canCreateActivities,
                                ),
                              ),
                            );
                          },
                        ),
                );

                final screens = <Widget>[
                  homeContent,
                  AvailabilityScreen(
                    organizationId: selectedOrganizationId,
                    currentUid: user.uid,
                    currentUserName: displayName,
                    canViewOrganizationReadiness: isOrganizationAdmin,
                  ),
                  CalloutsScreen(
                    organizationId: selectedOrganizationId,
                    currentUid: user.uid,
                    currentUserName: displayName,
                    canManageCallouts: isOrganizationAdmin,
                  ),
                  NotificationsScreen(
                    organizationId: selectedOrganizationId,
                    currentUid: user.uid,
                    currentUserName: displayName,
                    canManageNotifications: isOrganizationAdmin,
                    canCreateActivities: canCreateActivities,
                  ),
                  MenuScreen(
                    organizationId: selectedOrganizationId,
                    organizationName: commandName,
                    currentUid: user.uid,
                    currentUserName: displayName,
                    isOrganizationAdmin: isOrganizationAdmin,
                    isPlatformOwner: isPlatformOwner,
                    canCreateActivities: canCreateActivities,
                    canViewStatistics: canViewStatistics,
                    onOpenOrganizationSettings: () {
                      setState(() => _selectedNavigationIndex = 0);
                    },
                  ),
                ];

                return MainNavigationShell(
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
