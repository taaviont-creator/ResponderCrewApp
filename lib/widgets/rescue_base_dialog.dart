import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RescueBaseDialog extends StatefulWidget {
  const RescueBaseDialog({
    super.key,
    this.initial,
    this.organizationLocation = false,
    this.onSave,
  });
  final Map<String, dynamic>? initial;
  final bool organizationLocation;
  final Future<void> Function(Map<String, dynamic>)? onSave;
  @override
  State<RescueBaseDialog> createState() => _RescueBaseDialogState();
}

class _RescueBaseDialogState extends State<RescueBaseDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?['name'] as String? ?? '',
  );
  late final _address = TextEditingController(
    text: widget.initial?['address'] as String? ?? '',
  );
  late final _latitude = TextEditingController(
    text: widget.initial?['latitude']?.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.initial?['longitude']?.toString() ?? '',
  );
  late bool _verified = widget.initial?['positionVerified'] == true;
  late bool _active = widget.initial?['active'] != false;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _address, _latitude, _longitude]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  String? _coordinate(String? value, bool latitude) {
    final own = (value ?? '').trim(),
        other = (latitude ? _longitude : _latitude).text.trim();
    if (own.isEmpty && other.isEmpty) return null;
    final n = _number(own), max = latitude ? 90 : 180;
    return n == null || !n.isFinite || n.abs() > max
        ? 'Sisesta korrektne ${latitude ? 'laius' : 'pikkus'}kraad'
        : null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.organizationLocation
            ? 'Ühingu asukoht kaardil'
            : widget.initial == null
            ? 'Lisa päästebaas'
            : 'Muuda päästebaasi',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.organizationLocation)
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Päästebaasi nimi',
                      ),
                      maxLength: 120,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Sisesta nimi' : null,
                    ),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Aadress või asukoha kirjeldus',
                    ),
                    maxLength: 300,
                  ),
                  const Text(
                    'Sisesta baasi tegelikud WGS84 koordinaadid. Kui asukoht pole teada, jäta mõlemad väljad tühjaks.',
                  ),
                  TextFormField(
                    controller: _latitude,
                    decoration: const InputDecoration(labelText: 'Laiuskraad'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinate(v, true),
                    onChanged: (_) => setState(() => _verified = false),
                  ),
                  TextFormField(
                    controller: _longitude,
                    decoration: const InputDecoration(labelText: 'Pikkuskraad'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinate(v, false),
                    onChanged: (_) => setState(() => _verified = false),
                  ),
                  if (_number(_latitude.text) != null &&
                      _number(_longitude.text) != null &&
                      (_number(_latitude.text)! < 57 ||
                          _number(_latitude.text)! > 60.5 ||
                          _number(_longitude.text)! < 21 ||
                          _number(_longitude.text)! > 29))
                    const Text(
                      'Koordinaat jääb Eesti tavapärasest piirkonnast välja. Kontrolli, et laius- ja pikkuskraad pole vahetuses.',
                    ),
                  if (widget.organizationLocation)
                    const Text(
                      'Salvestamisel kinnitad, et need on ühingu päästebaasi tegelikud koordinaadid. Nende järgi kuvatakse kaardipunkt.',
                    )
                  else
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Olen baasi asukoha üle kontrollinud'),
                      value: _verified,
                      onChanged: (value) =>
                          setState(() => _verified = value ?? false),
                    ),
                  if (widget.initial != null && !widget.organizationLocation)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Baas on kasutusel'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
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
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Katkesta'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  final lat = _number(_latitude.text),
                      lon = _number(_longitude.text);
                  final value = <String, dynamic>{
                    if (!widget.organizationLocation) 'name': _name.text.trim(),
                    'address': _address.text.trim(),
                    'latitude': lat,
                    'longitude': lon,
                    'positionVerified':
                        lat != null &&
                        lon != null &&
                        (widget.organizationLocation || _verified),
                    if (!widget.organizationLocation) 'active': _active,
                  };
                  if (widget.onSave == null) {
                    Navigator.pop(context, value);
                    return;
                  }
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await widget.onSave!(value);
                  } catch (error) {
                    if (!mounted) return;
                    setState(() {
                      _saving = false;
                      _error = error is FirebaseFunctionsException
                          ? error.code == 'aborted'
                                ? 'Andmeid on vahepeal muudetud. Sulge vorm ja ava uuesti.'
                                : error.message ??
                                      'Salvestamine ebaõnnestus. Proovi uuesti.'
                          : 'Salvestamine ebaõnnestus. Proovi uuesti.';
                    });
                    return;
                  }
                  if (!context.mounted) return;
                  setState(() => _saving = false);
                  Navigator.pop(context, value);
                },
          child: Text(_saving ? 'Salvestan…' : 'Salvesta'),
        ),
      ],
    ),
  );
}
