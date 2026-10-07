import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/membership_model.dart';
import '../models/callout_model.dart';

class CalloutTestStatusControl extends StatefulWidget {
  const CalloutTestStatusControl({
    super.key,
    required this.callout,
    required this.organizationId,
    required this.userId,
  });
  final CalloutModel callout;
  final String organizationId, userId;
  @override
  State<CalloutTestStatusControl> createState() =>
      _CalloutTestStatusControlState();
}

class _CalloutTestStatusControlState extends State<CalloutTestStatusControl> {
  late final _membership = FirebaseFirestore.instance
      .doc('memberships/${widget.userId}_${widget.organizationId}')
      .snapshots();
  bool _saving = false;
  Future<void> _save(bool value) async {
    setState(() => _saving = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-north1',
      ).httpsCallable('setCalloutTestStatus').call({
        'organizationId': widget.organizationId,
        'calloutId': widget.callout.id,
        'isTest': value,
        'expectedIsTest': widget.callout.isTest,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Proovisündmuse tunnuse salvestamine ebaõnnestus. Proovi uuesti.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _membership,
    builder: (context, snapshot) {
      final m = snapshot.data?.data();
      if (m == null ||
          !MembershipModel.fromMap(id: snapshot.data!.id, data: m).isOrgAdmin) {
        return const SizedBox.shrink();
      }
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Proovisündmus'),
        subtitle: const Text(
          'Ei lähe sündmuste statistikasse ega liikmete panusesse. Tunnuse muutmine ei saada uut häiret.',
        ),
        value: widget.callout.isTest,
        onChanged: _saving ? null : _save,
      );
    },
  );
}
