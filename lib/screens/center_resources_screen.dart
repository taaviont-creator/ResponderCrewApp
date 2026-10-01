import '../widgets/app_layout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class CenterResourcesService {
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'europe-north1',
    ).httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }
}

class CenterResourcesScreen extends StatefulWidget {
  const CenterResourcesScreen({
    super.key,
    this.embedded = false,
    required this.organizationId,
    this.service,
    this.onSaved,
  });
  final String organizationId;
  final CenterResourcesService? service;
  final bool embedded;
  final VoidCallback? onSaved;
  @override
  State<CenterResourcesScreen> createState() => _CenterResourcesScreenState();
}

class _CenterResourcesScreenState extends State<CenterResourcesScreen> {
  late final _service = widget.service ?? CenterResourcesService();
  List<Map<String, dynamic>> _entries = [];
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _service.call('getOrganizationCenterResources', {
        'organizationId': widget.organizationId,
      });
      if (!mounted) return;
      setState(() {
        _entries = (result['entries'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FirebaseFunctionsException
              ? e.message
              : 'Andmete laadimine ebaõnnestus.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(String method, Map<String, dynamic> value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.call(method, {
        'organizationId': widget.organizationId,
        ...value,
      });
      if (mounted) {
        widget.onSaved?.call();
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is FirebaseFunctionsException
              ? e.message
              : 'Salvestamine ebaõnnestus. Proovi uuesti.';
        });
      }
    }
  }

  Future<void> _identity(Map<String, dynamic> row) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VesselIdentityDialog(
        row: row,
        onSave: (value) async {
          await _service.call('saveCenterVesselIdentity', {
            'organizationId': widget.organizationId,
            'resourceId': row['resourceId'],
            'expectedRevision': row['identityRevision'],
            ...value,
          });
        },
      ),
    );
    if (saved == true && mounted) {
      widget.onSaved?.call();
      setState(() => _busy = true);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Aluse registriandmed seovad sama aluse eri kirjed. Liikmeid arvestatakse automaatselt nende valvesoleku järgi.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Kui sama alus on mitme ühingu kasutuses, saab määrata, milline ühing seda kasutab.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Laadi uuesti'),
          ),
        ],
        if (!_busy &&
            _entries.where((e) => e['kind'] == 'vessel').isEmpty &&
            _error == null)
          const Text('Ühingu varustuses pole veel aluseid.'),
        for (final row in _entries.where((e) => e['kind'] == 'vessel'))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['name'] as String,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    row['identityVerified'] == true
                        ? 'Registriandmed kinnitatud · ${row['country']} ${row['registration']}'
                        : 'Registriandmed kinnitamata',
                  ),
                  Text(switch (row['allocation']) {
                    'own' => 'Määratud selle ühingu valmidusse',
                    'other' => 'Määratud teise ühingu valmidusse',
                    _ => 'Eraldi jaotuseta · arvestatakse tegelikku saadavust',
                  }),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (row['releaseOnly'] != true)
                        TextButton(
                          onPressed: _busy ? null : () => _identity(row),
                          child: const Text('Registriandmed'),
                        ),
                      if (row['allocation'] != 'other' &&
                          row['identityVerified'] == true)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _save('setOrganizationCenterResource', {
                                  'kind': 'vessel',
                                  'resourceId': row['resourceId'],
                                  'expectedRevision': row['allocationRevision'],
                                  'action': row['allocation'] == 'own'
                                      ? 'release'
                                      : 'claim',
                                }),
                          child: Text(
                            row['allocation'] == 'own'
                                ? 'Vabasta jaotus'
                                : 'Määra meie ühingule',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (widget.embedded) return content;
    return AppScaffold(
      appBar: AppBar(title: const Text('Aluste registriandmed')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }
}

class _VesselIdentityDialog extends StatefulWidget {
  const _VesselIdentityDialog({required this.row, required this.onSave});
  final Map<String, dynamic> row;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<_VesselIdentityDialog> createState() => _VesselIdentityDialogState();
}

class _VesselIdentityDialogState extends State<_VesselIdentityDialog> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'country': _country.text.toUpperCase(),
        'registration': _registration.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FirebaseFunctionsException
              ? e.message ?? 'Salvestamine ebaõnnestus. Proovi uuesti.'
              : 'Salvestamine ebaõnnestus. Proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  late final _country = TextEditingController(
    text: (widget.row['country'] as String?)?.isNotEmpty == true
        ? widget.row['country'] as String
        : 'EE',
  );
  late final _registration = TextEditingController(
    text: widget.row['registration'] as String? ?? '',
  );
  @override
  void dispose() {
    _country.dispose();
    _registration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Aluse registriandmed'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sisesta tegelikud registriandmed. Sama alus peab kõigis ühingutes kasutama sama registririiki ja registrinumbrit.',
              ),
              if (_saving) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextFormField(
                enabled: !_saving,
                controller: _country,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Registririik (nt EE)',
                ),
                validator: (v) =>
                    RegExp(r'^[A-Z]{2}$').hasMatch((v ?? '').toUpperCase())
                    ? null
                    : 'Sisesta kahetäheline riigikood',
              ),
              TextFormField(
                enabled: !_saving,
                controller: _registration,
                maxLength: 30,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Registrinumber'),
                validator: (v) =>
                    RegExp(r'^[A-Z0-9]{2,30}$').hasMatch(
                      (v ?? '').toUpperCase().replaceAll(RegExp(r'[\s-]'), ''),
                    )
                    ? null
                    : 'Kontrolli registrinumbrit',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Tühista'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvestan…' : 'Kinnitan registriandmed'),
        ),
      ],
    ),
  );
}
