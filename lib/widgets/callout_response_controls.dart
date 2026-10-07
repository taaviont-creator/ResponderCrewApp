import 'package:flutter/material.dart';
import '../models/callout_model.dart';
import '../services/callout_service.dart';

/// The same response document and controls on the dashboard and event detail.
class CalloutResponseControls extends StatefulWidget {
  const CalloutResponseControls({
    super.key,
    required this.calloutId,
    required this.organizationId,
    required this.userId,
    required this.userName,
    required this.active,
    this.enabled = true,
    this.responseStream,
    this.onSave,
  });
  final String calloutId, organizationId, userId, userName;
  final bool active, enabled;
  final Stream<CalloutResponseModel?>? responseStream;
  final Future<void> Function(String, int?, String)? onSave;
  @override
  State<CalloutResponseControls> createState() =>
      _CalloutResponseControlsState();
}

class _CalloutResponseControlsState extends State<CalloutResponseControls> {
  late Stream<CalloutResponseModel?> _stream;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _stream =
        widget.responseStream ??
        CalloutService().streamMyResponse(
          calloutId: widget.calloutId,
          organizationId: widget.organizationId,
          userId: widget.userId,
        );
  }

  @override
  void didUpdateWidget(covariant CalloutResponseControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calloutId != widget.calloutId ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.userId != widget.userId ||
        oldWidget.responseStream != widget.responseStream) {
      _bind();
    }
  }

  Future<void> _save(String response, [int? minutes, String note = '']) async {
    if (_saving || !widget.active || !widget.enabled) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onSave != null) {
        await widget.onSave!(response, minutes, note);
      } else {
        await CalloutService().setMyResponse(
          calloutId: widget.calloutId,
          organizationId: widget.organizationId,
          userId: widget.userId,
          userName: widget.userName,
          response: response,
          responseMinutes: minutes,
          note: note,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Vastust ei saanud salvestada. Proovi uuesti.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delay(CalloutResponseModel? previous) async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _DelayDialog(previous: previous),
    );
    if (result != null && mounted) {
      await _save(CalloutResponseValue.delayed, result.$1, result.$2);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<CalloutResponseModel?>(
    stream: _stream,
    builder: (context, snapshot) {
      final response = snapshot.data;
      final enabled =
          widget.active &&
          widget.enabled &&
          !_saving &&
          !snapshot.hasError &&
          snapshot.connectionState != ConnectionState.waiting;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Minu reageerimine',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical =
                  constraints.maxWidth < 230 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              final buttons = <Widget>[
                for (final option in const [
                  (CalloutResponseValue.responding, 'Tulen'),
                  (CalloutResponseValue.delayed, 'Hilinen'),
                  (CalloutResponseValue.unavailable, 'Ei tule'),
                ])
                  Semantics(
                    selected: response?.response == option.$1,
                    child: OutlinedButton(
                      key: ValueKey('response-${option.$1}'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        backgroundColor: response?.response == option.$1
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        side: BorderSide(
                          width: response?.response == option.$1 ? 2 : 1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onPressed: !enabled
                          ? null
                          : () => option.$1 == CalloutResponseValue.delayed
                                ? _delay(response)
                                : _save(option.$1),
                      child: Text(option.$2, textAlign: TextAlign.center),
                    ),
                  ),
              ];
              return vertical
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: buttons,
                    )
                  : Row(
                      children: [
                        for (var i = 0; i < buttons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(child: buttons[i]),
                        ],
                      ],
                    );
            },
          ),
          if (_saving)
            const Text('Salvestan vastust… Serveri kinnitus on ootel.'),
          if (snapshot.hasError)
            const Text('Vastuse laadimine ebaõnnestus. Kontrolli ühendust.'),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!_saving &&
              !snapshot.hasError &&
              snapshot.connectionState != ConnectionState.waiting)
            Text(switch (response?.response) {
              CalloutResponseValue.responding => 'Sinu vastus: Tulen',
              CalloutResponseValue.delayed =>
                'Sinu vastus: Hilinen${response?.responseMinutes == null ? '' : ' · ${response!.responseMinutes} min'}',
              CalloutResponseValue.unavailable => 'Sinu vastus: Ei tule',
              _ => 'Vastus puudub',
            }, style: Theme.of(context).textTheme.bodySmall),
          if (!widget.active)
            const Text('Väljakutse on lõpetatud. Vastust ei saa enam muuta.'),
        ],
      );
    },
  );
}

class _DelayDialog extends StatefulWidget {
  const _DelayDialog({this.previous});
  final CalloutResponseModel? previous;
  @override
  State<_DelayDialog> createState() => _DelayDialogState();
}

class _DelayDialogState extends State<_DelayDialog> {
  late int _minutes = widget.previous?.responseMinutes ?? 15;
  late final _note = TextEditingController(text: widget.previous?.note ?? '');
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Minu saabumisaeg'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sinu hinnanguline saabumine. See ei muuda väljakutse väljasõidu sihtaega.',
          ),
          DropdownButtonFormField<int>(
            isExpanded: true,
            itemHeight: null,
            initialValue: _minutes,
            decoration: const InputDecoration(labelText: 'Hilinen umbes'),
            items: ({15, 30, 60, _minutes}.toList()..sort())
                .map(
                  (m) => DropdownMenuItem(value: m, child: Text('$m minutit')),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _minutes = value);
            },
          ),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Märkus (soovi korral)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Loobu'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (_minutes, _note.text)),
        child: const Text('Salvesta'),
      ),
    ],
  );
}
