import 'package:flutter/material.dart';
import '../models/callout_model.dart';
import '../theme/app_theme.dart';

/// Both real callouts and drills remain reachable. Only the selected lifecycle
/// section builds its cards (and their response subscriptions).
class CalloutListView extends StatefulWidget {
  const CalloutListView({
    super.key,
    required this.callouts,
    required this.itemBuilder,
    this.loading = false,
    this.error,
    this.onRetry,
  });
  final List<CalloutModel> callouts;
  final Widget Function(CalloutModel) itemBuilder;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<CalloutListView> createState() => _CalloutListViewState();
}

class _CalloutListViewState extends State<CalloutListView> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.callouts
        .where((c) => c.status == CalloutStatus.active)
        .toList();
    final completed = widget.callouts
        .where((c) => c.status != CalloutStatus.active)
        .toList();
    final visible = _completed ? completed : active;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Row(
            children: [
              for (final past in [false, true]) ...[
                if (past) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    selected: _completed == past,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _completed == past
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                      ),
                      onPressed: () => setState(() => _completed = past),
                      child: Text(
                        '${past ? 'Lõpetatud' : 'Aktiivsed'}${widget.loading || widget.error != null ? '' : ' (${past ? completed.length : active.length})'}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: widget.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.screenPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.error!, textAlign: TextAlign.center),
                        if (widget.onRetry != null)
                          TextButton(
                            onPressed: widget.onRetry,
                            child: const Text('Proovi uuesti'),
                          ),
                      ],
                    ),
                  ),
                )
              : widget.loading
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.screenPadding),
                    child: Text(
                      _completed
                          ? 'Lõpetatud väljakutseid ei ole.'
                          : 'Aktiivseid väljakutseid ei ole.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  key: ValueKey(_completed),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    0,
                    AppTheme.screenPadding,
                    96,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.itemSpacing),
                  itemBuilder: (_, index) => widget.itemBuilder(visible[index]),
                ),
        ),
      ],
    );
  }
}
