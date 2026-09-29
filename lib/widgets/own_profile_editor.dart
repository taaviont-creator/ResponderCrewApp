import 'package:flutter/material.dart';
import '../services/member_contact_service.dart';

class OwnProfileEditor extends StatefulWidget {
  const OwnProfileEditor({
    super.key,
    required this.name,
    required this.phone,
    required this.save,
    this.field,
  });
  final String name, phone;
  final String? field;
  final Future<void> Function(String name, String phone) save;
  @override
  State<OwnProfileEditor> createState() => _OwnProfileEditorState();
}

class _OwnProfileEditorState extends State<OwnProfileEditor> {
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(text: widget.phone);
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_name.text.trim(), _phone.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Andmeid ei saanud salvestada. Proovi uuesti.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.field == 'name' ? 'Muuda nime' : widget.field == 'phone' ? 'Muuda telefoninumbrit' : 'Muuda profiili'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.field != 'phone') TextFormField(
                controller: _name,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nimi'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Sisesta nimi.' : null,
              ),
              if (widget.field != 'name') TextFormField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
                validator: (v) =>
                    v != null &&
                        v.trim().isNotEmpty &&
                        phoneContactUri(v, sms: false) == null
                    ? 'Sisesta korrektne telefoninumber.'
                    : null,
              ),
              if (_error != null) Text(_error!),
              if (_saving) const LinearProgressIndicator(),
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
          child: const Text('Salvesta'),
        ),
      ],
    ),
  );
}
