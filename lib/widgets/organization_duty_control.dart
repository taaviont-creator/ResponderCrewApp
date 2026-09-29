import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class OrganizationDutyControl extends StatefulWidget {
  const OrganizationDutyControl({super.key, required this.organizationId});
  final String organizationId;
  @override
  State<OrganizationDutyControl> createState() =>
      _OrganizationDutyControlState();
}

class _OrganizationDutyControlState extends State<OrganizationDutyControl> {
  late final _stream = FirebaseFirestore.instance
      .collection('commands')
      .doc(widget.organizationId)
      .snapshots();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save(bool paused) async {
    if (paused && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Lisa põhjus, mida liikmed avalehel näevad.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-north1',
      ).httpsCallable('setOrganizationDuty').call({
        'organizationId': widget.organizationId,
        'paused': paused,
        'reason': _reason.text,
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? 'Muudatus ebaõnnestus.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Muudatus ebaõnnestus. Proovi uuesti.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Text(
          snapshot.hasError
              ? 'Ühingu valveolekut ei õnnestunud laadida.'
              : 'Laadin ühingu valveolekut…',
        );
      }
      final data = snapshot.data!.data() ?? {},
          paused = data['dutyPaused'] == true;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kogu ühingu valve',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                paused
                    ? 'Ühing on valvest maas. Liikmete valveaja arvestus on peatatud.'
                    : 'Ühingu valve on lubatud. Reageerimisvalmidus sõltub meeskonnast.',
              ),
              const Text(
                'See seade puudutab tervet ühingut. Liikmete isiklikke staatuseid ei muudeta. Koolituste ja tegevuste panuse arvestus jätkub.',
              ),
              if (paused) Text('Põhjus: ${data['dutyPauseReason'] ?? ''}'),
              if (!paused)
                TextField(
                  controller: _reason,
                  enabled: !_saving,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Valve peatamise põhjus (liikmetele nähtav)',
                  ),
                ),
              if (_error != null) Text(_error!),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(!paused),
                icon: Icon(
                  paused ? Icons.play_arrow : Icons.pause_circle_outline,
                ),
                label: Text(
                  paused
                      ? 'Taasta ühingu valve'
                      : 'Võta kogu ühing valvest maha',
                ),
              ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    },
  );
}
