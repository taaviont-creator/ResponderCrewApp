import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/callout_model.dart';
import '../services/center_dispatch_service.dart';

class DispatchCalloutPanel extends StatefulWidget {
  const DispatchCalloutPanel({
    super.key,
    required this.callout,
    required this.canManage,
    this.compact = false,
  });
  final CalloutModel callout;
  final bool canManage, compact;
  @override
  State<DispatchCalloutPanel> createState() => _DispatchCalloutPanelState();
}

class _DispatchCalloutPanelState extends State<DispatchCalloutPanel> {
  bool _busy = false;
  String? _error;
  Future<void> _act(String action, {String? response}) async {
    String reason = '';
    if (response == 'declined') {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ühing ei saa reageerida'),
          content: TextField(
            controller: controller,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Põhjus'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Loobu'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Teavita keskust'),
            ),
          ],
        ),
      );
      // The closing dialog can still paint its text field during the animation.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      if (value == null || !mounted) return;
      reason = value;
    }
    final d = widget.callout.dispatch!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CenterDispatchService.send({
        'action': action,
        'requestId': CenterDispatchService.requestId(),
        'incidentId': d['incidentId'],
        'organizationId': widget.callout.organizationId,
        'expectedRevision': d['revision'],
        'expectedResponse': d['response'],
        'response': ?response,
        'reason': reason,
      });
    } catch (e) {
      if (mounted) setState(() => _error = CenterDispatchService.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _history() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            const ListTile(title: Text('Keskuse täiendused')),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('callouts/${widget.callout.id}/centerUpdates')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, s) {
                  if (s.hasError) {
                    return const Center(
                      child: Text('Täienduste laadimine ebaõnnestus.'),
                    );
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    children: [
                      if (s.data!.docs.isEmpty)
                        const ListTile(title: Text('Täiendusi veel pole.')),
                      for (final row in s.data!.docs)
                        ListTile(
                          leading: Icon(
                            row.data()['critical'] == true
                                ? Icons.priority_high
                                : Icons.info_outline,
                          ),
                          title: Text(row.data()['text'] as String),
                          subtitle: Text(
                            CenterDispatchService.time(row.data()['createdAt']),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final d = widget.callout.dispatch;
    if (d == null) return const SizedBox.shrink();
    final unread =
        (d['acknowledgedRevision'] as num? ?? 0) <
        (d['criticalRevision'] as num? ?? 0);
    final inactive = d['incidentStatus'] != 'active';
    final canAct = widget.canManage && !widget.callout.isFromCache;
    final p = d['position'];
    return Card(
      color: inactive || (d['critical'] == true && unread)
          ? Theme.of(context).colorScheme.errorContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d['centerName']} · ${CenterDispatchService.status(d['incidentStatus'])}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Uuendatud ${CenterDispatchService.time(d['updatedAt'])}'),
            if (widget.callout.isFromCache)
              const Text(
                'Ühendus pole kinnitatud. Kuvatakse viimati laaditud infot.',
              ),
            if ((d['radioChannel'] ?? '') != '')
              Text(
                'JRCC sidekanal: ${d['radioChannel']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if ((d['otherResponders'] ?? '') != '')
              Text('Muud reageerijad: ${d['otherResponders']}'),
            for (final org
                in (d['organizations'] as List? ?? const []).whereType<Map>())
              if (org['organizationId'] != widget.callout.organizationId)
                Text(
                  '${org['name']} · ${CenterDispatchService.response(org['response'])}',
                ),
            if (inactive)
              const Text(
                'Keskuse väljakutse ei ole enam aktiivne. Fikseeri tagasisõit ja lõpeta oma ühingu logi.',
              ),
            Text(d['message'] as String? ?? ''),
            if ((d['criticalRevision'] as num? ?? 0) >
                    (d['acknowledgedRevision'] as num? ?? 0) &&
                d['criticalMessage'] != d['message'])
              Text(
                'Oluline varasem täiendus: ${d['criticalMessage']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (!widget.compact) ...[
              Text(CenterDispatchService.response(d['response'])),
              if ((d['responseReason'] ?? '') != '')
                Text('Põhjus: ${d['responseReason']}'),
              if (p is Map)
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': '${p['latitude']},${p['longitude']}',
                    }),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    '${switch (d['positionKind']) {
                      'approximate' => 'Hinnanguline asukoht',
                      'lastKnown' => 'Viimane teadaolev asukoht',
                      _ => 'Asukoht',
                    }}: ${p['latitude']}, ${p['longitude']}',
                  ),
                ),
              if (p == null && widget.callout.location.isEmpty)
                const Text(
                  'Asukoht täpsustamisel. Lähtu teadaolevast sündmuse infost.',
                ),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (canAct &&
                    !widget.compact &&
                    !inactive &&
                    widget.callout.status == CalloutStatus.active) ...[
                  if (d['response'] != 'accepted')
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _act('respond', response: 'accepted'),
                      child: const Text('Ühing reageerib'),
                    ),
                  if (d['response'] != 'declined')
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _act('respond', response: 'declined'),
                      child: const Text('Ühing ei saa reageerida'),
                    ),
                ],
                if (canAct && unread)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _act('acknowledge'),
                    icon: const Icon(Icons.done),
                    label: const Text('Kinnita info loetuks'),
                  ),
                TextButton(
                  onPressed: _history,
                  child: const Text('Kõik keskuse täiendused'),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
