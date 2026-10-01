import '../widgets/app_layout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/organization_response_settings_service.dart';

class OrganizationResponseSettingsScreen extends StatefulWidget {
  const OrganizationResponseSettingsScreen({
    super.key,
    this.onSaved,
    this.embedded = false,
    required this.organizationId,
    this.service,
  });
  final String organizationId;
  final OrganizationResponseSettingsService? service;
  final bool embedded;
  final VoidCallback? onSaved;
  @override
  State<OrganizationResponseSettingsScreen> createState() =>
      _OrganizationResponseSettingsScreenState();
}

class _OrganizationResponseSettingsScreenState
    extends State<OrganizationResponseSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _contact = TextEditingController(), _phone = TextEditingController();
  final _departure = {
    'sar': TextEditingController(),
    'tross': TextEditingController(),
  };
  final _minimum = TextEditingController();
  final _enabled = {'sar': false, 'tross': false};
  final _selected = {'sar': <String>{}, 'tross': <String>{}};
  late final _service = widget.service ?? OrganizationResponseSettingsService();
  List<Map<String, dynamic>> _vessels = [];
  bool _loading = true, _saving = false, _loaded = false, _conflict = false;
  int _revision = 0;
  int? _sarMinimum;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _contact,
      _phone,
      _minimum,
      ..._departure.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _message(Object e, String fallback) =>
      e is FirebaseFunctionsException ? e.message ?? fallback : fallback;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loaded = false;
      _error = null;
    });
    try {
      final data = await _service.load(widget.organizationId);
      if (!mounted) return;
      _revision = (data['revision'] as num?)?.toInt() ?? 0;
      _sarMinimum = (data['sarMinimumCrew'] as num?)?.toInt();
      _contact.text = data['contactName'] as String? ?? '';
      _phone.text = data['contactPhone'] as String? ?? '';
      final services = data['services'] as Map? ?? {};
      for (final name in _enabled.keys) {
        final s = services[name] as Map? ?? {};
        _enabled[name] = s['enabled'] == true;
        _departure[name]!.text = s['departureMinutes']?.toString() ?? '';
        _selected[name]!.clear();
        _selected[name]!.addAll(
          (s['vesselIds'] as List? ?? []).whereType<String>(),
        );
        if (name == 'tross') {
          _minimum.text = (s['minimumResponders'] ?? 1).toString();
        }
      }
      _vessels = (data['vessels'] as List? ?? [])
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      _loaded = true;
      _conflict = false;
    } catch (e) {
      _error = _message(
        e,
        'Seadete laadimine ebaõnnestus. Kontrolli ühendust ja admini õigust.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    for (final name in _enabled.keys) {
      if (_enabled[name]! &&
          (_bounded(_departure[name]!, 60) == null ||
              (name == 'tross' && _bounded(_minimum, 50) == null))) {
        setState(
          () => _error =
              'Kontrolli väljasõiduaega (1–60 min) ja Trossi reageerijate arvu (1–50).',
        );
        return;
      }
      if (_selected[name]!.length > 10) {
        setState(() => _error = 'Vali ühe teenuse jaoks kuni 10 alust.');
        return;
      }
      if (_enabled[name]! && _selected[name]!.isEmpty) {
        setState(
          () => _error =
              'Vali ${name == 'sar' ? 'SAR-i' : 'Trossi'} jaoks vähemalt üks alus.',
        );
        return;
      }
    }
    final value = <String, dynamic>{
      'contactName': _contact.text.trim(),
      'contactPhone': _phone.text.trim(),
      'services': {
        for (final name in _enabled.keys)
          name: {
            'enabled': _enabled[name],
            'departureMinutes': _bounded(_departure[name]!, 60),
            'vesselIds': _selected[name]!.toList(),
            if (name == 'tross')
              'minimumResponders': _bounded(_minimum, 50) ?? 1,
          },
      },
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final revision = await _service.save(
        widget.organizationId,
        _revision,
        value,
      );
      if (!mounted) return;
      _revision = revision;
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ühingu teenuste seaded salvestatud.')),
      );
    } catch (e) {
      if (!mounted) return;
      _conflict = e is FirebaseFunctionsException && e.code == 'aborted';
      _error = _conflict
          ? 'Seadeid on vahepeal muudetud. Laadi salvestatud andmed uuesti; sinu salvestamata valikud asendatakse.'
          : _message(
              e,
              'Salvestamine ebaõnnestus. Sisestatud andmed on alles, proovi uuesti.',
            );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _number(String? text, int max) {
    final value = int.tryParse((text ?? '').trim());
    return value == null || value < 1 || value > max
        ? 'Sisesta täisarv 1–$max'
        : null;
  }

  int? _bounded(TextEditingController controller, int max) {
    final value = int.tryParse(controller.text.trim());
    return value != null && value >= 1 && value <= max ? value : null;
  }

  Widget _section(String service, String title) {
    final enabled = _enabled[service]!;
    final selected = _selected[service]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: const Text('Ühing pakub seda teenust'),
              value: enabled,
              onChanged: (value) => setState(() {
                _enabled[service] = value;
                if (value &&
                    service == 'tross' &&
                    _departure[service]!.text.isEmpty) {
                  _departure[service]!.text = '60';
                }
              }),
            ),
            if (enabled) ...[
              if (service == 'sar')
                Text(
                  'Miinimumkoosseis: ${(_sarMinimum ?? 0) > 0 ? _sarMinimum : 'seadistamata'} · vähemalt üks II astme merepäästja. Miinimumi muudad Ühingu valmiduse lehel.',
                ),
              if (service == 'tross') ...[
                const Text(
                  'Trossi tingimused on SAR-ist eraldi. Vähemalt üks sobiv reageerija ja kasutatav alus on vajalikud.',
                ),
                TextFormField(
                  key: const ValueKey('tross-minimum'),
                  controller: _minimum,
                  decoration: const InputDecoration(
                    labelText: 'Trossi minimaalne reageerijate arv',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => _number(v, 50),
                ),
              ],
              TextFormField(
                key: ValueKey('$service-departure'),
                controller: _departure[service],
                decoration: const InputDecoration(
                  labelText: 'Väljasõiduvalmidus (min)',
                  helperText: 'Aeg aktiveerimisest väljasõiduvalmiduseni',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _number(v, 60),
              ),
              const SizedBox(height: 12),
              const Text('Teenuseks kasutatavad alused'),
              const Text(
                'Valik ei tähenda, et alus on praegu korras või teenus reageerimisvalmis.',
              ),
              for (final vessel in _vessels)
                CheckboxListTile(
                  key: ValueKey('$service-${vessel['id']}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(vessel['name'] as String? ?? 'Alus'),
                  subtitle: Text(switch (vessel['status']) {
                    'ok' => 'Korras',
                    'needsMaintenance' => 'Vajab hooldust',
                    'broken' => 'Rikkis',
                    'outOfService' => 'Kasutusest väljas',
                    _ => 'Seisund teadmata',
                  }),
                  value: selected.contains(vessel['id']),
                  onChanged: (v) => setState(() {
                    v == true
                        ? selected.add(vessel['id'] as String)
                        : selected.remove(vessel['id']);
                  }),
                ),
              if (_vessels.isEmpty)
                const Text(
                  'Lisa alus esmalt ühingu varustusse kategooriaga „Alus”.',
                ),
            ],
            for (final missing in selected.where(
              (id) => !_vessels.any((v) => v['id'] == id),
            ))
              CheckboxListTile(
                title: const Text('Varem valitud alus ei ole enam saadaval'),
                subtitle: const Text(
                  'Eemalda aegunud valik enne salvestamist.',
                ),
                value: true,
                onChanged: (_) => setState(() => selected.remove(missing)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : !_loaded
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Andmeid ei õnnestunud laadida.'),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Proovi uuesti'),
                  ),
                ],
              ),
            ),
          )
        : Form(
            key: _form,
            child: ListView(
              shrinkWrap: widget.embedded,
              physics: widget.embedded
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.all(12),
              children: [
                const Text(
                  'Vali pakutavad teenused ja alused. Hetkevalmidus arvutatakse ühingu valveoleku, meeskonna ja aluse seisundi järgi.',
                ),
                const SizedBox(height: 8),
                AbsorbPointer(
                  absorbing: _saving,
                  child: Column(
                    children: [
                      _section('sar', 'SAR'),
                      _section('tross', 'Trossi mereabi'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keskusele jagatav kontakt',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Text(
                                'Keskusele nähtav valvekontakt. Liikmete isiklikke kontakte ei jagata.',
                              ),
                              TextFormField(
                                controller: _contact,
                                maxLength: 120,
                                decoration: const InputDecoration(
                                  labelText: 'Kontakti nimetus',
                                ),
                              ),
                              TextFormField(
                                controller: _phone,
                                maxLength: 60,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Valvetelefon',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_conflict)
                  TextButton(
                    onPressed: _saving ? null : _load,
                    child: const Text('Laadi salvestatud andmed uuesti'),
                  ),
                FilledButton.icon(
                  onPressed: _saving || _conflict ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Salvestan…' : 'Salvesta'),
                ),
              ],
            ),
          );
    if (widget.embedded) return body;
    return PopScope(
      canPop: !_saving,
      child: AppScaffold(
        appBar: AppBar(title: const Text('Teenused ja kontakt')),
        body: body,
      ),
    );
  }
}
