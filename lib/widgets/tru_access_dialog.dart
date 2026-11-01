import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/tru_session.dart';

class TruAccessDialog extends StatefulWidget {
  const TruAccessDialog({super.key, required this.userId, required this.name});
  final String userId, name;
  @override
  State<TruAccessDialog> createState() => _TruAccessDialogState();
}
class _TruAccessDialogState extends State<TruAccessDialog> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-north1');
  bool _busy = true, _active = false, _loaded = false;
  String _role = 'member';
  List<String> _regions = [];
  int _revision = 0;
  int? _validUntilMs;
  String? _error;
  @override
  void initState() {super.initState(); _load();}
  Future<void> _load() async {
    setState(() {_busy = true; _error = null;});
    try {
      final response = await _functions.httpsCallable('getPlatformTruAccess').call({'userId':widget.userId});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _active = data['active'] == true; _role = data['role'] as String;
        _regions = List<String>.from(data['regions'] as List);
        _revision = data['revision'] as int; _validUntilMs = data['validUntilMs'] as int?;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() {_loaded = false; _error = 'TRU liikmesuse laadimine ebaõnnestus.';});
    } finally {if (mounted) setState(() => _busy = false);}
  }
  Future<void> _save() async {
    setState(() {_busy = true; _error = null;});
    try {
      await _functions.httpsCallable('setTruAccess').call({'userId':widget.userId,
        'active':_active, 'role':_role, 'regions':_regions,
        'expectedRevision':_revision, 'validUntilMs':_active ? _validUntilMs : null});
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() {_loaded = false; _error = e.message ?? 'TRU liikmesuse muutmine ebaõnnestus.';});
    } catch (_) {
      if (mounted) setState(() {_loaded = false; _error = 'TRU liikmesuse muutmine ebaõnnestus.';});
    } finally {if (mounted) setState(() => _busy = false);}
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('TRU liikmesus'),
    content: SizedBox(width:460, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.name),
        const Text('TRU liikmesus ei muuda merepääste ega platvormi õigusi.'),
        if (_busy) const LinearProgressIndicator(),
        SwitchListTile(title: const Text('Kinnitatud TRU liige'), value: _active,
          onChanged: _busy || !_loaded ? null : (v) => setState(() => _active = v)),
        DropdownButtonFormField<String>(initialValue:_role, decoration:const InputDecoration(labelText:'TRU roll'),
          items: const [DropdownMenuItem(value:'member', child:Text('Liige')),
            DropdownMenuItem(value:'coordinator', child:Text('Koordinaator')),
            DropdownMenuItem(value:'admin', child:Text('TRU haldur'))],
          onChanged:_busy || !_loaded ? null : (v) => setState(() => _role = v!)),
        for (final r in TruMembership.regionNames) CheckboxListTile(title:Text(r), value:_regions.contains(r),
          onChanged:_busy || !_loaded ? null : (v) => setState(() {if (v == true) {_regions.add(r);} else {_regions.remove(r);}})),
        if (_validUntilMs != null) TextButton(onPressed:_busy ? null : () => setState(() => _validUntilMs = null),
          child: const Text('Muuda tähtajatuks')),
        if (_error != null) Text(_error!),
        TextButton(onPressed:_busy ? null : _load, child: const Text('Laadi uuesti')),
      ]))),
    actions: [TextButton(onPressed:_busy ? null : () => Navigator.pop(context), child:const Text('Loobu')),
      FilledButton(onPressed:_busy || !_loaded || _regions.isEmpty ? null : _save, child:const Text('Salvesta'))]);
}
