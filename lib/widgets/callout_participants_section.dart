import 'package:flutter/material.dart';
import '../services/callout_attendance_service.dart';
import '../screens/callout_attendance_screen.dart';
import '../models/statistics_model.dart';

class CalloutParticipantsSection extends StatefulWidget {
  const CalloutParticipantsSection({
    super.key,
    required this.organizationId,
    required this.calloutId,
    required this.currentUid,
  });
  final String organizationId, calloutId, currentUid;
  @override
  State<CalloutParticipantsSection> createState() =>
      _CalloutParticipantsSectionState();
}

class _CalloutParticipantsSectionState
    extends State<CalloutParticipantsSection> {
  late final _people = CalloutAttendanceService().participants(
    widget.organizationId,
    widget.calloutId,
  );
  late final _permission = CalloutAttendanceService().canManage(
    organizationId: widget.organizationId,
    userId: widget.currentUid,
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Väljakutse osalejad',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _people,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Osalejate laadimine ebaõnnestus.');
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final people = snapshot.data!
              .where((p) => p['status'] == 'confirmed')
              .toList();
          if (people.isEmpty) {
            return const Text('Osalejaid pole veel kinnitatud.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in people)
                Text(
                  '${p['userName'] ?? 'Liige'}${p['hours'] == null ? '' : ' · ${statisticsHours(p['hours'] as num)}'}',
                ),
            ],
          );
        },
      ),
      StreamBuilder<bool>(
        stream: _permission,
        builder: (context, snapshot) => snapshot.data != true
            ? const SizedBox.shrink()
            : OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                icon: const Icon(Icons.people_outline),
                label: const Text('Lisa / muuda ja kinnita osalejad'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalloutAttendanceScreen(
                      organizationId: widget.organizationId,
                      calloutId: widget.calloutId,
                    ),
                  ),
                ),
              ),
      ),
      const SizedBox(height: 12),
    ],
  );
}
