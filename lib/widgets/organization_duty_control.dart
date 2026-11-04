import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class OrganizationDutyControl extends StatefulWidget {
  const OrganizationDutyControl({
    super.key,
    required this.organizationId,
    this.onSaved,
  });
  final String organizationId;
  final VoidCallback? onSaved;
  @override
  State<OrganizationDutyControl> createState() =>
      _OrganizationDutyControlState();
}

class _OrganizationDutyControlState extends State<OrganizationDutyControl> {
  late final _stream = FirebaseFirestore.instance
      .collection('commands')
      .doc(widget.organizationId)
      .snapshots();
  bool _saving = false;
  String? _error;

  Future<void> _save(bool paused) async {
    String reason = '';
    if (paused) {
      final form = GlobalKey<FormState>();
      final answer = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('Võta ühing valvest maha'),
        content: SingleChildScrollView(child: Form(key: form, child: TextFormField(
          autofocus: true, maxLength: 1000, minLines: 2, maxLines: 4,
          decoration: const InputDecoration(labelText: 'Põhjus', helperText: 'Teade on liikmetele nähtav.'),
          validator: (value) => (value ?? '').trim().isEmpty ? 'Kirjuta peatamise põhjus.' : null,
          onSaved: (value) => reason = value!.trim(),
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Loobu')),
          FilledButton(onPressed: () {
            if (!form.currentState!.validate()) return;
            form.currentState!.save();
            Navigator.pop(dialog, reason);
          }, child: const Text('Peata valve')),
        ],
      ));
      if (answer == null || !mounted) return;
      reason = answer;
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
        'reason': reason,
      });
      if (mounted) widget.onSaved?.call();
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
              Text(paused ? 'Ühingu valve on peatatud' : 'Ühingu valve on lubatud',
                  style: Theme.of(context).textTheme.titleMedium),
              if (paused) Text('Põhjus: ${data['dutyPauseReason'] ?? ''}'),
              if (_error != null) Text(_error!),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(!paused),
                icon: Icon(
                  paused ? Icons.play_arrow : Icons.pause_circle_outline,
                ),
                label: Text(
                  paused
                      ? 'Taasta ühingu valve'
                      : 'Võta ühing valvest maha',
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
