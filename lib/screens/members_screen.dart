import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/membership_model.dart';
import '../services/membership_service.dart';

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
  final _membershipService = MembershipService();

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
          child: Text('See vaade on ainult administraatorile'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liikmed'),
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
            return Center(child: Text('Viga: ${membershipsSnapshot.error}'));
          }

          final membershipDocs = membershipsSnapshot.data ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (membershipDocs.isEmpty) {
            return const Center(child: Text('Uhtegi liiget ei leitud'));
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
                    return ListTile(
                      title: Text(
                        'Viga kasutaja laadimisel: ${userSnapshot.error}',
                      ),
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
                                  SnackBar(content: Text('Viga: $e')),
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
