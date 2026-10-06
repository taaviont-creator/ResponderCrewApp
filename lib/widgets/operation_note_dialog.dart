import 'app_date_field.dart';
import 'package:flutter/material.dart';
import '../models/operation_log_report.dart';

class OperationNoteDialog extends StatefulWidget {
  const OperationNoteDialog({super.key, required this.onSave});
  final Future<void> Function(String text, DateTime? occurredAt) onSave;
  @override
  State<OperationNoteDialog> createState() => _OperationNoteDialogState();
}

class _OperationNoteDialogState extends State<OperationNoteDialog> {
  final _text = TextEditingController();
  bool _retrospective = false, _saving = false;
  DateTime _time = DateTime.now();
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final day = await showAppDatePicker(
      context: context,
      initialDate: _time,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (time != null && mounted) {
      setState(
        () => _time = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty ||
        (_retrospective && _time.isAfter(DateTime.now()))) {
      setState(
        () => _error = 'Sisesta kommentaar ja vali aeg, mis ei ole tulevikus.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_text.text.trim(), _retrospective ? _time : null);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Salvestamine ebaõnnestus. Kommentaar on alles; proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Lisa operatiivlogisse kommentaar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Kommentaar'),
              maxLines: 4,
              autofocus: true,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lisa tagantjärele'),
              value: _retrospective,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _retrospective = v!),
            ),
            if (_retrospective)
              TextButton.icon(
                onPressed: _saving ? null : _pickTime,
                icon: const Icon(Icons.schedule),
                label: Text('Sündmuse aeg: ${operationLogEventTime(_time)}'),
              ),
            if (_retrospective)
              const Text('Salvestamise aeg ja autor jäävad eraldi alles.'),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Katkesta'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvesta kommentaar'),
        ),
      ],
    ),
  );
}

class OperationSummaryDialog extends StatefulWidget {
  const OperationSummaryDialog({
    super.key,
    required this.summary,
    required this.outcome,
    required this.onSave,
  });
  final String summary, outcome;
  final Future<void> Function(String summary, String outcome) onSave;
  @override
  State<OperationSummaryDialog> createState() => _OperationSummaryDialogState();
}

class _OperationSummaryDialogState extends State<OperationSummaryDialog> {
  late final _summary = TextEditingController(text: widget.summary);
  late final _outcome = TextEditingController(text: widget.outcome);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _summary.dispose();
    _outcome.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_summary.text.trim(), _outcome.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Salvestamine ebaõnnestus. Muudatused on alles; proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Lõppkokkuvõte'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _summary,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Lõppkokkuvõte'),
              maxLines: 4,
            ),
            TextField(
              controller: _outcome,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Tulemus'),
              maxLines: 2,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Katkesta'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvesta kokkuvõte'),
        ),
      ],
    ),
  );
}
