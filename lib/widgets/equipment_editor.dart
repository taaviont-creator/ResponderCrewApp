import 'package:flutter/material.dart';
import '../models/equipment_model.dart';
import 'app_date_field.dart';

class EquipmentDraft {
  const EquipmentDraft({
    required this.name,
    required this.category,
    required this.status,
    required this.location,
    required this.nextMaintenanceDate,
    required this.note,
  });
  final String name, category, status, location, nextMaintenanceDate, note;
}

/// Keep the form and its controllers alive until the write is acknowledged.
class EquipmentEditor extends StatefulWidget {
  const EquipmentEditor({
    super.key,
    this.existing,
    this.initialCategory = EquipmentCategory.other,
    required this.save,
  });
  final EquipmentModel? existing;
  final String initialCategory;
  final Future<void> Function(EquipmentDraft) save;
  @override
  State<EquipmentEditor> createState() => _EquipmentEditorState();
}

class _EquipmentEditorState extends State<EquipmentEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _location = TextEditingController(
    text: widget.existing?.location ?? '',
  );
  late final _maintenance = TextEditingController(
    text: widget.existing?.nextMaintenanceDate ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _category = EquipmentCategory.normalize(
    widget.existing?.category ?? widget.initialCategory,
  );
  late String _status = widget.existing?.status ?? EquipmentStatus.ok;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _location, _maintenance, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(
        EquipmentDraft(
          name: _name.text.trim(),
          category: _category,
          status: _status,
          location: _location.text.trim(),
          nextMaintenanceDate: _maintenance.text.trim(),
          note: _note.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Salvestamine ebaõnnestus. Andmed jäid vormile alles; proovi uuesti.',
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
      title: Text(
        widget.existing == null ? 'Lisa varustus' : 'Muuda varustust',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: AbsorbPointer(
              absorbing: _saving,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nimetus'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Sisesta nimetus.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(labelText: 'Kategooria'),
                    items: [
                      for (final v in EquipmentCategory.values)
                        DropdownMenuItem(
                          value: v,
                          child: Text(EquipmentCategory.label(v)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  if (widget.existing == null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(labelText: 'Olek'),
                      items: [
                        for (final v in EquipmentStatus.values)
                          DropdownMenuItem(
                            value: v,
                            child: Text(EquipmentStatus.label(v)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Asukoht'),
                  ),
                  const SizedBox(height: 12),
                  AppDateTextField(
                    controller: _maintenance,
                    label: 'Järgmine hooldus või kontroll',
                  ),
                  if (widget.existing == null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      maxLength: 2000,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Selgitus / märkus',
                      ),
                      validator: (v) =>
                          _status != EquipmentStatus.ok &&
                              (v ?? '').trim().isEmpty
                          ? 'Kirjelda probleemi.'
                          : null,
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Tühista'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvestan…' : 'Salvesta'),
        ),
      ],
    ),
  );
}
