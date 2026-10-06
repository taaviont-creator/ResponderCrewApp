import 'package:flutter/material.dart';

/// One immediate checkbox write. Hours remain separate from the member's RSVP.
class ActivityAttendanceRow extends StatefulWidget {
  const ActivityAttendanceRow({
    super.key,
    required this.name,
    required this.confirmed,
    required this.onSave,
    this.hours,
    this.canEdit = true,
    this.responseLabel,
  });
  final String name;
  final String? responseLabel;
  final bool confirmed, canEdit;
  final double? hours;
  final Future<void> Function(bool confirmed, double? hours) onSave;
  @override
  State<ActivityAttendanceRow> createState() => _ActivityAttendanceRowState();
}

class _ActivityAttendanceRowState extends State<ActivityAttendanceRow> {
  bool _busy = false;
  bool? _checked;
  double? _hours;
  String? _error;
  bool get checked => _checked ?? widget.confirmed;
  double? get hours => _checked == null ? widget.hours : _hours;
  @override
  void didUpdateWidget(ActivityAttendanceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy &&
        (oldWidget.confirmed != widget.confirmed ||
            oldWidget.hours != widget.hours)) {
      _checked = null;
    }
  }

  Future<void> _save(bool value, double? hours) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(value, hours);
      if (mounted) {
        setState(() {
          _checked = value;
          _hours = hours;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Salvestamine ebaõnnestus. Proovi uuesti.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editHours() async {
    final controller = TextEditingController(text: hours?.toString() ?? '');
    String? error;
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('${widget.name} · tunnid'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Osaletud tunnid',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tühista'),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                final value = double.tryParse(raw.replaceAll(',', '.'));
                if (raw.isNotEmpty &&
                    (value == null || !value.isFinite || value < 0)) {
                  update(() => error = 'Sisesta korrektne tundide arv.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Salvesta'),
            ),
          ],
        ),
      ),
    );
    final saved = await Navigator.of(context).push(route);
    await route.completed;
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    controller.dispose();
    if (saved == true && mounted) await _save(true, value);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(widget.name),
              subtitle: widget.responseLabel == null
                  ? null
                  : Text(widget.responseLabel!),
              value: checked,
              onChanged: _busy || !widget.canEdit
                  ? null
                  : (v) => _save(
                      v == true,
                      v == true ? hours : null,
                    ),
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (checked)
            TextButton(
              onPressed: widget.canEdit ? _editHours : null,
              child: Text(
                hours == null
                    ? 'Lisa tunnid'
                    : '${hours!.toStringAsFixed(1)} t',
              ),
            ),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
