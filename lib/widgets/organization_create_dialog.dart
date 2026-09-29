import 'package:flutter/material.dart';
import '../services/command_service.dart';

class OrganizationCreateDialog extends StatefulWidget {
  const OrganizationCreateDialog({super.key});
  @override
  State<OrganizationCreateDialog> createState() =>
      _OrganizationCreateDialogState();
}

class _OrganizationCreateDialogState extends State<OrganizationCreateDialog> {
  static const labels = {
    'name': 'Ametlik nimi *',
    'registrationCode': 'Registrikood',
    'organizationType': 'Organisatsiooni tüüp (nt MTÜ)',
    'region': 'Tegevuspiirkond',
    'address': 'Aadress / asukoht',
    'contactName': 'Kontaktisiku nimi *',
    'contactPhone': 'Kontakttelefon',
    'contactEmail': 'Kontaktisiku e-post *',
    'organizationEmail': 'Ühingu e-post (kui erineb)',
    'description': 'Lühikirjeldus',
    'logoUrl': 'Logo veebiaadress (valikuline)',
  };
  final _form = GlobalKey<FormState>();
  final _fields = {for (final key in labels.keys) key: TextEditingController()};
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CommandService().createCommand(
        name: _fields['name']!.text,
        profile: {
          for (final f in _fields.entries)
            if (f.key != 'name') f.key: f.value.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Ühingu loomine ebaõnnestus. Andmed on alles; proovi uuesti.',
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
      title: const Text('Uue ühingu taotlus'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ühing ootab platvormihalduri kinnitust. Kinnitamisel saab loojast ühingu esimene admin.',
              ),
              for (final entry in labels.entries)
                TextFormField(
                  controller: _fields[entry.key],
                  enabled: !_saving,
                  maxLength: entry.key == 'description' ? 2500 : 300,
                  decoration: InputDecoration(labelText: entry.value),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if ([
                          'name',
                          'contactName',
                          'contactEmail',
                        ].contains(entry.key) &&
                        value.isEmpty) {
                      return 'Täida kohustuslik väli.';
                    }
                    if (entry.key.toLowerCase().contains('email') &&
                        value.isNotEmpty &&
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                      return 'Kontrolli e-posti aadressi.';
                    }
                    if (entry.key == 'logoUrl' &&
                        value.isNotEmpty &&
                        !(Uri.tryParse(value)?.isScheme('https') ?? false)) {
                      return 'Kasuta https-aadressi.';
                    }
                    return null;
                  },
                ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Katkesta'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saadan…' : 'Saada taotlus'),
        ),
      ],
    ),
  );
}
