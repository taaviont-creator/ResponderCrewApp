import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/membership_service.dart';
import 'member_profile_screen.dart';

class SelfProfileScreen extends StatelessWidget {
  const SelfProfileScreen({
    super.key,
    required this.currentUid,
    required this.organizationId,
    required this.canManageRoles,
  });

  final String currentUid;
  final String organizationId;
  final bool canManageRoles;

  @override
  Widget build(BuildContext context) {
    final membershipService = MembershipService();
    final membershipId = membershipService.membershipId(
      userId: currentUid,
      organizationId: organizationId,
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting &&
            !userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnapshot.hasError || userSnapshot.data?.data() == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Minu profiil')),
            body: const Center(child: Text('Profiili ei saanud laadida.')),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('memberships')
              .doc(membershipId)
              .snapshots(),
          builder: (context, membershipSnapshot) {
            if (membershipSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !membershipSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final membership = membershipSnapshot.data?.data();
            if (membershipSnapshot.hasError ||
                membership == null ||
                !membershipService.isActiveMembership(membership) ||
                membershipService.organizationIdFromMembership(membership) !=
                    organizationId) {
              return Scaffold(
                appBar: AppBar(title: const Text('Minu profiil')),
                body: const Center(
                  child: Text('Aktiivse ühingu liikmelisust ei leitud.'),
                ),
              );
            }

            return MemberProfileScreen(
              userData: userSnapshot.data!.data()!,
              membershipData: membership,
              membershipId: membershipId,
              organizationId: organizationId,
              currentUid: currentUid,
              canManageRoles: canManageRoles,
            );
          },
        );
      },
    );
  }
}
