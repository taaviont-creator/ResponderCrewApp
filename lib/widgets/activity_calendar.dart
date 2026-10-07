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
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context);
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${months[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: textScale.scale(16) + textScale.scale(12) + 30,
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
              excludeSemantics: true,
              onTap: () => widget.onSelected(day),
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
                        ? colors.primary
                        : events > 0
                        ? colors.primaryContainer
                        : null,
                    border: events > 0 || ActivitySchedule.sameDay(day, today)
                        ? Border.all(color: colors.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: events > 0 || selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected
                                ? colors.onPrimary
                                : colors.onSurface,
                          ),
                        ),
                      ),
                      if (events > 0) ...[
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colors.onPrimary
                                    : colors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                events > 99 ? '99+' : '$events',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? colors.primary
                                      : colors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Arvumärgisega päeval on tegevus või koolitus. Märgis näitab nende arvu.',
          ),
        ),
      ],
    );
  }
}
