import 'app_date_field.dart';
import 'package:flutter/material.dart';
import '../models/activity_schedule.dart';

class ActivityDateField extends StatelessWidget {
  const ActivityDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.initialDate,
    this.error,
    this.optional = false,
  });
  final String label;
  final DateTime? value, initialDate;
  final ValueChanged<DateTime?> onChanged;
  final String? error;
  final bool optional;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label, errorText: error),
    child: Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final initial = value != null
                  ? ActivitySchedule.inEstonia(value!)
                  : initialDate ?? ActivitySchedule.inEstonia(DateTime.now());
              final day = await showAppDatePicker(
                context: context,
                initialDate: DateTime(initial.year, initial.month, initial.day),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100, 12, 31),
                helpText: label,
                cancelText: 'Tühista',
                confirmText: 'Edasi',
              );
              if (day == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: initial.hour,
                  minute: initial.minute,
                ),
                helpText: 'Kellaaeg · Eesti aeg',
                cancelText: 'Tühista',
                confirmText: 'Vali',
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (time == null || !context.mounted) return;
              final selected = ActivitySchedule.fromSelection(
                day,
                time.hour,
                time.minute,
              );
              if (selected == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Seda kellaaega kella keeramise tõttu ei ole. Vali teine aeg.',
                    ),
                  ),
                );
                return;
              }
              onChanged(selected);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value == null
                          ? 'Vali kuupäev ja kellaaeg'
                          : ActivitySchedule.format(value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (optional && value != null)
          IconButton(
            tooltip: 'Eemalda lõpuaeg',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );
}
