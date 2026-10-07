import '../widgets/app_layout.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/center_board.dart';

class OrganizationCenterReadinessScreen extends StatefulWidget {
  const OrganizationCenterReadinessScreen({
    super.key,
    this.embedded = false,
    required this.organizationId,
    this.call,
  });
  final String organizationId;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  call;
  final bool embedded;
  @override
  State<OrganizationCenterReadinessScreen> createState() =>
      _OrganizationCenterReadinessScreenState();
}

class _OrganizationCenterReadinessScreenState
    extends State<OrganizationCenterReadinessScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = true, _editing = false, _connected = false;
  Timer? _timer;
  DateTime? _serverAt;
  final _elapsed = Stopwatch()..start();
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (widget.call != null) return widget.call!(name, data);
    final result = await FirebaseFunctions.instanceFor(
      region: 'europe-north1',
    ).httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (!_busy && !_editing && _elapsed.elapsed.inSeconds >= 30) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final result = await _call('getOrganizationCenterReadiness', {
        'organizationId': widget.organizationId,
      });
      if (!mounted) return;
      _data = result;
      _serverAt = DateTime.fromMillisecondsSinceEpoch(
        result['serverNowMs'] as int,
      );
      _connected = true;
      _error = null;
    } catch (e) {
      if (!mounted) return;
      _connected = false;
      if (e is FirebaseFunctionsException &&
          ['permission-denied', 'unauthenticated'].contains(e.code)) {
        _data = null;
      }
      _error =
          'Valmiduse laadimine ebaõnnestus. Kontrolli ühendust ja liikmesust.';
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _elapsed.reset();
        });
      }
    }
  }

  String _time(Object? value) {
    if (value is! int) return 'Puudub';
    final t = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    _editing = true;
    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ConfirmationDialog(row: row),
    );
    _editing = false;
    if (choice == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _call('setOrganizationReadinessConfirmation', {
        'organizationId': widget.organizationId,
        'service': row['service'],
        'settingsRevision': _data!['settingsRevision'],
        'expectedRevision': (row['confirmation'] as Map)['revision'],
        ...choice,
      });
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FirebaseFunctionsException
              ? e.message ?? 'Kinnituse salvestamine ebaõnnestus.'
              : 'Kinnituse salvestamine ebaõnnestus.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Kaart kasutab ühingu valveolekut, meeskonna saadavust ja aluse seisundit. Eraldi kinnitust pole vaja.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final raw in (_data?['entries'] as List? ?? []))
          _entry(Map<String, dynamic>.from(raw as Map)),
      ],
    );
    if (widget.embedded) return content;
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Kaardi staatus'),
        actions: [
          IconButton(
            tooltip: 'Värskenda',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }

  Widget _entry(Map<String, dynamic> row) {
    final item = CenterBoardItem.fromMap(row);
    final at = (_serverAt ?? DateTime.now()).add(_elapsed.elapsed);
    final status = item.effectiveStatus(at, connected: _connected);
    final confirmation = row['confirmation'] as Map;
    final validUntil = confirmation['validUntilMs'];
    final indefinite =
        confirmation['validityMode'] == 'untilChanged' && validUntil == null;
    final confirmedAt = confirmation['confirmedAtMs'];
    final current =
        _connected &&
        confirmedAt is int &&
        confirmedAt <= at.millisecondsSinceEpoch &&
        (indefinite ||
            (validUntil is int && validUntil > at.millisecondsSinceEpoch)) &&
        confirmation['settingsRevision'] == _data!['settingsRevision'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row['service'] == 'sar'
                  ? 'SAR · Merevalvekeskus'
                  : 'Trossi mereabi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              row['enabled'] == true
                  ? status.label
                  : 'Teenus pole sisse lülitatud',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: switch (status) {
                  CenterReadinessStatus.ready => Colors.green.shade800,
                  CenterReadinessStatus.delayed => Colors.orange.shade900,
                  CenterReadinessStatus.unavailable => Colors.red.shade800,
                  CenterReadinessStatus.unknown => Colors.blueGrey.shade700,
                },
              ),
            ),
            for (final reason in item.reasons) Text(reason),
            if (row['enabled'] == true) ...[
              const SizedBox(height: 8),
              Text('Valves ${item.onDutyCount ?? 0} / ${item.minimum ?? '—'}'),
              Text(
                row['automatic'] == true
                    ? 'Automaatne · eraldi kinnitust pole vaja'
                    : confirmation['unavailable'] == true
                    ? 'Admini määratud: teenus pole kättesaadav'
                    : current
                    ? 'Admini määratud viivitus'
                    : 'Määratud viivitus vajab ülevaatamist',
              ),
              if (current && confirmation['expectedReadyAtMs'] is int)
                Text(
                  'Kinnitatud väljasõidu sihtaeg: ${_time(confirmation['expectedReadyAtMs'])}',
                ),
              if ((row['restrictionReason'] as String? ?? '').isNotEmpty)
                Text(row['restrictionReason'] as String),
            ],
            if (_data?['canManage'] == true &&
                (row['enabled'] == true ||
                    confirmation['confirmedAtMs'] != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _busy || !_connected ? null : () => _edit(row),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Muuda teenuse staatust'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationDialog extends StatefulWidget {
  const _ConfirmationDialog({required this.row});
  final Map<String, dynamic> row;
  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  late String _action = widget.row['automatic'] == true
      ? 'withdraw'
      : (widget.row['confirmation'] as Map)['unavailable'] == true
      ? 'unavailable'
      : 'confirm';
  int _delay = 15;
  late final _reason = TextEditingController(
    text: (widget.row['confirmation'] as Map)['reason'] as String? ?? '',
  );
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Teenuse staatus kaardil'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Muudad selle teenuse staatust keskuse kaardil. Sinu isiklik valvesolek ei muutu. Kogu ühingu valve peatamiseks kasuta ühingu valve nuppu.',
            ),
            DropdownButtonFormField<String>(
              itemHeight: null,
              initialValue: _action,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Staatus'),
              items: const [
                DropdownMenuItem(
                  value: 'confirm',
                  child: Text('Reageerime viivitusega'),
                ),
                DropdownMenuItem(
                  value: 'unavailable',
                  child: Text('Teenus pole kättesaadav'),
                ),
                DropdownMenuItem(
                  value: 'withdraw',
                  child: Text('Automaatne, ühingu andmete järgi'),
                ),
              ],
              onChanged: (v) => setState(() => _action = v!),
            ),
            if (_action != 'withdraw') ...[
              const Text(
                'Kättesaamatuse märge kehtib kuni selle eemaldad. Viivitusel määra väljasõidu sihtaeg; vajalik koosseis ja alus peavad olema olemas.',
              ),
              if (_action == 'confirm')
                DropdownButtonFormField<int>(
                  itemHeight: null,
                  initialValue: _delay,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kinnitatud väljasõiduviivitus',
                  ),
                  items: [
                    for (final minutes in [15, 30, 45, 60])
                      DropdownMenuItem(
                        value: minutes,
                        child: Text(
                          minutes == 0
                              ? 'Viivituseta'
                              : '$minutes minuti pärast',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _delay = v!),
                ),
              TextField(
                controller: _reason,
                maxLength: 240,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Keskusele nähtav selgitus',
                  helperText: 'Ära lisa isikuandmeid.',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tühista'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, dynamic>{
          'action': _action,
          'validityMode': 'untilChanged',
          'validForMinutes': null,
          'delayMinutes': _action == 'confirm' ? _delay : 0,
          'reason': _reason.text.trim(),
        }),
        child: const Text('Salvesta'),
      ),
    ],
  );
}
