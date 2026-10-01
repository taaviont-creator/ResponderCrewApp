import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class CenterAccessDialog extends StatefulWidget {
  const CenterAccessDialog({
    super.key,
    required this.userId,
    required this.name,
  });
  final String userId, name;
  @override
  State<CenterAccessDialog> createState() => _CenterAccessDialogState();
}

class _CenterAccessDialogState extends State<CenterAccessDialog> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-north1');
  List<Map<String, dynamic>> _grants = [];
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _functions
          .httpsCallable('getPlatformCenterAccess')
          .call({'userId': widget.userId});
      if (mounted) {
        setState(() {
          _grants = ((result.data as Map)['grants'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Keskuse õiguste laadimine ebaõnnestus.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(Map<String, dynamic> grant, bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _functions.httpsCallable('setCenterAccess').call({
        'userId': widget.userId,
        'centerId': grant['centerId'],
        'active': enabled,
        'expectedRevision': grant['revision'],
      });
      if (mounted) await _load();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Õiguse muutmine ebaõnnestus.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Õiguse muutmine ebaõnnestus.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Keskuste ligipääs'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name),
            const SizedBox(height: 12),
            const Text(
              'Õigus kehtib kuni eemaldamiseni. See ei anna ühingu administraatori ega platvormihalduri õigusi.',
            ),
            if (_busy) const LinearProgressIndicator(),
            for (final grant in _grants)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(grant['name'] as String),
                subtitle: grant['validUntilMs'] == null
                    ? null
                    : Text(
                        'Kehtiv kuni ${DateTime.fromMillisecondsSinceEpoch(grant['validUntilMs'] as int).toLocal()}',
                      ),
                value: grant['active'] == true,
                onChanged: _busy ? null : (value) => _change(grant, value),
              ),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Laadi uuesti'),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Sulge'),
      ),
    ],
  );
}
