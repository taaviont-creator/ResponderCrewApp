import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/center_context.dart';
import '../models/center_board.dart';
import '../models/operation_log_model.dart';
import '../services/center_dispatch_service.dart';

class CenterDispatchScreen extends StatelessWidget {
  const CenterDispatchScreen({
    super.key,
    required this.center,
    required this.units,
  });
  final CenterContext center;
  final List<CenterBoardItem> units;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${center.name} · Väljakutsed')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final id = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => DispatchEditor(center: center, units: units),
          ),
        );
        if (id != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CenterDispatchDetail(center: center, units: units, id: id),
            ),
          );
        }
      },
      icon: const Icon(Icons.campaign),
      label: const Text('Loo väljakutse'),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('dispatchIncidents')
          .where('centerId', isEqualTo: center.centerId)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Sündmuste lugemise õigus puudub või ühendus katkes.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!.docs.toList()
          ..sort(
            (a, b) =>
                ((b.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0)
                    .compareTo(
                      (a.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0,
                    ),
          );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (snapshot.data!.metadata.isFromCache)
              const ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text(
                  'Kuvatakse varem laaditud sündmusi. Kontrolli ühendust.',
                ),
              ),
            if (rows.isEmpty)
              const ListTile(title: Text('Keskusel ei ole veel väljakutseid.')),
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text(row.data()['title'] as String),
                  subtitle: Text(
                    '${CenterDispatchService.status(row.data()['status'])} · ${CenterDispatchService.time(row.data()['createdAt'])}${row.data()['isTest'] == true ? ' · PROOV' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CenterDispatchDetail(
                        center: center,
                        units: units,
                        id: row.id,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class CenterDispatchDetail extends StatefulWidget {
  const CenterDispatchDetail({
    super.key,
    required this.center,
    required this.units,
    required this.id,
  });
  final CenterContext center;
  final List<CenterBoardItem> units;
  final String id;
  @override
  State<CenterDispatchDetail> createState() => _CenterDispatchDetailState();
}

class _CenterDispatchDetailState extends State<CenterDispatchDetail> {
  CenterContext get center => widget.center;
  List<CenterBoardItem> get units => widget.units;
  String get id => widget.id;
  Timer? _clock;
  late final _incidentStream = FirebaseFirestore.instance
      .doc('dispatchIncidents/$id')
      .snapshots(includeMetadataChanges: true);
  late final _assignmentsStream = FirebaseFirestore.instance
      .collection('dispatchIncidents/$id/assignments')
      .snapshots();
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Keskuse sündmus')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _incidentStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Sündmuse lugemise õigus puudub või ühendus katkes.'),
          );
        }
        final d = snapshot.data?.data();
        if (d == null) return const Center(child: CircularProgressIndicator());
        final online = !snapshot.data!.metadata.isFromCache;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _assignmentsStream,
          builder: (context, assignments) {
            if (assignments.hasError) {
              return const Center(
                child: Text('Kaasatud ühingute laadimine ebaõnnestus.'),
              );
            }
            final rows = assignments.data?.docs ?? [];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      d['title'] as String,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${CenterDispatchService.status(d['status'])} · Uuendatud ${CenterDispatchService.time(d['updatedAt'])}',
                    ),
                    if (!online)
                      const Text(
                        'Ühendus puudub. Kuvatakse viimati laaditud infot.',
                      ),
                    const SizedBox(height: 12),
                    Text(d['description'] as String),
                    if ((d['radioChannel'] ?? '') != '')
                      Text('JRCC sidekanal: ${d['radioChannel']}'),
                    if ((d['otherResponders'] ?? '') != '')
                      Text('Muud reageerijad: ${d['otherResponders']}'),
                    Text(
                      (d['location'] as String).isEmpty
                          ? 'Asukoht täpsustamisel'
                          : d['location'] as String,
                    ),
                    if (d['position'] is Map)
                      Text(
                        'Koordinaadid: ${d['position']['latitude']}, ${d['position']['longitude']}',
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: !online
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DispatchEditor(
                                      center: center,
                                      units: units,
                                      incident: d,
                                      appendOnly: true,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Lisa infot'),
                        ),
                        OutlinedButton.icon(
                          onPressed: !online
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DispatchEditor(
                                      center: center,
                                      units: units,
                                      incident: d,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Muuda põhiinfot'),
                        ),
                        if (d['status'] == 'active')
                          OutlinedButton.icon(
                            onPressed: !online || !assignments.hasData
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DispatchEditor(
                                        center: center,
                                        units: units
                                            .where(
                                              (u) => !rows.any(
                                                (a) => a.id == u.id,
                                              ),
                                            )
                                            .toList(),
                                        incident: d,
                                        addTargets: true,
                                      ),
                                    ),
                                  ),
                            icon: const Icon(Icons.group_add),
                            label: const Text('Kaasa ühinguid'),
                          ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      'Kaasatud ühingud',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final row in rows)
                      _assignment(context, d, row.data(), online),
                    const SizedBox(height: 20),
                    ExpansionTile(
                      title: const Text('Keskuse muudatuste ajalugu'),
                      children: [
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('dispatchIncidents/$id/updates')
                              .orderBy('createdAt', descending: true)
                              .limit(50)
                              .snapshots(),
                          builder: (context, s) => s.hasError
                              ? const Text('Ajaloo laadimine ebaõnnestus.')
                              : Column(
                                  children: [
                                    for (final r in s.data?.docs ?? [])
                                      ListTile(
                                        title: Text(
                                          r.data()['message'] as String,
                                        ),
                                        subtitle: Text(
                                          '${CenterDispatchService.time(r.data()['createdAt'])} · Kõigile kaasatud ühingutele',
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
  Widget _assignment(
    BuildContext context,
    Map<String, dynamic> incident,
    Map<String, dynamic> a,
    bool online,
  ) {
    final at = a['createdAt'];
    // Proposed first-version warning: 2 min. It is not an acknowledgement deadline.
    final overdue =
        a['response'] == 'pending' &&
        incident['status'] == 'active' &&
        at is Timestamp &&
        DateTime.now().difference(at.toDate()).inMinutes >= 2;
    final unit = units.where((u) => u.id == a['organizationId']).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a['organizationName'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              CenterDispatchService.response(a['response']),
              style: TextStyle(
                color: overdue ? Colors.red.shade800 : null,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (overdue)
              const Text(
                'Ühing ei ole reageerimist kinnitanud. Võta ühinguga ühendust.',
              ),
            if (unit != null && unit.contactPhone.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: unit.contactPhone)),
                icon: const Icon(Icons.call),
                label: Text('Valvekontakt: ${unit.contactPhone}'),
              ),
            if ((a['responseReason'] ?? '') != '')
              Text('Põhjus: ${a['responseReason']}'),
            Text(
              'Meeskonna seis: ${a['progress'] == 'returning' ? 'Tagasisõidul' : OperationLogStatus.label(a['progress'])}',
            ),
            if (a['calloutStatus'] == 'closed' ||
                a['calloutStatus'] == 'cancelled')
              Text(
                'Ühingu väljakutse: ${a['calloutStatus'] == 'closed' ? 'lõpetatud' : 'tühistatud'}',
              ),
            Text(
              'Liikmeid reageerib: ${a['responseCounts']?['responding'] ?? 0} · hilineb: ${a['responseCounts']?['delayed'] ?? 0}',
            ),
            if ((a['criticalRevision'] as num? ?? 0) > 0)
              Text(
                'Oluline info: ${(a['acknowledgedRevision'] ?? 0) >= (a['criticalRevision'] ?? 1) ? 'ühing kinnitas lugemise' : 'lugemise kinnitus puudub'}',
              ),
            Text(
              'Alarmi edastus: ${switch (a['pushStatus']) {
                'accepted' => 'saatmisteenus võttis vastu',
                'partialFailure' => 'osa saatmistest ebaõnnestus',
                'unknown' => 'tulemus teadmata',
                _ => 'kinnitamata',
              }}. See ei kinnita inimese teavitamist.',
            ),
          ],
        ),
      ),
    );
  }
}

