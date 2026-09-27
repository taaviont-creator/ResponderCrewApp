import 'package:flutter/material.dart';
import '../models/callout_model.dart';

class CalloutDraft {
  const CalloutDraft({
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.priority,
    this.responseTargetMinutes,
  });
  final String type, title, description, location, priority;
  final int? responseTargetMinutes;
}

class CreateCalloutDialog extends StatefulWidget {
  const CreateCalloutDialog({super.key, required this.onSave});
  final Future<void> Function(CalloutDraft) onSave;
  @override
  State<CreateCalloutDialog> createState() => _CreateCalloutDialogState();
}

class _CreateCalloutDialogState extends State<CreateCalloutDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(text: 'SAR sündmus');
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _target = TextEditingController(text: '60');
  final _applied = <String>{};
  String _type = CalloutType.sar;
  String _priority = CalloutPriority.normal;
  bool _titleEdited = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        CalloutDraft(
          type: _type,
          title: _title.text.trim(),
          description: _description.text.trim(),
          location: _location.text.trim(),
          priority: _priority,
          responseTargetMinutes: _type == CalloutType.tross
              ? int.parse(_target.text.trim())
              : null,
        ),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Väljakutset ei õnnestunud salvestada. Kontrolli ühendust ja proovi uuesti. Sisestatud tekst säilib.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Lisa väljakutse'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Sündmuse tüüp'),
                for (final type in CalloutType.values)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _type = type;
                              if (!_titleEdited) {
                                _title.text = CalloutType.label(type);
                              }
                            }),
                      icon: Icon(
                        _type == type
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      label: Text(CalloutType.label(type)),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  onChanged: (_) => _titleEdited = true,
                  decoration: const InputDecoration(labelText: 'Pealkiri'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Sisesta pealkiri'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Lisa kirjeldusse'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in CalloutType.choices(_type))
                      ActionChip(
                        label: Text(choice, softWrap: true),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onPressed: _saving || _applied.contains(choice)
                            ? null
                            : () => setState(() {
                                _applied.add(choice);
                                if (!_description.text.contains(choice)) {
                                  final text = _description.text;
                                  _description.text =
                                      '$text${text.isEmpty || text.endsWith('\n') || text.endsWith(' ') ? '' : '\n'}$choice';
                                }
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Kirjeldus ja lisainfo',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _location,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Asukoht'),
                ),
                const SizedBox(height: 16),
                if (_type == CalloutType.tross) ...[
                  TextFormField(
                    controller: _target,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Väljasõidu sihtaeg (min)',
                      helperText: 'Aktiveerimisest väljasõiduni, 1–60 minutit.',
                      helperMaxLines: 3,
                    ),
                    validator: (value) =>
                        CalloutType.validTarget(
                          _type,
                          int.tryParse(value?.trim() ?? ''),
                        )
                        ? null
                        : 'Sisesta täisarv 1–60',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TROSSI saab aktiveerida ka ilma kinnitatud reageerijateta. SAR-i koosseisu- ja astmenõuded aktiveerimist ei piira.',
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Prioriteet'),
                  items: const [
                    DropdownMenuItem(
                      value: CalloutPriority.low,
                      child: Text('Madal'),
                    ),
                    DropdownMenuItem(
                      value: CalloutPriority.normal,
                      child: Text('Tavaline'),
                    ),
                    DropdownMenuItem(
                      value: CalloutPriority.high,
                      child: Text('Kõrge'),
                    ),
                    DropdownMenuItem(
                      value: CalloutPriority.critical,
                      child: Text('Kriitiline'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _priority = value!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aktiveerimisel saadetakse liikmetele teavitus. See ei märgi kedagi väljunuks ega pardale.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Salvestan ja ootan serveri kinnitust…'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Katkesta'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvestan…' : 'Aktiveeri väljakutse'),
        ),
      ],
    ),
  );
}
