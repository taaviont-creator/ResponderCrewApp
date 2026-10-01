import 'package:flutter/material.dart';

class UnitAllocationDialog extends StatefulWidget {
  const UnitAllocationDialog({
    super.key,
    required this.members,
    required this.vessels,
  });
  final List<Map<String, dynamic>> members, vessels;
  @override
  State<UnitAllocationDialog> createState() => _UnitAllocationDialogState();
}

class _UnitAllocationDialogState extends State<UnitAllocationDialog> {
  final Set<String> _members = {}, _vessels = {};
  int _hours = 4;
  String? _error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Määra ressursid üksusele'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Valik asendab selle üksuse praeguse jaotuse. Liikmete isiklik valvesolek ei muutu. Jaotus ei ole valmiduskinnitus.',
            ),
            for (final entry in [
              (widget.members, _members, 'Liikmed'),
              (widget.vessels, _vessels, 'Alused'),
            ]) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  entry.$3,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final row in entry.$1)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row['name'] as String),
                  subtitle:
                      entry.$3 == 'Alused' && row['identityVerified'] != true
                      ? const Text(
                          'Ühistunnus kinnitamata: ei tõenda veel valmidust',
                        )
                      : null,
                  value: entry.$2.contains(row['id']),
                  onChanged: (v) => setState(() {
                    v == true
                        ? entry.$2.add(row['id'] as String)
                        : entry.$2.remove(row['id']);
                  }),
                ),
            ],
            DropdownButtonFormField<int>(
              initialValue: _hours,
              decoration: const InputDecoration(labelText: 'Jaotuse kestus'),
              items: [
                for (final h in [1, 4, 8, 12, 24])
                  DropdownMenuItem(value: h, child: Text('$h tundi')),
              ],
              onChanged: (v) => setState(() => _hours = v ?? 4),
            ),
            if (_error != null) Text(_error!),
          ],
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
          if (_members.isEmpty && _vessels.isEmpty) {
            setState(() => _error = 'Vali vähemalt üks liige või alus.');
            return;
          }
          Navigator.pop(context, {
            'memberIds': _members.toList(),
            'vesselIds': _vessels.toList(),
            'durationHours': _hours,
          });
        },
        child: const Text('Määra üksusele'),
      ),
    ],
  );
}
