import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class OrganizationPlanning extends StatefulWidget {
  const OrganizationPlanning({super.key, required this.organizationId});
  final String organizationId;
  @override
  State<OrganizationPlanning> createState() => _OrganizationPlanningState();
}

class _OrganizationPlanningState extends State<OrganizationPlanning> {
  List<Map<String, dynamic>>? _rows;
  bool _cancelled = false, _loading = false;
  String? _error;
  Timer? _timer;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void didUpdateWidget(OrganizationPlanning oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) {
      _generation++;
      _rows = null;
      _loading = false;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await FirebaseFunctions.instanceFor(
            region: 'europe-north1',
          ).httpsCallable('getOrganizationReadinessPlanning').call({
            'organizationId': widget.organizationId,
            'includeCancelled': _cancelled,
          });
      if (!mounted || generation != _generation) return;
      setState(
        () => _rows = (result.data['rows'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Planeeringuid ei õnnestunud laadida.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Ühingu planeeritud mittevalved',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const Text('Kõigi liikmete ajad Eesti aja järgi. Enda planeeringuid halda Valmisoleku lehel. Isiklikke märkusi ei jagata.'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Näita tühistatud'),
        value: _cancelled,
        onChanged: _loading
            ? null
            : (value) {
                setState(() => _cancelled = value == true);
                _load();
              },
      ),
      if (_loading && _rows == null) const LinearProgressIndicator(),
      if (_error != null)
        ListTile(
          title: Text(_error!),
          trailing: IconButton(
            tooltip: 'Proovi uuesti',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ),
      if (_rows != null && _rows!.isEmpty)
        const Text('Planeeritud mittevalveid ei ole.'),
      for (final row in _rows ?? <Map<String, dynamic>>[])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            row['recurring'] == true ? Icons.event_repeat : Icons.event_busy,
          ),
          title: Text('${row['name']} · ${row['status']}'),
          subtitle: Text(
            '${row['recurring'] == true ? 'Korduv: ${row['days']} · ' : ''}${row['start']} – ${row['end']}',
          ),
        ),
    ],
  );
}
