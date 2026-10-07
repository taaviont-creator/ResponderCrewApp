import '../widgets/app_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/member_directory.dart';
import '../widgets/invite_email_status.dart';
import '../services/member_contact_service.dart';
import 'self_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/availability_model.dart';
import '../models/effective_availability.dart';
import '../models/membership_model.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/availability_service.dart';
import '../services/invite_service.dart';
import '../services/membership_service.dart';
import '../services/planned_unavailability_service.dart';
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
  final _availabilityService = AvailabilityService();
  final _inviteService = InviteService();
  final _membershipService = MembershipService();
  final _plannedUnavailabilityService = PlannedUnavailabilityService();

  Future<void> _showInviteDialog() async {
    final controller = TextEditingController();
    final route = DialogRoute<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kutsu liige'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-post'),
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

    final email = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (email == null || email.trim().isEmpty) return;

    try {
      await _inviteService.createMemberInvite(
        organizationId: widget.organizationId,
        email: email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kutse loodud.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_inviteErrorMessage(error))));
    }
  }

  String _inviteErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isNotEmpty ? message : 'Kutse loomine ebaõnnestus.';
  }

  String? _busyContact;
  Future<void> _contact(String uid, bool sms) async {
    if (_busyContact != null) return;
    setState(() => _busyContact = uid);
    try {
      final uri = await MemberContactService().contactUri(
        organizationId: widget.organizationId,
        userId: uid,
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
              'Kontakti ei saanud avada. Kontrolli, et liikmel on telefoninumber.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyContact = null);
    }
  }

  Future<void> _openMemberProfile({
    required QueryDocumentSnapshot<Map<String, dynamic>> membershipDoc,
    required Map<String, dynamic> membership,
  }) async {
    final targetUid = (membership['userId'] ?? '').toString().trim();
    if (targetUid.isEmpty) return;

    if (targetUid == widget.currentUid) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SelfProfileScreen(
            currentUid: widget.currentUid,
            organizationId: widget.organizationId,
            canManageRoles: widget.canManageRoles,
          ),
        ),
      );
      return;
    }
    try {
      final userSnapshot = widget.canManageRoles
          ? await FirebaseFirestore.instance
                .collection('users')
                .doc(targetUid)
                .get()
          : null;
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberProfileScreen(
            userData:
                userSnapshot?.data() ??
                {
                  'name': _membershipService.safeDisplayNameFromMembership(
                    membership,
                  ),
                },
            membershipData: membership,
            membershipId: membershipDoc.id,
            organizationId: widget.organizationId,
            currentUid: widget.currentUid,
            canManageRoles: widget.canManageRoles,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liikme profiili ei saanud avada.')),
      );
    }
  }

  Widget _buildMembersList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> membershipDocs,
    required Map<String, AvailabilityModel> availabilityByUserId,
    required List<PlannedUnavailabilityModel> periods,
    required List<PlannedUnavailabilityRuleModel> rules,
  }) {
    final byId = {
      for (final doc in membershipDocs) doc.data()['userId'].toString(): doc,
    };
    final now = DateTime.now();
    return MemberDirectory(
      showExport: widget.canManageRoles,
      key: ValueKey(widget.organizationId),
      busyUserId: _busyContact,
      members: [
        for (final doc in membershipDocs)
          DirectoryMember(
            id: doc.data()['userId'].toString(),
            name: _membershipService.safeDisplayNameFromMembership(doc.data()),
            role: MembershipRole.normalize(doc.data()['role']),
            level: SeaRescueLevel.normalize(doc.data()['seaRescueLevel']),
            isSelf: doc.data()['userId'] == widget.currentUid,
            status: switch (EffectiveAvailability.resolve(
              userId: doc.data()['userId'].toString(),
              manualStatus:
                  availabilityByUserId[doc.data()['userId']]?.status ??
                  AvailabilityStatus.offDuty,
              periods: periods,
              rules: rules,
              now: now,
            )) {
              AvailabilityStatus.onDuty => 'Valves',
              AvailabilityStatus.delayed => 'Hilinemisega',
              _ => 'Mitte valves',
            },
          ),
      ],
      onOpen: (uid) {
        final doc = byId[uid];
        if (doc != null) {
          _openMemberProfile(membershipDoc: doc, membership: doc.data());
        }
      },
      onContact: _contact,
      adminSections: widget.canManageRoles
          ? [
              _PendingMemberRequestsSection(
                key: ValueKey(widget.organizationId),
                organizationId: widget.organizationId,
                membershipService: _membershipService,
              ),
              _PendingOrganizationInvitesSection(
                organizationId: widget.organizationId,
                inviteService: _inviteService,
              ),
            ]
          : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Liikmed'),
        actions: [
          if (widget.canManageRoles)
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
          if (membershipsSnapshot.connectionState == ConnectionState.waiting &&
              !membershipsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (membershipsSnapshot.hasError) {
            return const Center(child: Text('Liikmete laadimine ebaõnnestus.'));
          }

          final membershipDocs =
              membershipsSnapshot.data ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (membershipDocs.isEmpty) {
            return const Center(child: Text('Liikmeid ei leitud.'));
          }

          return StreamBuilder<List<AvailabilityModel>>(
            stream: _availabilityService.streamOrganizationAvailability(
              organizationId: widget.organizationId,
            ),
            builder: (context, availabilitySnapshot) {
              final availabilityByUserId = <String, AvailabilityModel>{
                for (final availability
                    in availabilitySnapshot.data ?? const <AvailabilityModel>[])
                  if (availability.userId.isNotEmpty)
                    availability.userId: availability,
              };

              return StreamBuilder<List<PlannedUnavailabilityModel>>(
                stream: _plannedUnavailabilityService.streamOrganizationPeriods(
                  organizationId: widget.organizationId,
                ),
                builder: (context, periodsSnapshot) {
                  return StreamBuilder<List<PlannedUnavailabilityRuleModel>>(
                    stream: _plannedUnavailabilityService
                        .streamOrganizationRules(
                          organizationId: widget.organizationId,
                        ),
                    builder: (context, rulesSnapshot) {
                      if ((availabilitySnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !availabilitySnapshot.hasData) ||
                          (periodsSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !periodsSnapshot.hasData) ||
                          (rulesSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !rulesSnapshot.hasData)) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (availabilitySnapshot.hasError ||
                          periodsSnapshot.hasError ||
                          rulesSnapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Liikmete valmisoleku laadimine ebaõnnestus.',
                          ),
                        );
                      }

                      return _buildMembersList(
                        membershipDocs: membershipDocs,
                        availabilityByUserId: availabilityByUserId,
                        periods:
                            periodsSnapshot.data ??
                            const <PlannedUnavailabilityModel>[],
                        rules:
                            rulesSnapshot.data ??
                            const <PlannedUnavailabilityRuleModel>[],
                      );
                    },
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

class _PendingMemberRequestsSection extends StatefulWidget {
  const _PendingMemberRequestsSection({
    super.key,
    required this.organizationId,
    required this.membershipService,
  });

  final String organizationId;
  final MembershipService membershipService;

  @override
  State<_PendingMemberRequestsSection> createState() =>
      _PendingMemberRequestsSectionState();
}

class _PendingMemberRequestsSectionState
    extends State<_PendingMemberRequestsSection> {
  final _saving = <String>{};
  late final _requests = widget.membershipService.streamPendingMemberRequests(
    widget.organizationId,
  );

  Future<void> _review(String uid, bool approve) async {
    setState(() => _saving.add(uid));
    try {
      await widget.membershipService.reviewMemberRequest(
        organizationId: widget.organizationId,
        targetUserId: uid,
        approve: approve,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Liige kinnitatud.' : 'Taotlus tagasi lükatud.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liitumistaotlust ei saanud muuta.')),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _requests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Liitumistaotluste laadimine ebaõnnestus.');
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Liitumistaotlused',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final request in requests)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  widget.membershipService.safeDisplayNameFromMembership(
                    request.data(),
                  ),
                ),
                subtitle: const Text('Ootab kinnitust'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Lükka tagasi',
                      icon: const Icon(Icons.close),
                      onPressed: _saving.contains(request.data()['userId'])
                          ? null
                          : () => _review(
                              request.data()['userId'] as String,
                              false,
                            ),
                    ),
                    IconButton(
                      tooltip: 'Kinnita liige',
                      icon: const Icon(Icons.check),
                      onPressed: _saving.contains(request.data()['userId'])
                          ? null
                          : () => _review(
                              request.data()['userId'] as String,
                              true,
                            ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PendingOrganizationInvitesSection extends StatelessWidget {
  const _PendingOrganizationInvitesSection({
    required this.organizationId,
    required this.inviteService,
  });

  static const _inviteMessage =
      'Tere! Sind on kutsutud liituma RespondCrew ühinguga. '
      'Palun registreeru või logi sisse sama e-posti aadressiga, '
      'millele kutse saadeti, ning ava äpis kutsete vaade, '
      'et liitumine kinnitada.';

  final String organizationId;
  final InviteService inviteService;

  Future<void> _copyInviteText(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _inviteMessage));

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kutse tekst kopeeritud.')));
  }

  Future<void> _cancelInvite(BuildContext context, String inviteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kas tühistada kutse?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Katkesta'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tühista kutse'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await inviteService.cancelInvite(
        inviteId: inviteId,
        organizationId: organizationId,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kutse tühistatud.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kutset ei saanud tühistada.')),
      );
    }
  }

  String _statusLabel(Object? status) {
    final value = (status ?? '').toString();
    if (value == 'pending') return 'Ootel';
    if (value.isEmpty) return 'Staatus puudub';
    return value;
  }

  String? _formatTimestamp(Object? value) {
    if (value is! Timestamp) return null;

    final date = value.toDate().toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: inviteService.streamPendingInvitesForOrganization(
            organizationId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }

            if (snapshot.hasError) {
              return const Text('Kutsete laadimine ebaõnnestus.');
            }

            final invites =
                snapshot.data ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ootel kutsed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (invites.isEmpty)
                  const Text('Ootel kutseid ei ole.')
                else
                  for (final invite in invites) ...[
                    _PendingOrganizationInviteTile(
                      invite: invite,
                      statusLabel: _statusLabel,
                      formatTimestamp: _formatTimestamp,
                      onCopy: () => _copyInviteText(context),
                      onCancel: () => _cancelInvite(context, invite.id),
                    ),
                    if (invite.id != invites.last.id) const Divider(),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PendingOrganizationInviteTile extends StatelessWidget {
  const _PendingOrganizationInviteTile({
    required this.invite,
    required this.statusLabel,
    required this.formatTimestamp,
    required this.onCopy,
    required this.onCancel,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> invite;
  final String Function(Object? status) statusLabel;
  final String? Function(Object? value) formatTimestamp;
  final VoidCallback onCopy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final data = invite.data();
    final email = (data['email'] ?? 'E-post puudub').toString();
    final details = <String>['Staatus: ${statusLabel(data['status'])}'];
    final expiresAt = formatTimestamp(data['expiresAt']);
    final createdAt = formatTimestamp(data['createdAt']);

    if (expiresAt != null) {
      details.add('Aegub: $expiresAt');
    }
    if (createdAt != null) {
      details.add('Loodud: $createdAt');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(details.join('\n')),
          InviteEmailStatus(invite: invite.reference),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Kopeeri kutse tekst'),
              ),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Tühista kutse'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
