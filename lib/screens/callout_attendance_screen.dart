import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/membership_model.dart';
import '../services/statistics_service.dart';

class CalloutAttendanceScreen extends StatefulWidget {
  const CalloutAttendanceScreen({
    super.key,
    required this.organizationId,
    required this.calloutId,
  });
  final String organizationId, calloutId;
  @override
  State<CalloutAttendanceScreen> createState() =>
      _CalloutAttendanceScreenState();
}

class _CalloutAttendanceScreenState extends State<CalloutAttendanceScreen> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    final db = FirebaseFirestore.instance;
    final result = await Future.wait([
      db
          .collection('memberships')
          .where(
            Filter.or(
              Filter('organizationId', isEqualTo: widget.organizationId),
              Filter('commandId', isEqualTo: widget.organizationId),
            ),
          )
          .get(),
      db
          .collection('calloutAttendance')
          .where('organizationId', isEqualTo: widget.organizationId)
          .where('calloutId', isEqualTo: widget.calloutId)
          .get(),
    ]);
    final attendance = {
      for (final d in result[1].docs) d.data()['userId']: d.data(),
    };
    final members = <String, Map<String, dynamic>>{};
    for (final d in result[0].docs) {
      final m = d.data();
      final uid = m['userId'] as String?;
      if (uid == null ||
          !MembershipModel.fromMap(id: d.id, data: m).isActive &&
              !['removed', 'inactive'].contains(m['status'])) {
        continue;
      }
      if (d.id != '${uid}_${widget.organizationId}') continue;
      members[uid] = {
        ...m,
        'attendance': attendance[uid],
      };
    }
    return members.values.toList()..sort(
      (a, b) => (a['displayName'] as String? ?? '').compareTo(
        b['displayName'] as String? ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Väljakutse osalejad')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: const Text('Laadimine ebaõnnestus. Proovi uuesti.'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Kinnita tegelikult osalenud liikmed. Reageerimisvastus ei ole osalemise kinnitus. Tunnid võid lisada hiljem.',
            ),
            const SizedBox(height: 16),
            for (final m in snapshot.data ?? <Map<String, dynamic>>[])
              _AttendanceRow(
                key: ValueKey(m['userId']),
                member: m,
                organizationId: widget.organizationId,
                calloutId: widget.calloutId,
              ),
          ],
        );
      },
    ),
  );
}

class _AttendanceRow extends StatefulWidget {
  const _AttendanceRow({
    super.key,
    required this.member,
    required this.organizationId,
    required this.calloutId,
  });
  final Map<String, dynamic> member;
  final String organizationId, calloutId;
  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> {
  late final _hours = TextEditingController(
    text: (widget.member['attendance']?['hours'] ?? '').toString(),
  );
  late String? _status = widget.member['attendance']?['status'] as String?;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save(String status) async {
    final raw = _hours.text.trim().replaceAll(',', '.');
    final hours = raw.isEmpty ? null : double.tryParse(raw);
    if (status == 'confirmed' &&
        raw.isNotEmpty &&
        (hours == null || !hours.isFinite || hours < 0 || hours > 744)) {
      setState(() => _error = 'Sisesta kehtiv tundide arv (0–744).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await StatisticsService().saveAttendance({
        'organizationId': widget.organizationId,
        'calloutId': widget.calloutId,
        'userId': widget.member['userId'],
        'status': status,
        'hours': status == 'confirmed' ? hours : null,
      });
      if (mounted) setState(() => _status = status);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Salvestamine ebaõnnestus.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Salvestamine ebaõnnestus. Proovi uuesti.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.member['displayName'] as String? ?? 'Liige',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              _status == 'confirmed'
                  ? 'Osales'
                  : _status == 'absent'
                  ? 'Ei osalenud'
                  : 'Kinnitamata',
            ),
            TextField(
              controller: _hours,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Osalemise tunnid (valikuline)',
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_saving) const LinearProgressIndicator(),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => _save('confirmed'),
                  child: Text(
                    _status == 'confirmed' ? 'Uuenda tunde' : 'Kinnita osales',
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _save('absent'),
                  child: const Text('Ei osalenud'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
