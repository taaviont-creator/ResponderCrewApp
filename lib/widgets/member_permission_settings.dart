import 'package:flutter/material.dart';

/// Owns the subscription on the settings route, independently of the home route.
class MemberPermissionSettings extends StatefulWidget {
  const MemberPermissionSettings({
    super.key,
    required this.settings,
    required this.save,
  });
  final Stream<Map<String, dynamic>> settings;
  final Future<void> Function(String field, bool value) save;
  @override
  State<MemberPermissionSettings> createState() =>
      _MemberPermissionSettingsState();
}

class _MemberPermissionSettingsState extends State<MemberPermissionSettings> {
  bool _saving = false;
  String? _error;
  Future<void> _save(String field, bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(field, value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Seadete muutmine ebaõnnestus. Proovi uuesti.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
    stream: widget.settings,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Seadete laadimine ebaõnnestus.'),
          ),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final data = snapshot.data!;
      return Card(
        child: Column(
          children: [
            for (final entry in const {
              'allowMembersToCreateActivities':
                  'Liikmed võivad lisada tegevusi/koolitusi',
              'allowMembersToViewStatistics': 'Liikmed võivad näha statistikat',
            }.entries)
              SwitchListTile(
                title: Text(entry.value),
                value: data[entry.key] == true,
                onChanged: _saving ? null : (value) => _save(entry.key, value),
              ),
            if (_saving) const LinearProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          ],
        ),
      );
    },
  );
}
