import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/equipment_model.dart';
import '../services/equipment_service.dart';

class EquipmentRequestsPanel extends StatefulWidget {
  const EquipmentRequestsPanel({
    super.key,
    required this.organizationId,
    required this.canManage,
    required this.service,
  });
  final String organizationId;
  final bool canManage;
  final EquipmentService service;
  @override
  State<EquipmentRequestsPanel> createState() => _EquipmentRequestsPanelState();
}

class _EquipmentRequestsPanelState extends State<EquipmentRequestsPanel> {
  late Future<Map<String, dynamic>> _future = _load();
  bool _busy = false;
  String? _error;
  Future<Map<String, dynamic>> _load() =>
      widget.service.manage(widget.organizationId, 'list');
  void _refresh() => setState(() => _future = _load());

  Future<void> _review(Map<String, dynamic> row, String action) async {
    if (_busy) return;
    final item = Map<String, dynamic>.from(row['item'] as Map);
    final label = switch (action) {
      'approve' => 'Kinnita',
      'reject' => 'Lükka tagasi',
      _ => 'Tühista taotlus',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label: ${item['name']}'),
        content: SingleChildScrollView(
          child: Text(
            [
              if (action == 'approve')
                'Ese lisatakse ühingu arvestusse ja väljastatakse liikmele. Kontrolli, et sama ese pole juba arvel.',
              'Liige: ${row['submittedByName'] ?? 'Liige'}',
              'Kategooria: ${EquipmentCategory.label(item['category'] as String)}',
              'Olek: ${EquipmentStatus.label(item['status'] as String)}',
              if ((item['location'] as String? ?? '').isNotEmpty)
                'Asukoht: ${item['location']}',
              if ((item['nextMaintenanceDate'] as String? ?? '').isNotEmpty)
                'Järgmine hooldus: ${item['nextMaintenanceDate']}',
              if ((item['note'] as String? ?? '').isNotEmpty)
                'Märkus: ${item['note']}',
            ].join('\n\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tagasi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.manage(
        widget.organizationId,
        action,
        id: row['id'] as String,
      );
      if (mounted) _refresh();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FirebaseFunctionsException
              ? e.message
              : 'Toiming ebaõnnestus. Proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Varustuse taotluste laadimine ebaõnnestus. Proovi uuesti',
            ),
          );
        }
        return const SizedBox.shrink();
      }
      final rows = (snapshot.data!['requests'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (rows.isEmpty && !widget.canManage) return const SizedBox.shrink();
      return ExpansionTile(
        initiallyExpanded: rows.isNotEmpty,
        tilePadding: EdgeInsets.zero,
        title: Text('Kinnitust ootavad esemed (${rows.length})'),
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (rows.isEmpty) const Text('Kinnitust ootavaid esemeid pole.'),
          for (final row in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text((row['item'] as Map)['name'] as String),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.canManage
                        ? '${row['submittedByName']} · Ühingu varustus'
                        : 'Ühingu varustus · Ootab admini kinnitust',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (widget.canManage)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _review(row, 'approve'),
                          child: const Text('Vaata ja kinnita'),
                        ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _review(
                                row,
                                widget.canManage ? 'reject' : 'cancel',
                              ),
                        child: Text(
                          widget.canManage ? 'Lükka tagasi' : 'Tühista taotlus',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Värskenda taotlusi'),
          ),
          if (snapshot.data!['hasMore'] == true)
            const Text(
              'Kuvatud on 100 taotlust. Järgmised ilmuvad pärast nende lahendamist.',
            ),
        ],
      );
    },
  );
}
