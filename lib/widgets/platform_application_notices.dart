import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// The pending queue remains actionable; this compact inbox preserves notices
/// after a request has been reviewed.
class PlatformApplicationNotices extends StatefulWidget {
  const PlatformApplicationNotices({super.key});
  @override
  State<PlatformApplicationNotices> createState() =>
      _PlatformApplicationNoticesState();
}

class _PlatformApplicationNoticesState
    extends State<PlatformApplicationNotices> {
  late final _stream = FirebaseFirestore.instance
      .collection('userNotifications')
      .where('organizationId', isEqualTo: 'platform')
      .where(
        'recipientUserId',
        isEqualTo: FirebaseAuth.instance.currentUser!.uid,
      )
      .snapshots();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Taotluste teavituste laadimine ebaõnnestus. Taotlusi näed allolevas nimekirjas.',
        );
      }
      final rows = [...?snapshot.data?.docs];
      if (rows.isEmpty) return const SizedBox.shrink();
      int time(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
          (doc.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      rows.sort((a, b) => time(b).compareTo(time(a)));
      return ExpansionTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Viimased taotluste teavitused'),
        children: [
          for (final row in rows.take(5))
            ListTile(
              title: Text(row.data()['title'] as String? ?? 'Ühingu taotlus'),
              subtitle: Text(row.data()['message'] as String? ?? ''),
            ),
        ],
      );
    },
  );
}
