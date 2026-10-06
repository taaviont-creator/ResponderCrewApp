import 'package:flutter/material.dart';

import '../models/calendar_date.dart';
export '../models/calendar_date.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? helpText,
  String? cancelText,
  String? confirmText,
}) {
  final first = DateUtils.dateOnly(firstDate ?? DateTime(1900));
  final last = DateUtils.dateOnly(lastDate ?? DateTime(2200, 12, 31));
  var initial = DateUtils.dateOnly(initialDate ?? DateTime.now());
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: helpText ?? 'Vali kuupäev',
    cancelText: cancelText ?? 'Tühista',
    confirmText: confirmText ?? 'Vali',
    initialEntryMode: DatePickerEntryMode.calendar,
  );
}

Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
}) => showTimePicker(
  context: context,
  initialTime: initialTime,
  helpText: helpText ?? 'Vali kellaaeg',
  cancelText: 'Tühista',
  confirmText: 'Vali',
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  ),
);

/// Date-only values keep their calendar day; no UTC conversion is applied.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.optional = false,
    this.enabled = true,
    this.validator,
    this.emptyLabel = 'Vali kuupäev',
  });
  final String label, emptyLabel;
  final DateTime? value, firstDate, lastDate;
  final ValueChanged<DateTime?> onChanged;
  final bool optional, enabled;
  final FormFieldValidator<DateTime>? validator;

  @override
  Widget build(BuildContext context) => FormField<DateTime>(
    key: ValueKey(value),
    initialValue: value,
    validator: validator,
    enabled: enabled,
    builder: (state) => Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: !enabled
                ? null
                : () async {
                    final date = await showAppDatePicker(
                      context: context,
                      initialDate: value,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      helpText: label,
                    );
                    if (date != null && context.mounted) {
                      state.didChange(date);
                      onChanged(date);
                    }
                  },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                enabled: enabled,
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.calendar_month_outlined),
              ),
              child: Text(
                value == null ? emptyLabel : calendarDateLabel(value),
              ),
            ),
          ),
        ),
        if (optional && value != null)
          IconButton(
            tooltip: 'Tühjenda: $label',
            onPressed: enabled
                ? () {
                    state.didChange(null);
                    onChanged(null);
                  }
                : null,
            icon: const Icon(Icons.clear),
          ),
      ],
    ),
  );
}

/// Adapter for existing ISO string fields, without changing Firestore data.
class AppDateTextField extends StatelessWidget {
  const AppDateTextField({
    super.key,
    required this.controller,
    required this.label,
    this.optional = true,
    this.enabled = true,
    this.lastDate,
  });
  final TextEditingController controller;
  final String label;
  final bool optional, enabled;
  final DateTime? lastDate;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => AppDateField(
          label: label,
          value: parseCalendarDate(value.text),
          optional: optional,
          enabled: enabled,
          lastDate: lastDate,
          emptyLabel: value.text.isEmpty
              ? 'Vali kuupäev'
              : 'Kontrolli kuupäeva: ${value.text}',
          onChanged: (date) =>
              controller.text = date == null ? '' : calendarDateIso(date),
        ),
      );
}
