import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

String inviteEmailStatusLabel(String? status) => switch (status) {
  'accepted' => 'Kutse e-kiri on meiliserverile üle antud.',
  'sending' => 'E-kirja saatmine on pooleli. Vajadusel jaga kutse teksti.',
  'failed' => 'E-kirja saatmine ebaõnnestus. Jaga kutse teksti.',
  'unknown' =>
    'E-kirja saatmist ei saanud kinnitada. Vajadusel jaga kutse teksti.',
  _ => 'E-kirja saatmise kinnitus puudub. Vajadusel jaga kutse teksti.',
};

class InviteEmailStatus extends StatelessWidget {
  const InviteEmailStatus({super.key, required this.invite});

  final DocumentReference<Map<String, dynamic>> invite;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: invite.collection('emailDelivery').doc('status').snapshots(),
        builder: (context, snapshot) => Text(
          snapshot.hasError
              ? 'E-kirja saatmise olekut ei saanud laadida.'
              : inviteEmailStatusLabel(
                  snapshot.data?.data()?['status'] as String?,
                ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}
