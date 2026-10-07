import 'package:flutter/material.dart';

class ResponseUnitDialog extends StatefulWidget {
  const ResponseUnitDialog({
    super.key,
    required this.bases,
    required this.members,
    required this.vessels,
    this.initial,
  });
  final List<Map<String, dynamic>> bases, members, vessels;
  final Map<String, dynamic>? initial;
  @override
  State<ResponseUnitDialog> createState() => _ResponseUnitDialogState();
}

class _ResponseUnitDialogState extends State<ResponseUnitDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?['name'] as String? ?? '',
  );
  late final _contact = TextEditingController(
    text: widget.initial?['contactName'] as String? ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.initial?['contactPhone'] as String? ?? '',
  );
  late String? _base = widget.initial?['baseId'] as String?;
  late bool _active = widget.initial?['active'] != false;
  late final Set<String> _services = Set<String>.from(
    widget.initial?['enabledServices'] as List? ?? [],
  );
  late final Set<String> _members = Set<String>.from(
    widget.initial?['memberIds'] as List? ?? [],
  );
  late final Set<String> _vessels = Set<String>.from(
    widget.initial?['vesselIds'] as List? ?? [],
  );
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    super.dispose();
  }

  Widget _choices(
    String title,
    List<Map<String, dynamic>> rows,
    Set<String> selected, {
    bool vessels = false,
  }) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text('$title (${selected.length})'),
    children: [
      for (final row in rows)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(row['name'] as String),
          subtitle: vessels && row['identityVerified'] != true
              ? const Text('Aluse ühine tunnus vajab kontrollimist')
              : null,
          value: selected.contains(row['id']),
          onChanged: (v) => setState(() {
            v == true
                ? selected.add(row['id'] as String)
                : selected.remove(row['id']);
          }),
        ),
      for (final missing
          in selected.where((id) => !rows.any((r) => r['id'] == id)).toList())
        CheckboxListTile(
          title: const Text('Kirje ei ole enam valitav'),
          subtitle: Text(missing),
          value: true,
          onChanged: (_) => setState(() => selected.remove(missing)),
        ),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Sobivaid kirjeid ei ole. Lisa alus esmalt ühingu varustusse; liige peab olema aktiivne.',
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null
          ? 'Lisa reageeriv üksus'
          : 'Muuda reageerivat üksust',
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Üksuse nimi'),
                maxLength: 120,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Sisesta nimi' : null,
              ),
              DropdownButtonFormField<String>(
                itemHeight: null,
                initialValue: widget.bases.any((b) => b['id'] == _base)
                    ? _base
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Päästebaas'),
                items: [
                  for (final b in widget.bases)
                    DropdownMenuItem(
                      value: b['id'] as String,
                      child: Text(b['name'] as String),
                    ),
                ],
                onChanged: (v) => setState(() => _base = v),
                validator: (v) => v == null ? 'Vali päästebaas' : null,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const {
                    'sar': 'SAR',
                    'tross': 'Trossi mereabi',
                  }.entries)
                    FilterChip(
                      label: Text(s.value),
                      selected: _services.contains(s.key),
                      onSelected: (v) => setState(() {
                        v ? _services.add(s.key) : _services.remove(s.key);
                      }),
                    ),
                ],
              ),
              TextFormField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'Keskusele nähtava kontakti nimetus',
                ),
                maxLength: 120,
              ),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Valvekontakt / telefon',
                ),
                maxLength: 60,
                keyboardType: TextInputType.phone,
              ),
              const Text(
                'Kasuta keskusele jagamiseks sobivat valvekontakti. Võimalik koosseis ei määra veel liikmeid ega aluseid üksuse kasutusse.',
              ),
              _choices('Võimalikud liikmed', widget.members, _members),
              _choices(
                'Võimalikud alused',
                widget.vessels,
                _vessels,
                vessels: true,
              ),
              if (widget.initial != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Üksus on kasutusel'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Katkesta'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          if (_services.isEmpty ||
              _members.length > 50 ||
              _vessels.length > 10) {
            setState(
              () => _error =
                  'Vali teenus. Üksuses saab olla kuni 50 liiget ja 10 alust.',
            );
            return;
          }
          Navigator.pop(context, <String, dynamic>{
            'name': _name.text.trim(),
            'baseId': _base,
            'active': _active,
            'enabledServices': _services.toList(),
            'contactName': _contact.text.trim(),
            'contactPhone': _phone.text.trim(),
            'memberIds': _members.toList(),
            'vesselIds': _vessels.toList(),
          });
        },
        child: const Text('Salvesta'),
      ),
    ],
  );
}
