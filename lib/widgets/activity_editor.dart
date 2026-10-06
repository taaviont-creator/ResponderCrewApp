import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../models/activity_schedule.dart';
import '../services/activity_service.dart';
import 'activity_date_field.dart';

const activityTypeLabels = {
  ActivityType.training: 'Koolitus',
  ActivityType.meeting: 'Koosolek',
  ActivityType.maintenance: 'Hooldus',
  ActivityType.repair: 'Remont',
  ActivityType.groundskeeping: 'Heakord / niitmine',
  ActivityType.exercise: 'Harjutus',
  ActivityType.event: 'Sündmus',
  ActivityType.other: 'Muu',
};

class ActivityEditor extends StatefulWidget {
  const ActivityEditor({
    super.key,
    required this.service,
    required this.organizationId,
    required this.userId,
    this.activity,
    this.initialDay,
  });
  final ActivityService service;
  final String organizationId, userId;
  final ActivityModel? activity;
  final DateTime? initialDay;
  @override
  State<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<ActivityEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.activity?.title);
  late final _description = TextEditingController(
    text: widget.activity?.description,
  );
  late final _location = TextEditingController(text: widget.activity?.location);
  late String _type = activityTypeLabels.containsKey(widget.activity?.type)
      ? widget.activity!.type
      : ActivityType.training;
  late DateTime? _start = widget.activity?.startsAt,
      _end = widget.activity?.endsAt;
  bool _busy = false;
  String? _error, _dateError, _endError;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _dateError = _start == null ? 'Vali algusaeg.' : null;
      _endError = _end != null && _start != null && !_end!.isAfter(_start!)
          ? 'Lõpuaeg peab olema algusajast hilisem.'
          : null;
    });
    if (!_form.currentState!.validate() ||
        _dateError != null ||
        _endError != null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.activity == null) {
        await widget.service.addActivity(
          organizationId: widget.organizationId,
          createdBy: widget.userId,
          title: _title.text,
          description: _description.text,
          type: _type,
          startTime: _start!.toUtc().toIso8601String(),
          endTime: _end?.toUtc().toIso8601String() ?? '',
          location: _location.text,
        );
      } else {
        await widget.service.updateActivity(
          activity: widget.activity!,
          updatedBy: widget.userId,
          title: _title.text,
          description: _description.text,
          type: _type,
          startTime: _start!.toUtc().toIso8601String(),
          endTime: _end?.toUtc().toIso8601String() ?? '',
          location: _location.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Salvestamine ebaõnnestus. Sisestatud andmed on alles.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        widget.activity == null ? 'Lisa tegevus/koolitus' : 'Muuda tegevust',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: AbsorbPointer(
              absorbing: _busy,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Pealkiri'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Sisesta pealkiri.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tüüp'),
                    items: activityTypeLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 16),
                  ActivityDateField(
                    label: 'Algusaeg · Eesti aeg',
                    value: _start,
                    initialDate: widget.initialDay,
                    error: _dateError,
                    onChanged: (v) => setState(() {
                      _start = v;
                      _dateError = null;
                    }),
                  ),
                  if (widget.activity != null &&
                      widget.activity!.startsAt == null &&
                      widget.activity!.startTime.isNotEmpty)
                    Text('Varem sisestatud: ${widget.activity!.startTime}'),
                  const SizedBox(height: 16),
                  ActivityDateField(
                    label: 'Lõpuaeg (soovi korral)',
                    value: _end,
                    initialDate: _start == null
                        ? widget.initialDay
                        : ActivitySchedule.inEstonia(_start!),
                    optional: true,
                    error: _endError,
                    onChanged: (v) => setState(() {
                      _end = v;
                      _endError = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Asukoht'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Kirjeldus'),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Tühista'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Salvestan…' : 'Salvesta'),
        ),
      ],
    ),
  );
}