class DispatchEditor extends StatefulWidget {
  const DispatchEditor({
    super.key,
    required this.center,
    required this.units,
    this.incident,
    this.appendOnly = false,
    this.addTargets = false,
    this.submit,
    this.initialOrganizationId,
  });
  final CenterContext center;
  final List<CenterBoardItem> units;
  final Map<String, dynamic>? incident;
  final bool addTargets, appendOnly;
  final String? initialOrganizationId;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submit;
  @override
  State<DispatchEditor> createState() => _DispatchEditorState();
}

class _DispatchEditorState extends State<DispatchEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.incident?['title'] ?? '',
  );
  late final _description = TextEditingController(
    text: widget.incident?['description'] ?? '',
  );
  late final _location = TextEditingController(
    text: widget.incident?['location'] ?? '',
  );
  late final _lat = TextEditingController(
    text: widget.incident?['position']?['latitude']?.toString() ?? '',
  );
  late final _lon = TextEditingController(
    text: widget.incident?['position']?['longitude']?.toString() ?? '',
  );
  late final _radioChannel = TextEditingController(
    text: widget.incident?['radioChannel'] ?? '',
  );
  late final _otherResponders = TextEditingController(
    text: widget.incident?['otherResponders'] ?? '',
  );
  final _message = TextEditingController();
  final _selected = <String>{};
  final _existing = <String, TextEditingController>{};
  late String _kind = widget.incident?['positionKind'] ?? 'unknown',
      _status = widget.incident?['status'] ?? 'active';
  final _requestId = CenterDispatchService.requestId();
  bool _busy = false, _critical = false, _test = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.initialOrganizationId != null &&
        widget.units.any((u) => u.id == widget.initialOrganizationId)) {
      _selected.add(widget.initialOrganizationId!);
    }
  }

  bool get _targets => widget.incident == null || widget.addTargets;
  bool get _general => !widget.addTargets && !widget.appendOnly;
  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _location,
      _lat,
      _lon,
      _radioChannel,
      _otherResponders,
      _message,
    ]) {
      c.dispose();
    }
    for (final c in _existing.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_targets && _selected.isEmpty) {
      setState(() => _error = 'Vali vähemalt üks ühing.');
      return;
    }
    Map<String, dynamic>? position;
    if (_lat.text.trim().isNotEmpty || _lon.text.trim().isNotEmpty) {
      final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.')),
          lon = double.tryParse(_lon.text.trim().replaceAll(',', '.'));
      if (lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180 ||
          _kind == 'unknown') {
        setState(
          () =>
              _error = 'Kontrolli mõlemat koordinaati ja vali asukoha täpsus.',
        );
        return;
      }
      position = {'latitude': lat, 'longitude': lon};
    }
    if (_targets) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alarmeeri valitud ühinguid?'),
          content: Text(
            '${_title.text}\n\n${widget.units.where((u) => _selected.contains(u.id)).map((u) => u.name).join('\n')}\n\n${widget.center.service == 'sar' ? 'SAR-häire' : 'Trossi mereabi teavitus'}${_test ? ' · PROOV' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Loobu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Alarmeeri ühinguid'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await (widget.submit ?? CenterDispatchService.send)({
        'action': widget.incident == null
            ? 'create'
            : widget.addTargets
            ? 'addTargets'
            : widget.appendOnly
            ? 'append'
            : 'update',
        'requestId': _requestId,
        'centerId': widget.center.centerId,
        if (widget.incident != null) 'incidentId': widget.incident!['id'],
        if (widget.incident != null)
          'expectedRevision': widget.incident!['revision'],
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _location.text.trim(),
        'radioChannel': _radioChannel.text.trim(),
        'otherResponders': _otherResponders.text.trim(),
        'position': position,
        'positionKind': position == null ? 'unknown' : _kind,
        if (_targets)
          'targets': [
            for (final org in _selected)
              {
                'organizationId': org,
                if ((_existing[org]?.text.trim() ?? '').isNotEmpty)
                  'existingCalloutId': _existing[org]!.text.trim(),
              },
          ],
        if (!_targets) ...{
          'message': _message.text.trim(),
          'critical': _critical,
          'status': _status,
        },
        if (widget.incident == null) 'isTest': _test,
      });
      if (mounted) Navigator.pop(context, result['incidentId'] as String);
    } catch (e) {
      if (mounted) setState(() => _error = CenterDispatchService.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    int lines = 1,
    int max = 6000,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      enabled: !_busy,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 6,
      maxLength: max,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (v) =>
          required && (v ?? '').trim().isEmpty ? 'Täida see väli' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.incident == null
            ? 'Uus keskuse väljakutse'
            : widget.addTargets
            ? 'Kaasa ühinguid'
            : widget.appendOnly
            ? 'Lisa infot'
            : 'Täienda sündmust',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_general) ...[
                _field(_title, 'Sündmuse pealkiri', required: true, max: 200),
                _field(
                  _description,
                  'Mis juhtus? Teadaolev info ja ohud',
                  required: true,
                  lines: 3,
                ),
                _field(
                  _location,
                  'Asukoha kirjeldus (valikuline)',
                  lines: 2,
                  max: 1000,
                ),
                const Text(
                  'Alarmeerida saab ka teadmata asukohaga. Sisesta see info, mis on teada.',
                ),
                ExpansionTile(
                  title: const Text('Koordinaadid (valikulised)'),
                  children: [
                    _field(_lat, 'Laiuskraad · kümnendkraadides', max: 24),
                    _field(_lon, 'Pikkuskraad · kümnendkraadides', max: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _kind,
                      decoration: const InputDecoration(
                        labelText: 'Asukoha täpsus',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'unknown',
                          child: Text('Koordinaadid teadmata'),
                        ),
                        DropdownMenuItem(
                          value: 'approximate',
                          child: Text('Hinnanguline'),
                        ),
                        DropdownMenuItem(
                          value: 'lastKnown',
                          child: Text('Viimane teadaolev'),
                        ),
                        DropdownMenuItem(value: 'exact', child: Text('Täpne')),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _kind = v!),
                    ),
                  ],
                ),
              ],
              if (_general) ...[
                const SizedBox(height: 12),
                _field(_radioChannel, 'JRCC sidekanal (kui teada)', max: 200),
                _field(
                  _otherResponders,
                  'Muud reageerijad (kui teada)',
                  lines: 2,
                  max: 2000,
                ),
              ],
              if (_targets) ...[
                const SizedBox(height: 12),
                const Text('Alarmeeritavad ühingud'),
                if (widget.units.isEmpty)
                  const Text(
                    'Uusi lubatud ühinguid pole. Kontrolli keskusega jagamist.',
                  ),
                for (final u in widget.units)
                  CheckboxListTile(
                    title: Text(u.name),
                    subtitle: Text(u.status.label),
                    value: _selected.contains(u.id),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              _selected.add(u.id);
                            } else {
                              _selected.remove(u.id);
                            }
                          }),
                  ),
                ExpansionTile(
                  title: const Text('Seo telefonitsi saadud väljakutsega'),
                  children: [
                    const Text(
                      'Sisesta ühingu antud olemasoleva väljakutse tunnus. Selle ühingu alarmi ei korrata ning logi säilib.',
                    ),
                    for (final unit in widget.units.where(
                      (u) => _selected.contains(u.id),
                    ))
                      _field(
                        _existing.putIfAbsent(
                          unit.id,
                          () => TextEditingController(),
                        ),
                        '${unit.name}: väljakutse tunnus',
                        max: 128,
                      ),
                  ],
                ),
                if (widget.incident == null)
                  CheckboxListTile(
                    title: const Text('Proovisündmus'),
                    subtitle: const Text(
                      'Ei lähe ametlikku statistikasse. Saadab siiski valitud ühingutele teavituse.',
                    ),
                    value: _test,
                    onChanged: _busy ? null : (v) => setState(() => _test = v!),
                  ),
              ] else ...[
                _field(
                  _message,
                  'Uus info kõigile kaasatud ühingutele',
                  required: true,
                  lines: 2,
                  max: 3000,
                ),
                CheckboxListTile(
                  title: const Text(
                    'Oluline muudatus – vajab ühingu lugemiskinnitust',
                  ),
                  value: _critical,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _critical = v!),
                ),
                if (!widget.appendOnly)
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Keskuse väljakutse seis',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Aktiivne'),
                      ),
                      DropdownMenuItem(
                        value: 'closed',
                        child: Text('Väljakutse lõpetatud'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Väljakutse tühistatud'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _status = v!),
                  ),
                if (!widget.appendOnly)
                  const Text(
                    'Ühingute operatiivlogid jäävad avatuks, et meeskonnad saaksid tagasisõidu ja lõpetamise fikseerida.',
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: Icon(_targets ? Icons.campaign : Icons.send),
                label: Text(
                  _busy
                      ? 'Salvestan…'
                      : _targets
                      ? 'Alarmeeri ühinguid'
                      : 'Saada täiendus',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
