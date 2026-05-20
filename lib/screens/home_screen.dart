import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/availability_reminder_settings_model.dart';
import '../models/availability_model.dart';
import '../models/equipment_model.dart';
import '../services/availability_reminder_settings_service.dart';
import '../services/availability_service.dart';
import '../services/command_service.dart';
import '../services/equipment_service.dart';
import '../services/membership_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _availabilityService = AvailabilityService();
  final _availabilityReminderSettingsService =
      AvailabilityReminderSettingsService();
  final _commandService = CommandService();
  final _equipmentService = EquipmentService();
  final _membershipService = MembershipService();

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _setActiveCommand(String commandId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'activeOrganizationId': commandId,
      'activeCommandId': commandId,
      'commandId': commandId,
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

  Future<void> _showAddEquipmentDialog({
    required String organizationId,
    required String createdBy,
  }) async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final noteController = TextEditingController();
    var selectedCategory = EquipmentCategory.other;
    var selectedStatus = EquipmentStatus.ok;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Lisa varustus'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nimi',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategooria',
                    ),
                    items: EquipmentCategory.values.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(_equipmentCategoryLabel(category)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Staatus',
                    ),
                    items: EquipmentStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_equipmentStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Asukoht',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Märkus',
                    ),
                    maxLines: 2,
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
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lisa'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true) return;

    try {
      await _equipmentService.addEquipment(
        organizationId: organizationId,
        name: nameController.text,
        category: selectedCategory,
        status: selectedStatus,
        location: locationController.text,
        note: noteController.text,
        createdBy: createdBy,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varustus lisatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Varustuse lisamine ebaõnnestus: $e')),
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
    final canSwitchOrganization =
        _organizationIdsFromMembershipDocs(membershipDocs).length > 1;

    return [
      IconButton(
        onPressed: _signOut,
        icon: const Icon(Icons.logout),
        tooltip: 'Logi välja',
      ),
      IconButton(
        icon: const Icon(Icons.swap_horiz),
        tooltip: 'Vaheta organisatsiooni',
        onPressed: !canSwitchOrganization
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
            : items.first['id'];

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButton<String>(
            value: selectedId,
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

  Widget _buildHeaderSection({
    required User user,
    required String displayName,
    required String? commandId,
    required String? commandName,
    required String? joinCode,
    required bool canSeeJoinCode,
    required bool isPlatformOwner,
    required String? membershipRole,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
  }) {
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
          if (commandId != null && commandId.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAvailabilityControl(
              user: user,
              organizationId: commandId,
            ),
            const SizedBox(height: 16),
            _buildAvailabilityReminderSettings(
              user: user,
              organizationId: commandId,
            ),
            const SizedBox(height: 16),
            _buildAvailabilityOverview(
              organizationId: commandId,
            ),
            const SizedBox(height: 16),
            _buildEquipmentSection(
              organizationId: commandId,
              canManageEquipment: membershipRole == 'admin',
              currentUid: user.uid,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Liikmed',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAvailabilityControl({
    required User user,
    required String organizationId,
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

  Widget _buildAvailabilityReminderSettings({
    required User user,
    required String organizationId,
  }) {
    return StreamBuilder<AvailabilityReminderSettingsModel>(
      stream: _availabilityReminderSettingsService.streamMySettings(
        userId: user.uid,
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        final settings = snapshot.data ??
            AvailabilityReminderSettingsModel.defaults(
              userId: user.uid,
              organizationId: organizationId,
            );
        final timeOptions = _reminderTimeOptions(settings.reminderTime);

        Future<void> updateReminderSettings({
          bool? enabled,
          int? intervalHours,
          String? reminderTime,
        }) async {
          try {
            await _availabilityReminderSettingsService.setMySettings(
              userId: user.uid,
              organizationId: organizationId,
              enabled: enabled ?? settings.enabled,
              intervalHours: intervalHours ?? settings.intervalHours,
              reminderTime: reminderTime ?? settings.reminderTime,
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Meeldetuletuse muutmine ebaonnestus: $e'),
              ),
            );
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Valmisoleku meeldetuletused'),
                  value: settings.enabled,
                  onChanged: (value) => updateReminderSettings(
                    enabled: value,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: settings.intervalHours,
                  decoration: const InputDecoration(
                    labelText: 'Intervall',
                  ),
                  items: AvailabilityReminderSettingsModel.allowedIntervalHours
                      .map((hours) {
                    return DropdownMenuItem<int>(
                      value: hours,
                      child: Text(_reminderIntervalLabel(hours)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    updateReminderSettings(intervalHours: value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: settings.reminderTime,
                  decoration: const InputDecoration(
                    labelText: 'Kellaaeg',
                  ),
                  items: timeOptions.map((time) {
                    return DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    updateReminderSettings(reminderTime: value);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityOverview({
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

            int onDutyCount = 0;
            int delayedCount = 0;
            int offDutyCount = 0;

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
                    const Text('Organisatsiooni valmisolek'),
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
                    const SizedBox(height: 8),
                    if (activeMemberships.isEmpty)
                      const Text('Liikmeid ei leitud')
                    else
                      ...activeMemberships.map((membershipDoc) {
                        final membership = membershipDoc.data();
                        final userId = (membership['userId'] ?? '').toString();
                        final availability = availabilityByUserId[userId];
                        final status =
                            availability?.status ?? AvailabilityStatus.offDuty;
                        final responseMinutes = availability?.responseMinutes;

                        return FutureBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          builder: (context, userSnapshot) {
                            final userData = userSnapshot.data?.data() ?? {};
                            final name = (userData['name'] ?? '').toString();
                            final email = (userData['email'] ?? '').toString();
                            final title = name.isNotEmpty
                                ? name
                                : (email.isNotEmpty ? email : userId);
                            final subtitle =
                                status == AvailabilityStatus.delayed &&
                                        responseMinutes != null
                                    ? '$status - $responseMinutes min'
                                    : status;

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(title),
                              subtitle: Text(subtitle),
                            );
                          },
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _reminderTimeOptions(String selectedTime) {
    final times = <String>{
      for (var hour = 0; hour < 24; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
      selectedTime,
    }.toList();

    times.sort();
    return times;
  }

  String _reminderIntervalLabel(int intervalHours) {
    if (intervalHours == 168) return '7 days';
    return '$intervalHours hours';
  }

  Widget _buildEquipmentSection({
    required String organizationId,
    required bool canManageEquipment,
    required String currentUid,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Varustus'),
                ),
                if (canManageEquipment)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Lisa varustus',
                    onPressed: () => _showAddEquipmentDialog(
                      organizationId: organizationId,
                      createdBy: currentUid,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<EquipmentModel>>(
              stream: _equipmentService.streamOrganizationEquipment(
                organizationId: organizationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                if (snapshot.hasError) {
                  return Text('Varustuse laadimine ebaõnnestus: ${snapshot.error}');
                }

                final equipment = snapshot.data ?? const <EquipmentModel>[];
                if (equipment.isEmpty) {
                  return const Text('Varustust ei ole veel lisatud');
                }

                return Column(
                  children: equipment.map((item) {
                    final subtitleParts = [
                      _equipmentCategoryLabel(item.category),
                      _equipmentStatusLabel(item.status),
                      if (item.location.isNotEmpty) item.location,
                    ];

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(subtitleParts.join(' - ')),
                      trailing: item.note.isEmpty
                          ? null
                          : const Icon(Icons.notes),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _equipmentCategoryLabel(String category) {
    switch (category) {
      case EquipmentCategory.vessel:
        return 'Vessel';
      case EquipmentCategory.engine:
        return 'Engine';
      case EquipmentCategory.rescue:
        return 'Rescue';
      case EquipmentCategory.medical:
        return 'Medical';
      case EquipmentCategory.radio:
        return 'Radio';
      case EquipmentCategory.safety:
        return 'Safety';
      default:
        return 'Other';
    }
  }

  String _equipmentStatusLabel(String status) {
    switch (status) {
      case EquipmentStatus.needsMaintenance:
        return 'Needs maintenance';
      case EquipmentStatus.broken:
        return 'Broken';
      case EquipmentStatus.outOfService:
        return 'Out of service';
      default:
        return 'OK';
    }
  }

  Future<void> _updateMembershipRole({
    required String membershipId,
    required String targetUid,
    required String organizationId,
    required String newRole,
  }) async {
    await _membershipService.updateMembershipRole(
      membershipId: membershipId,
      targetUserId: targetUid,
      organizationId: organizationId,
      role: newRole,
    );
  }

  String _membershipRoleFromData(Map<String, dynamic> membership) {
    final role = membership['role'];
    return role is String && role.isNotEmpty ? role : 'member';
  }

  int _roleSortOrder(String role) {
    switch (role) {
      case 'admin':
        return 0;
      case 'boardMember':
        return 1;
      default:
        return 2;
    }
  }

  Widget _buildMembersList({
    required String activeOrganizationId,
    required bool canManageRoles,
    required String currentUid,
  }) {
    return StreamBuilder<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _membershipService.streamActiveMembershipsForOrganization(
        activeOrganizationId,
      ),
      builder: (context, membershipsSnapshot) {
        if (membershipsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (membershipsSnapshot.hasError) {
          return Center(child: Text('Viga: ${membershipsSnapshot.error}'));
        }

        final membershipDocs = membershipsSnapshot.data ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (membershipDocs.isEmpty) {
          return const Center(child: Text('Ühtegi liiget ei leitud'));
        }

        final memberships = membershipDocs
            .where((doc) => (doc.data()['userId'] ?? '').toString().isNotEmpty)
            .toList();

        memberships.sort((a, b) {
          final aRole = _membershipRoleFromData(a.data());
          final bRole = _membershipRoleFromData(b.data());

          return _roleSortOrder(aRole).compareTo(_roleSortOrder(bRole));
        });

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: memberships.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final membershipDoc = memberships[index];
            final membership = membershipDoc.data();
            final targetUid = (membership['userId'] ?? '') as String;
            final membershipRole = _membershipRoleFromData(membership);

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(targetUid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Laen kasutajat...'),
                  );
                }

                if (userSnapshot.hasError) {
                  return ListTile(
                    title: Text('Viga kasutaja laadimisel: ${userSnapshot.error}'),
                  );
                }

                final userData = userSnapshot.data?.data() ?? {};
                final uName = (userData['name'] ?? '') as String;
                final uEmail = (userData['email'] ?? '') as String;
                final uStatus = (userData['status'] ?? 'unavailable') as String;

                final title = uName.isNotEmpty ? uName : uEmail;
                final subtitle = (uStatus == 'available')
                    ? 'Valves / Saadaval'
                    : 'Mitte valves';

                return ListTile(
                  title: Text(title),
                  subtitle: Text('$subtitle • roll: $membershipRole'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        uStatus == 'available'
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: uStatus == 'available'
                            ? const Color.fromARGB(255, 72, 212, 79)
                            : const Color.fromARGB(255, 179, 32, 30),
                      ),
                      if (canManageRoles && targetUid != currentUid) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            try {
                              if (value == 'make_admin') {
                                await _updateMembershipRole(
                                  membershipId: membershipDoc.id,
                                  targetUid: targetUid,
                                  organizationId: activeOrganizationId,
                                  newRole: 'admin',
                                );
                              } else if (value == 'make_board_member') {
                                await _updateMembershipRole(
                                  membershipId: membershipDoc.id,
                                  targetUid: targetUid,
                                  organizationId: activeOrganizationId,
                                  newRole: 'boardMember',
                                );
                              } else if (value == 'make_member') {
                                await _updateMembershipRole(
                                  membershipId: membershipDoc.id,
                                  targetUid: targetUid,
                                  organizationId: activeOrganizationId,
                                  newRole: 'member',
                                );
                              }

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Roll uuendatud')),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Viga: $e')),
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'make_admin',
                              child: Text('Tee adminiks'),
                            ),
                            PopupMenuItem(
                              value: 'make_board_member',
                              child: Text('Tee juhatuse liikmeks'),
                            ),
                            PopupMenuItem(
                              value: 'make_member',
                              child: Text('Tee liikmeks'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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

        final name = (userData['name'] ?? '') as String;

        final activeOrganizationIdFromUser =
            userData['activeOrganizationId'] as String?;
        final activeCommandIdFromUser = userData['activeCommandId'] as String?;
        final legacyCommandIdFromUser = userData['commandId'] as String?;
        final currentActiveIdFromUser = activeOrganizationIdFromUser ??
            activeCommandIdFromUser ??
            legacyCommandIdFromUser;
        final platformRole = (userData['platformRole'] ?? '') as String;
        final isPlatformOwner = platformRole == 'platformOwner';

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
                    currentActiveCommandId: currentActiveIdFromUser,
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
                    currentActiveCommandId: currentActiveIdFromUser,
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
              activeCommandId = _membershipService.resolveActiveOrganizationId(
                userData: userData,
                memberships: membershipDocs,
              );

              final activeMembership = activeCommandId == null
                  ? null
                  : _membershipService.membershipForOrganizationId(
                      organizationId: activeCommandId,
                      memberships: membershipDocs,
                    );
              myMembershipRole = activeMembership == null
                  ? null
                  : _membershipRoleFromData(activeMembership);

              final selectedActiveCommandId = activeCommandId;
              if (selectedActiveCommandId != null &&
                  selectedActiveCommandId.isNotEmpty &&
                  (activeOrganizationIdFromUser != selectedActiveCommandId ||
                      activeCommandIdFromUser != selectedActiveCommandId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await _setActiveCommand(selectedActiveCommandId);
                  } catch (_) {}
                });
              }
            } else {
              activeCommandId = null;
              myMembershipRole = null;
            }

            final canManageRoles = myMembershipRole == 'admin';
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
                      membershipDocs: membershipDocs,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Sa ei ole veel komandoga liitunud. Kasuta ülevalt “Liitu koodiga” või “Loo komando”.',
                      ),
                    ),
                  ],
                ),
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('commands')
                  .doc(activeCommandId)
                  .snapshots(),
              builder: (context, commandSnapshot) {
                final commandData = commandSnapshot.data?.data();
                final commandName = commandData?['name'] as String?;
                final joinCode = commandData?['joinCode'] as String?;

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('RespondCrew'),
                    actions: _buildAppBarActions(
                      membershipDocs: membershipDocs,
                      currentActiveCommandId: activeCommandId,
                      currentCommandName: commandName,
                    ),
                  ),
                  body: ListView(
                    children: [
                      _buildHeaderSection(
                        user: user,
                        displayName: displayName,
                        commandId: activeCommandId,
                        commandName: commandName,
                        joinCode: joinCode,
                        canSeeJoinCode: canSeeJoinCode,
                        isPlatformOwner: isPlatformOwner,
                        membershipRole: myMembershipRole,
                        membershipDocs: membershipDocs,
                      ),
                      _buildMembersList(
                        activeOrganizationId: activeCommandId!,
                        canManageRoles: canManageRoles,
                        currentUid: user.uid,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
