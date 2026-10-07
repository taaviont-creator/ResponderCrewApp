import 'dart:async';
import 'package:flutter/material.dart';
import '../models/activity_schedule.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../models/upcoming_absence.dart';

class HomeAbsencePreview extends StatefulWidget {
  const HomeAbsencePreview({
    super.key,
    required this.userId,
    required this.periods,
    required this.rules,
    required this.onPlan,
  });
  final String userId;
  final List<PlannedUnavailabilityModel> periods;
  final List<PlannedUnavailabilityRuleModel> rules;
  final VoidCallback onPlan;
  @override
  State<HomeAbsencePreview> createState() => _HomeAbsencePreviewState();
}

class _HomeAbsencePreviewState extends State<HomeAbsencePreview> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _date(DateTime time) {
    final local = ActivitySchedule.inEstonia(time);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = upcomingAbsences(
      userId: widget.userId,
      periods: widget.periods,
      rules: widget.rules,
      now: DateTime.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: widget.onPlan,
          icon: const Icon(Icons.event_busy_outlined),
          label: const Text('Planeeri valvevälist aega'),
        ),
        if (upcoming.isNotEmpty) ...[
          Text(
            'Järgmised valvevälised ajad',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          for (final item in upcoming)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_date(item.start)} – ${_date(item.end)}${item.recurring ? ' · korduv' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
