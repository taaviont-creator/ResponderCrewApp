import 'package:flutter/material.dart';
import '../models/callout_model.dart';

/// Opens the addressed event independently of the list query. Parent rebuilds
/// and late results from a previous organization must not lose/replace the route.
class CalloutLinkOpener extends StatefulWidget {
  const CalloutLinkOpener({
    super.key,
    required this.organizationId,
    required this.calloutId,
    required this.load,
    required this.detailBuilder,
    required this.child,
    this.onOpened,
  });
  final String organizationId;
  final String? calloutId;
  final Future<CalloutModel?> Function(String organizationId, String calloutId)
  load;
  final Widget Function(CalloutModel) detailBuilder;
  final VoidCallback? onOpened;
  final Widget child;
  @override
  State<CalloutLinkOpener> createState() => _CalloutLinkOpenerState();
}

class _CalloutLinkOpenerState extends State<CalloutLinkOpener> {
  int _generation = 0;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant CalloutLinkOpener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calloutId != widget.calloutId ||
        oldWidget.organizationId != widget.organizationId) {
      _schedule();
    }
  }

  void _schedule() {
    final generation = ++_generation;
    _loading = widget.calloutId?.trim().isNotEmpty == true;
    _error = null;
    if (_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation) _open(generation);
      });
    }
  }

  Future<void> _open(int generation) async {
    final org = widget.organizationId;
    final id = widget.calloutId!.trim();
    try {
      final callout = await widget.load(org, id);
      if (!mounted || generation != _generation) return;
      if (callout == null ||
          callout.id != id ||
          (callout.organizationId.isNotEmpty
                  ? callout.organizationId
                  : callout.commandId) !=
              org) {
        throw StateError('Callout unavailable');
      }
      setState(() => _loading = false);
      final detail = widget.detailBuilder(callout);
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => detail));
      widget.onOpened?.call();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error =
            'Teavituse väljakutset ei saanud avada. Kontrolli ühendust ja ligipääsu ühingule.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_loading || _error != null)
        Positioned.fill(
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Avan väljakutset…'),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          FilledButton(
                            onPressed: () {
                              setState(_schedule);
                            },
                            child: const Text('Proovi uuesti'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _error = null);
                              widget.onOpened?.call();
                            },
                            child: const Text('Ava väljakutsete nimekiri'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
    ],
  );
}
