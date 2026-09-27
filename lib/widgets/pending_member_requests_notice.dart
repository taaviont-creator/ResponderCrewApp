import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/membership_service.dart';
import '../screens/members_screen.dart';

/// Display only in organization-admin views; data uses existing membership rules.
class PendingMemberRequestsNotice extends StatefulWidget {
  const PendingMemberRequestsNotice({
    super.key,
    required this.organizationId,
    required this.currentUid,
  });
  final String organizationId;
  final String currentUid;

  @override
  State<PendingMemberRequestsNotice> createState() => _NoticeState();
}

class _NoticeState extends State<PendingMemberRequestsNotice> {
  late Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _requests;
  void _subscribe() {
    _requests = MembershipService().streamPendingMemberRequests(
      widget.organizationId,
    );
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PendingMemberRequestsNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.currentUid != widget.currentUid) {
      _subscribe();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    key: ValueKey('${widget.currentUid}_${widget.organizationId}'),
    stream: _requests,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Liitumistaotluste laadimine ebaõnnestus.');
      }
      final count = snapshot.data?.length ?? 0;
      if (count == 0) return const SizedBox.shrink();
      return Card(
        child: ListTile(
          leading: const Icon(Icons.person_add_alt_1),
          title: Text('Liitumistaotlused ($count)'),
          subtitle: const Text('Liikmed ootavad sinu kinnitust'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MembersScreen(
                organizationId: widget.organizationId,
                currentUid: widget.currentUid,
                canManageRoles: true,
              ),
            ),
          ),
        ),
      );
    },
  );
}
