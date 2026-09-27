import 'dart:async';
import 'package:flutter/material.dart';
import '../models/callout_model.dart';
import '../models/operation_log_model.dart';
import '../models/operation_log_report.dart';

DateTime? firstDeparture(List<OperationLogEventModel> events) {
  final times =
      events
          .where(
            (e) =>
                e.type == OperationLogEventType.statusChange &&
                OperationLogStatus.normalize(e.status) ==
                    OperationLogStatus.enRoute,
          )
          .map((e) => e.createdAt)
          .whereType<DateTime>()
          .toList()
        ..sort();
  return times.isEmpty ? null : times.first;
}

class CalloutDepartureTiming extends StatefulWidget {
  const CalloutDepartureTiming({
    super.key,
    required this.callout,
    required this.events,
  });
  final CalloutModel callout;
  final List<OperationLogEventModel> events;
  @override
  State<CalloutDepartureTiming> createState() => _CalloutDepartureTimingState();
}

class _CalloutDepartureTimingState extends State<CalloutDepartureTiming> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callout = widget.callout;
    final departure = firstDeparture(widget.events);
    final target = callout.responseTargetMinutes;
    final activated = callout.createdAt;
    final deadline = activated == null || target == null
        ? null
        : activated.add(Duration(minutes: target));
    final overdue =
        deadline != null &&
        (departure != null
            ? departure.isAfter(deadline)
            : callout.status == CalloutStatus.active &&
                  DateTime.now().isAfter(deadline));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (target != null)
          Text('Väljasõidu sihtaeg: $target min aktiveerimisest'),
        if (deadline != null)
          Text('Sihtaeg: ${operationLogEventTime(deadline)}'),
        Text(
          departure == null
              ? 'Väljasõitu ei ole registreeritud'
              : 'Tegelik väljasõit: ${operationLogEventTime(departure)}',
        ),
        if (overdue)
          Text(
            'Väljasõidu sihtaeg ületatud',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        const Text(
          'Liikme saabumisaeg on tema isiklik hinnang. Reageerimine ei kinnita pardalolekut.',
        ),
      ],
    );
  }
}
