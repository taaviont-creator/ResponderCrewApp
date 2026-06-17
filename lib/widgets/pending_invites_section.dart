import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/invite_service.dart';

class PendingInvitesSection extends StatefulWidget {
  const PendingInvitesSection({super.key});

  @override
  State<PendingInvitesSection> createState() => _PendingInvitesSectionState();
}

class _PendingInvitesSectionState extends State<PendingInvitesSection> {
  final _inviteService = InviteService();
  late final Future<String?> _normalizedEmailFuture;

  @override
  void initState() {
    super.initState();
    _normalizedEmailFuture = _inviteService.ensureCurrentUserNormalizedEmail();
  }

  Future<void> _acceptInvite(String inviteId) async {
    try {
      await _inviteService.acceptInvite(inviteId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kutse vastu võetud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seda kutset ei saa vastu võtta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _normalizedEmailFuture,
      builder: (context, emailSnapshot) {
        final normalizedEmail = emailSnapshot.data;
        if (emailSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (normalizedEmail == null || normalizedEmail.isEmpty) {
          return _InviteShell(
            child: const Text('Sul ei ole ootel kutseid.'),
          );
        }

        return StreamBuilder<
            List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _inviteService.streamPendingInvitesForEmail(
            normalizedEmail,
          ),
          builder: (context, inviteSnapshot) {
            if (inviteSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            final invites = inviteSnapshot.data ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (invites.isEmpty) {
              return _InviteShell(
                child: const Text('Sul ei ole ootel kutseid.'),
              );
            }

            return _InviteShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sul on ootel kutse ühingusse.'),
                  const SizedBox(height: 12),
                  for (final invite in invites) ...[
                    _InviteTile(
                      invite: invite,
                      onAccept: () => _acceptInvite(invite.id),
                    ),
                    if (invite.id != invites.last.id)
                      const Divider(height: 20),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InviteShell extends StatelessWidget {
  const _InviteShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.invite,
    required this.onAccept,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> invite;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final inviteData = invite.data();
    final organizationId =
        (inviteData['organizationId'] ?? inviteData['commandId'] ?? '')
            .toString();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('commands')
          .doc(organizationId)
          .get(),
      builder: (context, commandSnapshot) {
        final commandData = commandSnapshot.data?.data();
        final organizationName =
            (commandData?['name'] ?? organizationId).toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              organizationName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onAccept,
                child: const Text('Võta kutse vastu'),
              ),
            ),
          ],
        );
      },
    );
  }
}
