import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/command_service.dart';

class OrganizationCreateDialog extends StatefulWidget {
  const OrganizationCreateDialog({
    super.key,
    this.organizationId,
    this.initialName = '',
    this.initialProfile = const {},
  });
  final String? organizationId;
  final String initialName;
  final Map<String, dynamic> initialProfile;
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
  void initState() {
    super.initState();
    _fields['name']!.text = widget.initialName;
    for (final key in labels.keys.where((key) => key != 'name')) {
      _fields[key]!.text = widget.initialProfile[key]?.toString() ?? '';
    }
  }

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
      if (widget.organizationId != null) {
        await FirebaseFunctions.instanceFor(
          region: 'europe-north1',
        ).httpsCallable('saveOrganizationProfile').call({
          'organizationId': widget.organizationId,
          'name': _fields['name']!.text,
          'revision': widget.initialProfile['revision'] ?? 0,
          'profile': {
            for (final f in _fields.entries)
              if (f.key != 'name') f.key: f.value.text.trim(),
          },
        });
      } else {
        await CommandService().createCommand(
          name: _fields['name']!.text,
          profile: {
            for (final f in _fields.entries)
              if (f.key != 'name') f.key: f.value.text.trim(),
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Salvestamine ebaõnnestus.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Salvestamine ebaõnnestus. Andmed on alles; proovi uuesti.',
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
        widget.organizationId == null ? 'Uue ühingu taotlus' : 'Ühingu andmed',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.organizationId == null)
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
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(value)) {
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
          child: Text(
            _saving
                ? 'Salvestan…'
                : widget.organizationId == null
                ? 'Saada taotlus'
                : 'Salvesta',
          ),
        ),
      ],
    ),
  );
}

Future<void> editOrganizationProfile(
  BuildContext context,
  String organizationId,
) async {
  try {
    final db = FirebaseFirestore.instance;
    final values = await Future.wait([
      db.collection('commands').doc(organizationId).get(),
      db.collection('organizationProfiles').doc(organizationId).get(),
    ]);
    if (!context.mounted) return;
    await showDialog<bool>(
      context: context,
      builder: (_) => OrganizationCreateDialog(
        organizationId: organizationId,
        initialName: values[0].data()?['name'] ?? '',
        initialProfile: values[1].data() ?? {},
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ühingu andmeid ei saanud laadida.')),
      );
    }
  }
}
