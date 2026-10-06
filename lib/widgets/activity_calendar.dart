import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../models/activity_schedule.dart';

class ActivityCalendar extends StatefulWidget {
  const ActivityCalendar({
    super.key,
    required this.activities,
    required this.selectedDay,
    required this.onSelected,
  });
  final List<ActivityModel> activities;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;
  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  late DateTime _month = DateTime(
    widget.selectedDay.year,
    widget.selectedDay.month,
  );
  static const months = [
    'Jaanuar',
    'Veebruar',
    'Märts',
    'Aprill',
    'Mai',
    'Juuni',
    'Juuli',
    'August',
    'September',
    'Oktoober',
    'November',
    'Detsember',
  ];

  @override
  Widget build(BuildContext context) {
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1;
    final count = ((offset + days) / 7).ceil() * 7;
    final today = ActivitySchedule.inEstonia(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Eelmine kuu',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${months[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Järgmine kuu',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () {
                setState(() => _month = DateTime(today.year, today.month));
                widget.onSelected(DateTime(today.year, today.month, today.day));
              },
              child: const Text('Täna'),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in ['E', 'T', 'K', 'N', 'R', 'L', 'P'])
              Expanded(child: Center(child: Text(d))),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 48,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final number = index - offset + 1;
            if (number < 1 || number > days) return const SizedBox.shrink();
            final day = DateTime(_month.year, _month.month, number);
            final events = widget.activities
                .where((a) => a.occursOn(day))
                .length;
            final selected = ActivitySchedule.sameDay(day, widget.selectedDay);
            return Semantics(
              label: '${ActivitySchedule.date(day)}, $events tegevust',
              selected: selected,
              button: true,
              child: InkWell(
                key: ValueKey(
                  'calendar-${day.toIso8601String().split('T').first}',
                ),
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onSelected(day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    border: ActivitySchedule.sameDay(day, today)
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$number'),
                      if (events > 0)
                        Text(
                          '$events',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Kuupäeva all olev arv näitab tegevuste arvu.'),
        ),
      ],
    );
  }
}
