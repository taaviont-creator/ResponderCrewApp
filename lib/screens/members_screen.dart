import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/membership_model.dart';
import '../services/invite_service.dart';
import '../services/membership_service.dart';
import 'member_profile_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canManageRoles,
  });

  final String organizationId;
  final String currentUid;
  final bool canManageRoles;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _inviteService = InviteService();
  final _membershipService = MembershipService();

  Future<void> _showInviteDialog() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kutsu liige'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-post',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Katkesta'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Saada kutse'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (email == null || email.trim().isEmpty) return;

    try {
      await _inviteService.createMemberInvite(
        organizationId: widget.organizationId,
        email: email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kutse loodud.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_inviteErrorMessage(error))),
      );
    }
  }

  String _inviteErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isNotEmpty ? message : 'Kutse loomine ebaõnnestus.';
  }

  Future<void> _updateMembershipRole({
    required String membershipId,
    required String targetUid,
    required String newRole,
  }) async {
    await _membershipService.updateMembershipRole(
      membershipId: membershipId,
      targetUserId: targetUid,
      organizationId: widget.organizationId,
      role: newRole,
    );
  }

  String _membershipRoleFromData(Map<String, dynamic> membership) {
    return MembershipRole.normalize(membership['role']);
  }

  int _roleSortOrder(String role) {
    return MembershipRole.isOrgAdmin(role) ? 0 : 1;
  }

  String _roleLabel(String role) {
    return MembershipRole.isOrgAdmin(role)
        ? 'Organisatsiooni administraator'
        : 'Liige';
  }

  String _seaRescueLevelLabel(Object? level) {
    switch (SeaRescueLevel.normalize(level)) {
      case SeaRescueLevel.level1:
        return 'Merepääste tase 1';
      case SeaRescueLevel.level2:
        return 'Merepääste tase 2';
      default:
        return 'Merepääste pädevus puudub';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canManageRoles) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Liikmed'),
        ),
        body: const Center(
          child: Text('Liikmete ja rollide haldamine on ainult administraatorile.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liikmed'),
        actions: [
          IconButton(
            tooltip: 'Kutsu liige',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _showInviteDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _membershipService.streamActiveMembershipsForOrganization(
          widget.organizationId,
        ),
        builder: (context, membershipsSnapshot) {
          if (membershipsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (membershipsSnapshot.hasError) {
            return const Center(
              child: Text('Liikmete laadimine ebaõnnestus.'),
            );
          }

          final membershipDocs = membershipsSnapshot.data ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (membershipDocs.isEmpty) {
            return const Center(child: Text('Liikmeid ei leitud.'));
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
            padding: const EdgeInsets.all(16),
            itemCount: memberships.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final membershipDoc = memberships[index];
              final membership = membershipDoc.data();
              final targetUid = (membership['userId'] ?? '') as String;
              final membershipRole = _membershipRoleFromData(membership);
              final seaRescueLevel =
                  _seaRescueLevelLabel(membership['seaRescueLevel']);

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
                    return const ListTile(
                      title: Text('Liikme andmete laadimine ebaõnnestus.'),
                    );
                  }

                  final userData = userSnapshot.data?.data() ?? {};
                  final uName = (userData['name'] ?? '') as String;
                  final uEmail = (userData['email'] ?? '') as String;
                  final uStatus =
                      (userData['status'] ?? 'unavailable') as String;

                  final title = uName.isNotEmpty ? uName : uEmail;
                  final subtitle = (uStatus == 'available')
                      ? 'Valves / Saadaval'
                      : 'Mitte valves';

                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberProfileScreen(
                            userData: userData,
                            membershipData: membership,
                          ),
                        ),
                      );
                    },
                    title: Text(title),
                    subtitle: Text(
                      '$subtitle\n'
                      '${_roleLabel(membershipRole)} • $seaRescueLevel',
                    ),
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
                        if (widget.canManageRoles &&
                            targetUid != widget.currentUid) ...[
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              try {
                                if (value == 'make_org_admin') {
                                  await _updateMembershipRole(
                                    membershipId: membershipDoc.id,
                                    targetUid: targetUid,
                                    newRole: MembershipRole.orgAdmin,
                                  );
                                } else if (value == 'make_member') {
                                  await _updateMembershipRole(
                                    membershipId: membershipDoc.id,
                                    targetUid: targetUid,
                                    newRole: MembershipRole.member,
                                  );
                                }

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Roll uuendatud'),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sul puudub õigus seda toimingut teha.',
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'make_org_admin',
                                child: Text(
                                  'Tee organisatsiooni administraatoriks',
                                ),
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
      ),
    );
  }
}
