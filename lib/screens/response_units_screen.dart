import '../widgets/app_layout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/response_unit_service.dart';
import '../widgets/rescue_base_dialog.dart';
import '../widgets/response_unit_dialog.dart';
import '../widgets/unit_allocation_dialog.dart';

class ResponseUnitsScreen extends StatefulWidget {
  const ResponseUnitsScreen({
    super.key,
    required this.organizationId,
    this.service,
  });
  final String organizationId;
  final ResponseUnitService? service;
  @override
  State<ResponseUnitsScreen> createState() => _ResponseUnitsScreenState();
}

class _ResponseUnitsScreenState extends State<ResponseUnitsScreen> {
  late final _service = widget.service ?? ResponseUnitService();
  Map<String, dynamic> _data = {};
  bool _busy = true;
  String? _error;
  (String, Map<String, dynamic>)? _failedSave;
  final _sinceLoad = Stopwatch();
  List<Map<String, dynamic>> rows(String key) =>
      ResponseUnitService.rows(_data[key]);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _failedSave = null;
    });
    try {
      final data = await _service.load(widget.organizationId);
      if (mounted) {
        setState(() {
          _data = data;
          _sinceLoad.reset();
          _sinceLoad.start();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _data = {};
          _error =
              'Andmete laadimine ebaõnnestus. Kontrolli ühendust ja ühingu admini õigust.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(
    String method,
    Map<String, dynamic> values, {
    Map<String, dynamic>? previous,
  }) async {
    await _write(method, {
      'organizationId': widget.organizationId,
      'id': previous?['id'] ?? _service.newId(),
      'expectedRevision': previous?['revision'] ?? 0,
      ...values,
    });
  }

  Future<void> _write(String method, Map<String, dynamic> payload) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.save(method, payload);
      if (mounted) await _load();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Salvestamine ebaõnnestus.';
          _failedSave = (method, payload);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Salvestamine ebaõnnestus. Proovi uuesti või värskenda vaadet, et kontrollida salvestatud seisu.';
          _failedSave = (method, payload);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _base([Map<String, dynamic>? value]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RescueBaseDialog(initial: value),
    );
    if (result != null && mounted) {
      await _save('saveRescueBase', result, previous: value);
    }
  }

  Future<void> _unit([Map<String, dynamic>? value]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ResponseUnitDialog(
        initial: value,
        bases: rows('bases').where((b) => b['active'] == true).toList(),
        members: rows('members'),
        vessels: rows('vessels'),
      ),
    );
    if (result != null && mounted) {
      await _save('saveResponseUnit', result, previous: value);
    }
  }

  Future<void> _allocate(Map<String, dynamic> unit) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => UnitAllocationDialog(
        members: rows(
          'members',
        ).where((m) => (unit['memberIds'] as List).contains(m['id'])).toList(),
        vessels: rows(
          'vessels',
        ).where((m) => (unit['vesselIds'] as List).contains(m['id'])).toList(),
      ),
    );
    if (result == null || !mounted) return;
    final hours = result.remove('durationHours') as int;
    final serverNow =
        (_data['serverNowMs'] as num).toInt() + _sinceLoad.elapsedMilliseconds;
    // Leave room for request latency at the server's 24-hour upper bound.
    result['validUntilMs'] =
        serverNow + Duration(hours: hours).inMilliseconds - 5000;
    await _save('setUnitAllocation', result, previous: unit);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(
      title: const Text('Päästebaasid ja üksused'),
      actions: [
        IconButton(
          tooltip: 'Värskenda',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Ettevalmistus keskuste kaardivaateks. Need andmed ei muuda veel ühingu senist valmidusarvutust ega avaldu keskustele.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_failedSave != null)
          TextButton(
            onPressed: _busy
                ? null
                : () => _write(_failedSave!.$1, _failedSave!.$2),
            child: const Text('Proovi salvestamist uuesti'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!),
          ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _base(),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Lisa baas'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || !rows('bases').any((b) => b['active'] == true)
                  ? null
                  : () => _unit(),
              icon: const Icon(Icons.add),
              label: const Text('Lisa üksus'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Päästebaasid', style: Theme.of(context).textTheme.titleLarge),
        if (rows('bases').isEmpty && !_busy)
          const Text('Lisa esmalt päästebaas. Asukoha võib jätta määramata.'),
        for (final b in rows('bases'))
          Card(
            child: ListTile(
              title: Text(b['name'] as String),
              subtitle: Text(
                '${b['active'] == true ? 'Kasutusel' : 'Peatatud'} · ${b['latitude'] == null
                    ? 'Asukoht määramata'
                    : b['positionVerified'] == true
                    ? 'Asukoht kontrollitud'
                    : 'Asukoht kontrollimata'}\n${b['address'] ?? ''}',
              ),
              trailing: IconButton(
                tooltip: 'Muuda baasi',
                onPressed: _busy ? null : () => _base(b),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Reageerivad üksused',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final u in rows('units'))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          u['name'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Muuda üksust',
                        onPressed: _busy ? null : () => _unit(u),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  Text(
                    '${u['active'] == true ? 'Kasutusel' : 'Peatatud'} · ${(u['enabledServices'] as List).map((s) => s == 'sar' ? 'SAR' : 'Tross').join(' / ')}',
                  ),
                  Text(
                    'Võimalik koosseis: ${(u['memberIds'] as List).length} liiget · ${(u['vesselIds'] as List).length} alust',
                  ),
                  for (final a in ResponseUnitService.rows(u['allocations']))
                    Text(
                      '${a['kind'] == 'member' ? 'Liige' : 'Alus'}: ${(rows(a['kind'] == 'member' ? 'members' : 'vessels').where((r) => r['id'] == a['resourceId']).firstOrNull?['name']) ?? 'Kirje pole enam aktiivne'} · kuni ${DateTime.fromMillisecondsSinceEpoch((a['validUntilMs'] as num).toInt()).toLocal()}',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy || u['active'] != true
                            ? null
                            : () => _allocate(u),
                        child: const Text('Määra ressursid'),
                      ),
                      if (ResponseUnitService.rows(u['allocations']).isNotEmpty)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _save('setUnitAllocation', {
                                  'memberIds': <String>[],
                                  'vesselIds': <String>[],
                                  'validUntilMs': null,
                                }, previous: u),
                          child: const Text('Vabasta ressursid'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
