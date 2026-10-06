import 'package:flutter/material.dart';

/// Own the single-subscription permission stream for exactly one expanded view.
/// Collapsing cancels it; reopening must obtain a fresh stream.
class OperationLogAccessPanel extends StatefulWidget {
  const OperationLogAccessPanel({
    super.key,
    required this.createStream,
    required this.builder,
  });
  final Stream<bool> Function() createStream;
  final Widget Function(BuildContext, AsyncSnapshot<bool>) builder;
  @override
  State<OperationLogAccessPanel> createState() =>
      _OperationLogAccessPanelState();
}

class _OperationLogAccessPanelState extends State<OperationLogAccessPanel> {
  late final _stream = widget.createStream();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<bool>(stream: _stream, builder: widget.builder);
}
