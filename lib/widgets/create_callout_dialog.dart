import 'package:flutter/material.dart';
import '../config/release_features.dart';
import '../models/callout_model.dart';

class CalloutDraft {
  const CalloutDraft({
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.priority,
    this.responseTargetMinutes,
    this.phoneCenterId,
  });
  final String type, title, description, location, priority;
  final int? responseTargetMinutes;
  final String? phoneCenterId;
}

class CreateCalloutDialog extends StatefulWidget {
  const CreateCalloutDialog({super.key, required this.onSave});
  final Future<void> Function(CalloutDraft) onSave;
  @override
  State<CreateCalloutDialog> createState() => _CreateCalloutDialogState();
}

class _CreateCalloutDialogState extends State<CreateCalloutDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  String? _type, _error;
  bool _saving = false;
  bool _phone = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final type = _type;
    if (_saving || type == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        CalloutDraft(
          type: type,
          phoneCenterId: _phone && ReleaseFeatures.centers
              ? (type == CalloutType.sar ? 'merevalvekeskus' : 'tross')
              : null,
          title: _title.text.trim().isEmpty
              ? CalloutType.label(type)
              : _title.text.trim(),
          description: _description.text.trim(),
          location: _location.text.trim(),
          priority: type == CalloutType.sar
              ? CalloutPriority.high
              : CalloutPriority.normal,
          responseTargetMinutes: type == CalloutType.tross ? 60 : null,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Väljakutse saatmist ei õnnestunud kinnitada. Kontrolli ühendust ja väljakutsete nimekirja enne uuesti saatmist. Sisestatud info säilib.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Loo väljakutse'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Vali sündmuse tüüp ja alarmeeri oma ühingu meeskond. Info saad lisada hiljem.',
              ),
              for (final type in CalloutType.values)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _type = type),
                    icon: Icon(
                      _type == type
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    label: Text(CalloutType.label(type)),
                  ),
                ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Lisa teadaolev info (valikuline)'),
                children: [
                  TextField(
                    controller: _title,
                    enabled: !_saving,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Pealkiri (valikuline)',
                    ),
                  ),
                  if (_type != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final choice in CalloutType.choices(_type!))
                          ActionChip(
                            label: Text(choice),
                            onPressed: _saving
                                ? null
                                : () {
                                    if (!_description.text.contains(choice)) {
                                      final before = _description.text;
                                      _description.text =
                                          '$before${before.isEmpty ? '' : '\n'}$choice';
                                    }
                                  },
                          ),
                      ],
                    ),
                  TextField(
                    controller: _description,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 6000,
                    decoration: const InputDecoration(
                      labelText: 'Kirjeldus ja lisainfo',
                    ),
                  ),
                  TextField(
                    controller: _location,
                    enabled: !_saving,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Asukoht (valikuline)',
                    ),
                  ),
                  if (ReleaseFeatures.centers)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Keskuse telefonikõne põhjal'),
                      value: _phone,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _phone = v!),
                    ),
                ],
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_saving) const Text('Saadan väljakutset…'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Katkesta'),
        ),
        FilledButton.icon(
          onPressed: _saving || _type == null ? null : _save,
          icon: const Icon(Icons.campaign),
          label: Text(_saving ? 'Saadan…' : 'Alarmeeri meeskond'),
        ),
      ],
    ),
  );
}
