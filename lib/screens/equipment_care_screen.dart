import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/equipment_model.dart';
import '../models/activity_schedule.dart';
import '../models/statistics_model.dart';
import '../services/equipment_service.dart';
import '../widgets/app_layout.dart';
import '../widgets/status_badge.dart';
import 'contribution_form_screen.dart';

class EquipmentCareScreen extends StatefulWidget {
  const EquipmentCareScreen({
    super.key,
    required this.item,
    required this.organizationId,
    required this.currentUid,
    required this.canManage,
    this.service,
  });
  final EquipmentModel item;
  final String organizationId, currentUid;
  final bool canManage;
  final EquipmentService? service;
  @override
  State<EquipmentCareScreen> createState() => _EquipmentCareScreenState();
}

class _EquipmentCareScreenState extends State<EquipmentCareScreen> {
  late final _service = widget.service ?? EquipmentService();
  late Future<Map<String, dynamic>> _future = _load();
  final _history = <Map<String, dynamic>>[];
  bool _works = false, _moreLoading = false;
  String? _cursor;
  Future<Map<String, dynamic>> _load() async {
    final data = await _service.care(widget.organizationId, widget.item.id);
    _history
      ..clear()
      ..addAll((data['history'] as List? ?? []).map(statisticsMap));
    _cursor = data['nextCursor'] as String?;
    return data;
  }

  void _refresh() => setState(() => _future = _load());
  Future<void> _more() async {
    setState(() => _moreLoading = true);
    try {
      final data = await _service.care(
        widget.organizationId,
        widget.item.id,
        cursor: _cursor,
      );
      if (!mounted) return;
      setState(() {
        final ids = _history.map((h) => h['id']).toSet();
        _history.addAll(
          (data['history'] as List? ?? [])
              .map(statisticsMap)
              .where((h) => !ids.contains(h['id'])),
        );
        _cursor = data['nextCursor'] as String?;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vanema ajaloo laadimine ebaõnnestus.')),
        );
      }
    } finally {
      if (mounted) setState(() => _moreLoading = false);
    }
  }

