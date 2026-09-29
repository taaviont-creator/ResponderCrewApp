import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/callout_model.dart';

class CalloutEditDialog extends StatefulWidget {
  const CalloutEditDialog({
    super.key,
    required this.callout,
    required this.organizationId,
  });
  final CalloutModel callout;
  final String organizationId;
  @override
  State<CalloutEditDialog> createState() => _CalloutEditDialogState();
}

class _CalloutEditDialogState extends State<CalloutEditDialog> {
  late final _title = TextEditingController(text: widget.callout.title);
  late final _description = TextEditingController(
    text: widget.callout.description,
  );
  late final _location = TextEditingController(text: widget.callout.location);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-north1',
      ).httpsCallable('amendCallout').call({
        'organizationId': widget.organizationId,
        'calloutId': widget.callout.id,
        'version': widget.callout.updatedAt?.millisecondsSinceEpoch ?? 0,
        'title': _title.text,
        'description': _description.text,
        'location': _location.text,
      });
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? 'Salvestamine ebaõnnestus.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Salvestamine ebaõnnestus. Andmed on alles.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Täienda sündmuse andmeid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              enabled: !_saving,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Pealkiri'),
            ),
            TextField(
              controller: _location,
              enabled: !_saving,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Asukoht'),
            ),
            TextField(
              controller: _description,
              enabled: !_saving,
              maxLength: 10000,
              minLines: 3,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Kirjeldus'),
            ),
            const Text('Muudatuse sisu, autor ja aeg jäävad ajalukku.'),
            if (_error != null) Text(_error!),
          ],
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
