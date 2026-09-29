import 'package:flutter/material.dart';
import '../models/operation_log_model.dart';

/// Large, single-tap controls. Only returning to base closes the log.
class OperationLogActions extends StatefulWidget {
  const OperationLogActions({
    super.key,
    required this.status,
    required this.onAction,
    required this.onComment,
    this.appendOnly = false,
  });

  final String status;
  final bool appendOnly;
  final Future<void> Function(String action) onAction;
  final Future<void> Function() onComment;

  @override
  State<OperationLogActions> createState() => _OperationLogActionsState();
}

class _OperationLogActionsState extends State<OperationLogActions> {
  bool _saving = false;
  String? _message;
  bool _failed = false;

  Future<void> _run(String title, {bool comment = false}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      if (title == 'Tagasi baasis') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lõpeta op-logi?'),
            content: const Text(
              'Kinnitad baasi jõudmise. Kommentaare, kokkuvõtet ja osalejaid saad täiendada ka hiljem.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Jätka logi'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lõpeta op-logi'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      if (comment) {
        await widget.onComment();
      } else {
        await widget.onAction(title);
        if (mounted) {
          setState(() {
            _message = 'Salvestatud: $title';
            _failed = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Salvestamine ebaõnnestus. Proovi uuesti.';
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = OperationLogStatus.normalize(widget.status);
    final active = status != OperationLogStatus.returnedToBase;
    final onScene =
        status == OperationLogStatus.onScene ||
        status == OperationLogStatus.inProgress;
    final actions = <(String, IconData)>[
      if (active && (widget.appendOnly || status == OperationLogStatus.open))
        ('Väljasõit', Icons.directions_boat_outlined),
      if (active && (widget.appendOnly || status == OperationLogStatus.open ||
          status == OperationLogStatus.enRoute))
        ('Sündmuskohal', Icons.place_outlined),
      if (active && (widget.appendOnly || status == OperationLogStatus.onScene)) ('Otsing algas', Icons.search),
      if (active && (widget.appendOnly || onScene)) ...[
        ('Kannatanu leitud', Icons.person_outline),
        ('Pukseerimine alustatud', Icons.directions_boat),
      ],
      if (active && status != OperationLogStatus.completed)
        ('Sündmuskohal tegevused tehtud', Icons.task_alt),
      if (active && (widget.appendOnly || status == OperationLogStatus.completed)) ...[
        ('Tagasisõit', Icons.keyboard_return),
        if (!widget.appendOnly) ('Tagasi baasis', Icons.home_outlined),
      ],
      if (active) ...[('Teade edastatud', Icons.radio_outlined),
        ('Sündmus lõpetatud', Icons.flag_outlined)],
    ];
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      alignment: Alignment.centerLeft,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active) ...[
          const Text(
            'Kiirtegevused',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Üks vajutus salvestab tegevuse, aja ja võimalusel asukoha.',
          ),
          if (widget.appendOnly) const Text('Lisad logimärkeid. Sündmuse ja logi olekut saab muuta sündmuse juht.'),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth >= 600 &&
                      MediaQuery.textScalerOf(context).scale(18) <= 22
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: width,
                      child: FilledButton.icon(
                        style: style,
                        onPressed: _saving ? null : () => _run(action.$1),
                        icon: Icon(action.$2, size: 28),
                        label: Text(action.$1, softWrap: true),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: _saving ? null : () => _run('Kommentaar', comment: true),
          icon: const Icon(Icons.add_comment_outlined, size: 28),
          label: const Text('Lisa op-logisse kommentaar'),
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Salvestan…', semanticsLabel: 'Salvestan tegevust'),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: TextStyle(
                  color: _failed ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
