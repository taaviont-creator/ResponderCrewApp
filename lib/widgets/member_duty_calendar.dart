import 'package:flutter/material.dart';
import '../models/activity_schedule.dart';
import '../models/availability_model.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import 'app_date_field.dart';

List<String> memberDayAbsences({
  required String userId,
  required DateTime day,
  required List<PlannedUnavailabilityModel> periods,
  required List<PlannedUnavailabilityRuleModel> rules,
}) {
  final start = ActivitySchedule.fromSelection(day, 0, 0)!;
  final end = ActivitySchedule.fromSelection(
    DateTime(day.year, day.month, day.day + 1),
    0,
    0,
  )!;
  return [
    for (final p in periods)
      if (p.userId == userId &&
          p.isActive &&
          p.startAt != null &&
          p.endAt != null &&
          p.startAt!.isBefore(end) &&
          p.endAt!.isAfter(start))
        '${ActivitySchedule.format(p.startAt)} – ${ActivitySchedule.format(p.endAt)}',
    for (final r in rules)
      if (r.userId == userId &&
          r.isActive &&
          r.daysOfWeek.contains(day.weekday))
        '${ActivitySchedule.two(r.startMinute ~/ 60)}:${ActivitySchedule.two(r.startMinute % 60)} – ${ActivitySchedule.two(r.endMinute ~/ 60)}:${ActivitySchedule.two(r.endMinute % 60)} · korduv',
  ];
}

class MemberDutyCalendar extends StatefulWidget {
  const MemberDutyCalendar({
    super.key,
    required this.userId,
    required this.status,
    required this.periods,
    required this.rules,
    this.now,
  });
  final String userId, status;
  final List<PlannedUnavailabilityModel> periods;
  final List<PlannedUnavailabilityRuleModel> rules;
  final DateTime? now;
  @override
  State<MemberDutyCalendar> createState() => _MemberDutyCalendarState();
}

class _MemberDutyCalendarState extends State<MemberDutyCalendar> {
  int _selected = 0;
  @override
  Widget build(BuildContext context) {
    final today = ActivitySchedule.inEstonia(widget.now ?? DateTime.now());
    final days = List.generate(
      14,
      (i) => DateTime(today.year, today.month, today.day + i),
    );
    List<String> absences(DateTime day) => memberDayAbsences(
      userId: widget.userId,
      day: day,
      periods: widget.periods,
      rules: widget.rules,
    );
    final selected = absences(days[_selected]);
    final status = widget.status == AvailabilityStatus.onDuty
        ? 'Valves'
        : widget.status == AvailabilityStatus.delayed
        ? 'Hilinemisega'
        : 'Mitte valves';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Järgmised 14 päeva · praeguse staatuse ja planeeringute põhjal',
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message:
                        '${calendarDateLabel(days[i])}: ${absences(days[i]).isEmpty ? status : 'Planeeritud mittevalve'}',
                    child: ChoiceChip(
                      selected: i == _selected,
                      onSelected: (_) => setState(() => _selected = i),
                      label: Column(
                        children: [
                          Text(
                            const [
                              'E',
                              'T',
                              'K',
                              'N',
                              'R',
                              'L',
                              'P',
                            ][days[i].weekday - 1],
                          ),
                          Text('${days[i].day}'),
                          Icon(
                            absences(days[i]).isNotEmpty
                                ? Icons.event_busy
                                : widget.status == AvailabilityStatus.onDuty
                                ? Icons.check_circle
                                : Icons.schedule,
                            size: 16,
                            color: absences(days[i]).isNotEmpty
                                ? Colors.deepOrange
                                : widget.status == AvailabilityStatus.onDuty
                                ? Colors.teal
                                : Colors.blueGrey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${calendarDateLabel(days[_selected])} · ${selected.isEmpty ? '$status, mittevalvet pole planeeritud' : 'Planeeritud mittevalve'}',
        ),
        for (final line in selected)
          Text(line, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
