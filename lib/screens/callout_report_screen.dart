import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/callout_model.dart';
import '../models/operation_log_report.dart';
import 'callout_attendance_screen.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map? ?? {});
List<Map<String, dynamic>> _maps(dynamic value) =>
    (value as List? ?? []).map(_map).toList();

class CalloutReportScreen extends StatefulWidget {
  const CalloutReportScreen({
    super.key,
    required this.organizationId,
    required this.calloutId,
    this.loadReport,
    this.saveReport,
  });
  final String organizationId, calloutId;
  final Future<Map<String, dynamic>> Function()? loadReport;
  final Future<void> Function(Map<String, dynamic>)? saveReport;
  @override
  State<CalloutReportScreen> createState() => _CalloutReportScreenState();
}

class _CalloutReportScreenState extends State<CalloutReportScreen> {
  late final _functions = FirebaseFunctions.instanceFor(
    region: 'europe-north1',
  );
  final _summary = TextEditingController(),
      _outcome = TextEditingController(),
      _suggestions = TextEditingController();
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _persons = [];
  Set<String> _equipment = {};
  Map<String, String> _registrations = {};
  String _author = '', _leader = '', _status = 'draft';
  String? _error;
  bool _loading = true, _saving = false, _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summary.dispose();
    _outcome.dispose();
    _suggestions.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loaded = widget.loadReport != null
          ? await widget.loadReport!()
          : _map(
              (await _functions.httpsCallable('getCalloutReport').call({
                'organizationId': widget.organizationId,
                'calloutId': widget.calloutId,
              })).data,
            );
      if (!mounted) return;
      final data = loaded, report = _map(loaded['report']);
      setState(() {
        _data = data;
        _summary.text = data['summary'] ?? '';
        _outcome.text = data['outcome'] ?? '';
        _suggestions.text = report['suggestions'] ?? '';
        _author = report['authorUserId'] ?? '';
        _leader = report['leaderUserId'] ?? '';
        _status = report['status'] ?? 'draft';
        _persons = _maps(data['persons']);
        _equipment = Set<String>.from(report['equipmentIds'] ?? []);
        _registrations = Map<String, String>.from(
          report['equipmentRegistration'] as Map? ?? {},
        );
        _dirty = false;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Aruande laadimine ebaõnnestus. Proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({required bool completed}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'organizationId': widget.organizationId,
        'calloutId': widget.calloutId,
        'operationLogId': _data!['operationLogId'],
        'revision': _map(_data!['report'])['revision'] ?? 0,
        'authorUserId': _author,
        'leaderUserId': _leader,
        'equipmentIds': _equipment.toList(),
        'equipmentRegistration': {
          for (final id in _equipment)
            if (_registrations.containsKey(id)) id: _registrations[id],
        },
        'expectedSummary': _data!['summary'] ?? '',
        'expectedOutcome': _data!['outcome'] ?? '',
        'summary': _summary.text,
        'outcome': _outcome.text,
        'suggestions': _suggestions.text,
        'persons': _persons,
        'status': completed ? 'completed' : 'draft',
      };
      if (widget.saveReport != null) {
        await widget.saveReport!(payload);
      } else {
        await _functions.httpsCallable('saveCalloutReport').call(payload);
      }
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Aruanne salvestatud.')));
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error.message ??
              'Salvestamine ebaõnnestus. Sisestatud andmed on alles.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Salvestamine ebaõnnestus. Sisestatud andmed on alles.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _person({int? index}) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _PersonDialog(initial: index == null ? null : _persons[index]),
    );
    if (value == null || !mounted) return;
    setState(() {
      _dirty = true;
      if (index == null) {
        _persons.add(value);
      } else {
        _persons[index] = value;
      }
    });
  }

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  String _date(dynamic value) => value is String
      ? operationLogEventTime(DateTime.tryParse(value))
      : 'Märkimata';
  Widget _field(String title, TextEditingController controller, bool edit) =>
      edit
      ? Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: controller,
            enabled: !_saving,
            minLines: 2,
            maxLines: null,
            maxLength: 10000,
            onChanged: (_) => setState(() => _dirty = true),
            decoration: InputDecoration(labelText: title),
          ),
        )
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '$title\n${controller.text.isEmpty ? 'Lisamata' : controller.text}',
          ),
        );

  @override
  Widget build(BuildContext context) {
    final data = _data, callout = _map(data?['callout']);
    final edit = data?['canEdit'] == true;
    final members = _maps(data?['members']);
    final authorOptions = members
        .where(
          (m) =>
              m['active'] == true ||
              m['userId'] == _author ||
              m['userId'] == _leader,
        )
        .toList();
    String personName(String uid) =>
        members
            .where((m) => m['userId'] == uid)
            .map((m) => m['name'].toString())
            .firstOrNull ??
        'Määramata';
    return PopScope(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Salvestamata muudatused'),
            content: const Text('Kas lahkud muudatusi salvestamata?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Jätka täitmist'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lahku'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sündmuse aruanne'),
          actions: [
            if (!_dirty)
              IconButton(
                tooltip: 'Värskenda',
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (data != null) ...[
                    Text(
                      _status == 'completed'
                          ? 'Aruanne valmis'
                          : 'Aruande mustand',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    _section('Sündmuse põhiandmed', [
                      Text(callout['title'] ?? ''),
                      Text('Ühing: ${data['organizationName']}'),
                      Text(
                        'Tüüp: ${CalloutType.label(callout['calloutType'] ?? 'sar')}',
                      ),
                      Text('Algus: ${_date(callout['createdAt'])}'),
                      Text('Lõpp: ${_date(callout['closedAt'])}'),
                      Text('Asukoht: ${callout['location'] ?? ''}'),
                      if (callout['latitude'] != null &&
                          callout['longitude'] != null)
                        Text(
                          'GPS: ${callout['latitude']}, ${callout['longitude']}',
                        ),
                      SelectableText('Sündmuse ID: ${widget.calloutId}'),
                    ]),
                    _section('Koostaja ja meeskonna juht', [
                      if (edit) ...[
                        for (final author in [true, false])
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'author-$author-${_map(data['report'])['revision']}',
                            ),
                            initialValue:
                                (author ? _author : _leader).isEmpty ||
                                    !authorOptions.any(
                                      (m) =>
                                          m['userId'] ==
                                          (author ? _author : _leader),
                                    )
                                ? ''
                                : (author ? _author : _leader),
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: author
                                  ? 'Aruande koostaja'
                                  : 'Meeskonna juht',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Vali liige'),
                              ),
                              for (final m in authorOptions)
                                DropdownMenuItem(
                                  value: m['userId'] as String,
                                  child: Text(m['name'].toString()),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) => setState(() {
                                    _dirty = true;
                                    if (author) {
                                      _author = v ?? '';
                                    } else {
                                      _leader = v ?? '';
                                    }
                                  }),
                          ),
                      ] else ...[
                        Text(
                          'Koostaja: ${data['authorName'] ?? personName(_author)}',
                        ),
                        Text(
                          'Juht: ${data['leaderName'] ?? personName(_leader)}',
                        ),
                      ],
                    ]),
                    _section('Kinnitatud meeskond', [
                      if (_maps(
                        data['crew'],
                      ).any((m) => m['levelAtConfirmation'] != true))
                        const Text(
                          'Vanemate osalemiste juures kuvatakse liikme praegune merepääste aste.',
                        ),
                      if (_maps(data['crew']).isEmpty)
                        const Text('Osalejaid pole veel kinnitatud.'),
                      for (final m in _maps(data['crew']))
                        Text(
                          '${m['name']} · ${m['level'] == 'level2'
                              ? 'II aste'
                              : m['level'] == 'level1'
                              ? 'I aste'
                              : 'Aste märkimata'}${m['hours'] == null ? '' : ' · ${m['hours']} t'}',
                        ),
                      if (edit)
                        OutlinedButton.icon(
                          onPressed: _saving || _dirty
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => CalloutAttendanceScreen(
                                        organizationId: widget.organizationId,
                                        calloutId: widget.calloutId,
                                      ),
                                    ),
                                  );
                                  if (mounted) await _load();
                                },
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Lisa / muuda ja kinnita osalejad'),
                        ),
                      if (_dirty)
                        const Text(
                          'Salvesta aruande muudatused enne osalejate vaate avamist.',
                        ),
                    ]),
                    _section('Kasutatud tehnika', [
                      for (final e in _maps(data['equipment']))
                        if (edit)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${e['name']} ${e['registrationNumber']}',
                            ),
                            value: _equipment.contains(e['id']),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() {
                                    _dirty = true;
                                    if (value == true) {
                                      _equipment.add(e['id']);
                                    } else {
                                      _equipment.remove(e['id']);
                                    }
                                  }),
                          )
                        else
                          Text('${e['name']} ${e['registrationNumber']}'),
                      if (_maps(data['equipment']).isEmpty)
                        const Text('Tehnikat pole seotud.'),
                      if (edit)
                        for (final e in _maps(
                          data['equipment'],
                        ).where((e) => _equipment.contains(e['id'])))
                          TextFormField(
                            key: ValueKey(
                              'registration-${e['id']}-${_map(data['report'])['revision']}',
                            ),
                            initialValue:
                                _registrations[e['id']] ??
                                e['registrationNumber'] ??
                                '',
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: '${e['name']} · registreerimisnumber',
                            ),
                            enabled: !_saving,
                            onChanged: (value) => setState(() {
                              _registrations[e['id']] = value;
                              _dirty = true;
                            }),
                          ),
                    ]),
                    _section('Sündmuse kokkuvõte', [
                      if (edit)
                        const Text(
                          'Kirjelda olukorda ja tulemust. Logi tegevusi pole vaja ümber kirjutada. Isikuandmed lisa eraldi seotud isikute alla.',
                        ),
                      _field('Kokkuvõte', _summary, edit),
                      _field('Tulemus', _outcome, edit),
                    ]),
                    _section('Operatsioonilogi', [
                      if (_maps(data['timeline']).isEmpty)
                        const Text('Logikanded puuduvad.'),
                      for (final e in _maps(data['timeline']))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${_date(e['occurredAt'] ?? e['createdAt'])} — ${e['title'] ?? ''}\n${e['text'] ?? e['description'] ?? ''}\n${e['type'] == 'system'
                                ? 'Automaatne sündmuse kirje'
                                : e['type'] == 'manualNote'
                                ? 'Liikme kommentaar'
                                : e['type'] == 'quickAction'
                                ? 'Liikme kiirtegevus'
                                : e['type'] == 'summarySaved'
                                ? 'Kokkuvõtte täiendus'
                                : 'Staatuse kanne'}${e['latitude'] == null ? '' : ' · GPS: ${e['latitude']}, ${e['longitude']}'}',
                          ),
                        ),
                    ]),
                    if (edit)
                      _section('Seotud isikud · piiratud ligipääs', [
                        const Text(
                          'Nähtav ainult ühingu adminile ja II astme merepäästjale.',
                        ),
                        for (var i = 0; i < _persons.length; i++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_persons[i]['name']),
                            subtitle: Text(_persons[i]['role']),
                            onTap: _saving ? null : () => _person(index: i),
                            trailing: IconButton(
                              tooltip: 'Eemalda isik aruandest',
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      _persons.removeAt(i);
                                      _dirty = true;
                                    }),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : () => _person(),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Lisa seotud isik'),
                        ),
                      ]),
                    _section('Ettepanekud ja tähelepanekud', [
                      _field('Ettepanekud / tähelepanekud', _suggestions, edit),
                    ]),
                    if (edit && data['operationLogId'] == null)
                      const Text(
                        'Ava sündmuse op-logi, et saaksid aruande salvestada.',
                      ),
                    if (edit && data['operationLogId'] != null) ...[
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _save(completed: false),
                        child: const Text('Salvesta mustand'),
                      ),
                      if (callout['status'] == 'closed')
                        FilledButton(
                          onPressed: _saving
                              ? null
                              : () => _save(completed: true),
                          child: Text(
                            _status == 'completed'
                                ? 'Salvesta valmis aruande parandused'
                                : 'Märgi aruanne valmis',
                          ),
                        ),
                      if (_saving) const LinearProgressIndicator(),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  static const labels = {
    'name': 'Nimi',
    'contact': 'Kontaktandmed',
    'identifier': 'Isikukood või muu vajalik tunnus',
    'role': 'Roll sündmuses',
    'notes': 'Märkused',
  };
  late final fields = {
    for (final k in labels.keys)
      k: TextEditingController(text: widget.initial?[k] ?? ''),
  };
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Seotud isik'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in fields.entries)
            TextField(
              controller: field.value,
              maxLength: field.key == 'notes' ? 2000 : 300,
              decoration: InputDecoration(labelText: labels[field.key]),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Katkesta'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          for (final f in fields.entries) f.key: f.value.text.trim(),
        }),
        child: const Text('Lisa aruandesse'),
      ),
    ],
  );
}
