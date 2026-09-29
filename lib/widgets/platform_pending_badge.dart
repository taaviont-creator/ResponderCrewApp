import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Instantiate only in platform-admin navigation. Rules enforce the role.
class PlatformPendingBadge extends StatefulWidget {
  const PlatformPendingBadge({super.key, this.child});
  final Widget? child;
  @override
  State<PlatformPendingBadge> createState() => _PlatformPendingBadgeState();
}

class _PlatformPendingBadgeState extends State<PlatformPendingBadge> {
  late final _stream = FirebaseFirestore.instance
      .collection('commands')
      .where('status', isEqualTo: 'pending')
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          final count = snapshot.data?.size ?? 0;
          return Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: widget.child ?? const Icon(Icons.apartment_outlined),
          );
        },
      );
}