  Future<void> _condition(Map<String, dynamic> data) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => EquipmentConditionDialog(
        status: data['status'] as String,
        note: data['note'] as String,
        save: (status, note) => _service.setCondition(
          organizationId: widget.organizationId,
          equipmentId: widget.item.id,
          status: status,
          note: note,
          expectedStatus: data['status'] as String,
          expectedNote: data['note'] as String,
        ),
      ),
    );
    if (changed == true && mounted) _refresh();
  }

  Future<void> _work() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionFormScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          canManage: widget.canManage,
          initialType: 'repair',
          initialEquipment: widget.item,
        ),
      ),
    );
    if (saved == true && mounted) {
      _works = true;
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    contentMaxWidth: 900,
    appBar: AppBar(
      title: Text(widget.item.name),
      actions: [
        IconButton(
          tooltip: 'Värskenda',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Varustuse ajaloo laadimine ebaõnnestus.'),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Proovi uuesti'),
                ),
              ],
            ),
          );
        }
        final data = snapshot.data!, status = data['status'] as String;
        final works = (data['works'] as List? ?? [])
            .map(statisticsMap)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              EquipmentCategory.label(widget.item.category),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(
                  label: EquipmentStatus.label(status),
                  type: status == 'ok'
                      ? StatusBadgeType.ready
                      : status == 'needsMaintenance'
                      ? StatusBadgeType.equipmentWarning
                      : StatusBadgeType.critical,
                  icon: status == 'ok'
                      ? Icons.check_circle_outline
                      : Icons.build_outlined,
                ),
                if (data['canEdit'] == true)
                  OutlinedButton.icon(
                    onPressed: () => _condition(data),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Muuda olekut'),
                  ),
              ],
            ),
            if ((data['note'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(data['note'] as String),
              ),
            if (widget.item.category == EquipmentCategory.vessel)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Reageerimisel arvestatakse aluse praegust olekut. Hoolduses või katki olev alus ei ole kasutusvalmis.',
                ),
              ),
            if (!widget.item.isPersonal)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _work,
                  icon: const Icon(Icons.add),
                  label: const Text('Lisa hooldus- või remondipanus'),
                ),
              ),
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Olekute ajalugu'),
                  selected: !_works,
                  onSelected: (_) => setState(() => _works = false),
                ),
                if (!widget.item.isPersonal)
                  ChoiceChip(
                    label: const Text('Hooldus ja remont'),
                    selected: _works,
                    onSelected: (_) => setState(() => _works = true),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_works) ...[
              Text(
                'Kinnitatud töö: ${statisticsHours(works.fold<num>(0, (n, w) => n + (w['confirmedHours'] as num? ?? 0)))}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Inimtunnid · kinnitamata panused koondisse ei lähe. Töö lisamine ei muuda tehnika olekut automaatselt.',
              ),
              if (works.any(
                (w) => (w['crew'] as List? ?? [])
                    .map(statisticsMap)
                    .any((p) => p['confirmed'] == true && p['hours'] == null),
              ))
                const Text(
                  'Mõnel kinnitatud osalemisel puuduvad tunnid. Koond hõlmab ainult teadaolevaid tunde.',
                ),
              if (data['workLimitReached'] == true)
                const Text(
                  'Näidatud kuni 500 seotud tööd; tunnid hõlmavad ainult neid töid.',
                ),
              if (works.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Seotud hooldus- ja remonditöid veel ei ole.'),
                ),
              for (final w in works)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w['title'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${w['type'] == 'repair' ? 'Remont' : 'Hooldus'} · ${ActivitySchedule.format(DateTime.tryParse(w['date'] as String? ?? ''))}',
                        ),
                        if ((w['description'] as String? ?? '').isNotEmpty)
                          Text(w['description'] as String),
                        for (final p in (w['crew'] as List? ?? []).map(
                          statisticsMap,
                        ))
                          Text(
                            '${p['name']} · ${statisticsHours(p['hours'] as num?)}${p['confirmed'] == true ? '' : ' · Ootab kinnitust'}',
                          ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              const Text(
                'Ajalugu koguneb selle funktsiooni kasutuselevõtust. Varasemaid muutmisi ei oletata; uus kirje võib ilmuda väikese viivitusega.',
              ),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Salvestatud muudatusi veel ei ole.'),
                ),
              for (final h in _history) _historyRow(h),
              if (_cursor != null)
                TextButton(
                  onPressed: _moreLoading ? null : _more,
                  child: Text(
                    _moreLoading ? 'Laadin…' : 'Näita vanemat ajalugu',
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
  Widget _historyRow(Map<String, dynamic> h) {
    final before = statisticsMap(h['before'] ?? {}),
        after = statisticsMap(h['after'] ?? {});
    final changed = (h['changed'] as List? ?? []).cast<String>();
    final at = h['occurredAt'] as num?;
    const labels = {
      'note': 'Kommentaar',
      'nextMaintenanceDate': 'Järgmine hooldus',
      'storage': 'Asukoht',
      'assignedToUserId': 'Saaja',
      'assignedToName': 'Saaja nimi',
    };
    String value(Map<String, dynamic> d, String key) {
      final v = d[key] as String? ?? '';
      return key == 'storage'
          ? (v == 'warehouse' ? 'Ladu' : 'Ühiskasutuses')
          : v.isEmpty
          ? '—'
          : v;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ActivitySchedule.format(at == null ? null : DateTime.fromMillisecondsSinceEpoch(at.toInt()))} · ${h['actorName']}',
            ),
            if (changed.contains('status'))
              Text(
                '${before.isEmpty ? 'Lisatud' : EquipmentStatus.label(before['status'] as String? ?? '')} → ${EquipmentStatus.label(after['status'] as String? ?? '')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            for (final field in changed.where(
              (f) => f != 'status' && f != 'assignedToUserId',
            ))
              Text(
                '${labels[field] ?? field}: ${value(before, field)} → ${value(after, field)}',
              ),
          ],
        ),
      ),
    );
  }
}

class EquipmentConditionDialog extends StatefulWidget {
  const EquipmentConditionDialog({
    super.key,
    required this.status,
    required this.note,
    required this.save,
  });
  final String status, note;
  final Future<void> Function(String, String) save;
  @override
  State<EquipmentConditionDialog> createState() =>
      _EquipmentConditionDialogState();
}

class _EquipmentConditionDialogState extends State<EquipmentConditionDialog> {
  late String _status = EquipmentStatus.values.contains(widget.status)
      ? widget.status
      : EquipmentStatus.outOfService;
  late final _note = TextEditingController(text: widget.note);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_status != 'ok' && _note.text.trim().isEmpty) {
      setState(() => _error = 'Kirjelda, mis vajab tegemist.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_status, _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Salvestamine ebaõnnestus.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Salvestamine ebaõnnestus. Sisestatud andmed jäid alles.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Tehnika või varustuse olek'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Olek'),
                items: [
                  for (final s in EquipmentStatus.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(EquipmentStatus.label(s)),
                    ),
                ],
                onChanged: _saving ? null : (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLength: 2000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Probleem või tehtud parandus',
                  hintText: 'Näiteks mootor ei käivitu; ootab remonti.',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Loobu'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvestan…' : 'Salvesta olek'),
        ),
      ],
    ),
  );
}
