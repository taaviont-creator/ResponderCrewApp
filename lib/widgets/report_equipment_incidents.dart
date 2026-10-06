import 'package:flutter/material.dart';

class ReportEquipmentIncidents extends StatelessWidget {
  const ReportEquipmentIncidents({
    super.key,
    required this.items,
    this.onChanged,
    this.busy = false,
  });
  final List<Map<String, dynamic>> items;
  final ValueChanged<List<Map<String, dynamic>>>? onChanged;
  final bool busy;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _IncidentDialog(initial: index == null ? null : items[index]),
    );
    if (value == null || !context.mounted) return;
    final next = [for (final item in items) Map<String, dynamic>.from(item)];
    if (index == null) {
      next.add(value);
    } else {
      next[index] = value;
    }
    onChanged?.call(next);
  }

  Future<void> _remove(BuildContext context, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eemalda varustuse juhtum?'),
        content: Text(items[index]['name'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tagasi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eemalda'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      onChanged?.call([...items]..removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Kahjustatud või kaotatud varustus',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      if (items.isEmpty) const Text('Kahjustusi ega kaotusi pole märgitud.'),
      for (var i = 0; i < items.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            items[i]['status'] == 'lost'
                ? Icons.search_off
                : Icons.build_outlined,
          ),
          title: Text(
            '${items[i]['name']} · ${items[i]['status'] == 'lost' ? 'Kaotatud' : 'Kahjustatud'}',
          ),
          subtitle: Text('${items[i]['description']}'),
          onTap: onChanged == null || busy ? null : () => _edit(context, i),
          trailing: onChanged == null
              ? null
              : IconButton(
                  tooltip: 'Eemalda juhtum',
                  onPressed: busy ? null : () => _remove(context, i),
                  icon: const Icon(Icons.delete_outline),
                ),
        ),
      if (onChanged != null) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy || items.length >= 50 ? null : () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Lisa kahjustus või kaotus'),
          ),
        ),
        const Text(
          'Kirjeldus lisatakse aruandesse. Varustuse registri seisundit see automaatselt ei muuda.',
        ),
      ],
    ],
  );
}

class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog({this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?['name'] ?? '');
  late final _description = TextEditingController(
    text: widget.initial?['description'] ?? '',
  );
  late String _status = widget.initial?['status'] ?? 'damaged';
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Varustuse kahjustus või kaotus'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Varustuse nimetus',
                  hintText: 'Näiteks käsiraadio',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Sisesta varustuse nimetus.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Juhtum'),
                items: const [
                  DropdownMenuItem(
                    value: 'damaged',
                    child: Text('Kahjustatud'),
                  ),
                  DropdownMenuItem(value: 'lost', child: Text('Kaotatud')),
                ],
                onChanged: (value) => setState(() => _status = value!),
              ),
              TextFormField(
                controller: _description,
                maxLength: 2000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Mis juhtus?',
                  hintText: 'Raadio kukkus üle parda ja jäi kadunuks.',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Kirjelda juhtunut.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tühista'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'status': _status,
              'description': _description.text.trim(),
            });
          }
        },
        child: Text(
          widget.initial == null ? 'Lisa aruandesse' : 'Salvesta kirje',
        ),
      ),
    ],
  );
}
