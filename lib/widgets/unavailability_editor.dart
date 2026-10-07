import 'package:flutter/material.dart';
import '../models/activity_schedule.dart';
import '../models/planned_unavailability_model.dart';
import '../models/planned_unavailability_rule_model.dart';
import '../services/planned_unavailability_service.dart';
import 'activity_date_field.dart';

/// One editor, backed by the existing period and weekly-rule collections.
/// Editing preserves the record type and ID; it never creates a second record.
class UnavailabilityEditor extends StatefulWidget {
  const UnavailabilityEditor({
    super.key,
    required this.organizationId,
    required this.service,
    this.period,
    this.rule,
  }) : assert(period == null || rule == null);

  final String organizationId;
  final PlannedUnavailabilityService service;
  final PlannedUnavailabilityModel? period;
  final PlannedUnavailabilityRuleModel? rule;

  @override
  State<UnavailabilityEditor> createState() => _UnavailabilityEditorState();
}

class _UnavailabilityEditorState extends State<UnavailabilityEditor> {
  late bool _weekly;
  late DateTime _start, _end;
  late int _startMinute, _endMinute;
  late Set<int> _days;
  late final TextEditingController _note;
  bool _saving = false;
  String? _error;
  bool get _editing => widget.period != null || widget.rule != null;

  @override
  void initState() {
    super.initState();
    _weekly = widget.rule != null;
    final nextHour = ActivitySchedule.inEstonia(
      DateTime.now().add(const Duration(hours: 1)),
    );
    _start =
        widget.period?.startAt ??
        ActivitySchedule.fromSelection(nextHour, nextHour.hour, 0)!;
    _end = widget.period?.endAt ?? _start.add(const Duration(hours: 2));
    _startMinute = widget.rule?.startMinute ?? 480;
    _endMinute = widget.rule?.endMinute ?? 1020;
    _days = {...?widget.rule?.daysOfWeek};
    _note = TextEditingController(
      text: widget.period?.note ?? widget.rule?.note ?? '',
    );
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_weekly && _days.isEmpty) {
      setState(() => _error = 'Vali vähemalt üks nädalapäev.');
      return;
    }
    if (_weekly ? _startMinute >= _endMinute : !_start.isBefore(_end)) {
      setState(
        () => _error = _weekly
            ? 'Lõpuaeg peab olema algusest hilisem. Üle südaöö korduv mittevalve lisa kahe ajana.'
            : 'Lõpuaeg peab olema algusest hilisem.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_weekly) {
        final days = _days.toList()..sort();
        if (widget.rule case final rule?) {
          await widget.service.updateMyRule(
            ruleId: rule.id,
            organizationId: widget.organizationId,
            daysOfWeek: days,
            startMinute: _startMinute,
            endMinute: _endMinute,
            note: _note.text,
          );
        } else {
          await widget.service.createMyRule(
            organizationId: widget.organizationId,
            daysOfWeek: days,
            startMinute: _startMinute,
            endMinute: _endMinute,
            note: _note.text,
          );
        }
      } else if (widget.period case final period?) {
        await widget.service.updateMyPeriod(
          periodId: period.id,
          organizationId: widget.organizationId,
          startAt: _start,
          endAt: _end,
          note: _note.text,
        );
      } else {
        await widget.service.createMyPeriod(
          organizationId: widget.organizationId,
          startAt: _start,
          endAt: _end,
          note: _note.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Mittevalvet ei saanud salvestada. Kontrolli ühendust ja proovi uuesti.';
        });
      }
    }
  }

  Future<void> _pickTime(bool start) async {
    final minute = start ? _startMinute : _endMinute;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      helpText: '${start ? 'Algus' : 'Lõpp'} · Eesti aeg',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final value = selected.hour * 60 + selected.minute;
      if (start) {
        _startMinute = value;
      } else {
        _endMinute = value;
      }
    });
  }

  Widget _timeField(String label, int minute, bool start) => InkWell(
    onTap: () => _pickTime(start),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.schedule),
      ),
      child: Text(
        '${ActivitySchedule.two(minute ~/ 60)}:${ActivitySchedule.two(minute % 60)}',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_editing ? 'Muuda mittevalvet' : 'Planeeri mittevalve'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AbsorbPointer(
              absorbing: _saving,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editing)
                    Text(
                      _weekly ? 'Kordub igal nädalal' : 'Ühekordne mittevalve',
                    )
                  else
                    DropdownButtonFormField<bool>(
                      itemHeight: null,
                      isExpanded: true,
                      initialValue: _weekly,
                      decoration: const InputDecoration(labelText: 'Kordumine'),
                      items: const [
                        DropdownMenuItem(value: false, child: Text('Ei kordu')),
                        DropdownMenuItem(
                          value: true,
                          child: Text('Igal nädalal'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _weekly = value ?? false;
                        _error = null;
                      }),
                    ),
                  const SizedBox(height: 16),
                  if (_weekly) ...[
                    const Text('Nädalapäevad'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var i = 1; i <= 7; i++)
                          FilterChip(
                            label: Text(
                              const ['E', 'T', 'K', 'N', 'R', 'L', 'P'][i - 1],
                            ),
                            tooltip: const [
                              'Esmaspäev',
                              'Teisipäev',
                              'Kolmapäev',
                              'Neljapäev',
                              'Reede',
                              'Laupäev',
                              'Pühapäev',
                            ][i - 1],
                            selected: _days.contains(i),
                            onSelected: (selected) => setState(() {
                              selected ? _days.add(i) : _days.remove(i);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _timeField('Algus', _startMinute, true),
                    const SizedBox(height: 12),
                    _timeField('Lõpp', _endMinute, false),
                  ] else ...[
                    ActivityDateField(
                      label: 'Algus',
                      value: _start,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _start = value;
                            if (!_start.isBefore(_end)) {
                              _end = _start.add(const Duration(hours: 2));
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ActivityDateField(
                      label: 'Lõpp',
                      value: _end,
                      onChanged: (value) {
                        if (value != null) setState(() => _end = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Kõik ajad on Eesti aja järgi.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    enabled: !_saving,
                    maxLines: 2,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Märkus (valikuline)',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Katkesta'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvesta'),
        ),
      ],
    ),
  );
}
