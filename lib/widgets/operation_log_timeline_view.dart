import 'package:flutter/material.dart';

import '../models/operation_log_model.dart';
import '../services/operation_log_service.dart';

/// Displays the notes and full event timeline for a single operation log.
///
/// Subscribes to [OperationLogService.streamLogEvents] and renders:
/// - a loading indicator while waiting for the first batch of data
/// - an error message on failure
/// - separate "Märkmed" and "Ajajoon" sections once data arrives
///
/// The stream is created once in [initState] and only recreated when
/// [operationLogId] or [organizationId] changes.  Keeping the stream stable
/// prevents [StreamBuilder] from resetting to [ConnectionState.waiting] (and
/// hiding the timeline) every time the parent card rebuilds.
class OperationLogTimelineView extends StatefulWidget {
  const OperationLogTimelineView({
    super.key,
    required this.operationLogId,
    required this.organizationId,
  });

  final String operationLogId;
  final String organizationId;

  @override
  State<OperationLogTimelineView> createState() =>
      _OperationLogTimelineViewState();
}

class _OperationLogTimelineViewState extends State<OperationLogTimelineView> {
  late Stream<List<OperationLogEventModel>> _eventStream;

  @override
  void initState() {
    super.initState();
    _eventStream = _buildStream();
  }

  @override
  void didUpdateWidget(OperationLogTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operationLogId != widget.operationLogId ||
        oldWidget.organizationId != widget.organizationId) {
      setState(() => _eventStream = _buildStream());
    }
  }

  Stream<List<OperationLogEventModel>> _buildStream() =>
      OperationLogService().streamLogEvents(
        operationLogId: widget.operationLogId,
        organizationId: widget.organizationId,
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OperationLogEventModel>>(
      stream: _eventStream,
      builder: (context, eventSnapshot) {
        // Show spinner only while waiting for the very first data.
        // Guard against hasData so that a stream recreation does not blank
        // the timeline when data was already loaded.
        if (eventSnapshot.connectionState == ConnectionState.waiting &&
            !eventSnapshot.hasData) {
          return const LinearProgressIndicator();
        }
        if (eventSnapshot.hasError) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Text('Sündmuste ajaloo laadimine ebaõnnestus.'),
          );
        }

        final events =
            eventSnapshot.data ?? const <OperationLogEventModel>[];
        if (events.isEmpty) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Märkmed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Märkmeid pole lisatud.'),
              SizedBox(height: 12),
              Text(
                'Ajajoon',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Sündmuste ajalugu puudub.'),
            ],
          );
        }

        final notes = events
            .where((event) => event.type == OperationLogEventType.manualNote)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Märkmed',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (notes.isEmpty)
              const Text('Märkmeid pole lisatud.')
            else
              ...notes.map(_buildEventTile),
            const SizedBox(height: 12),
            const Text(
              'Ajajoon',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...events.map(_buildEventTile),
          ],
        );
      },
    );
  }

  Widget _buildEventTile(OperationLogEventModel event) {
    final otherDescription = _otherQuickActionDescription(event);
    final title = _eventTitle(event, otherDescription);
    final subtitleLines = [
      if (event.type == OperationLogEventType.manualNote) 'Käsitsi märge',
      ?otherDescription,
      if (otherDescription == null && event.description.isNotEmpty)
        event.description,
      if (event.latitude != null && event.longitude != null)
        _formatCoordinates(event),
      if (event.createdAt != null) _shortDateTime(event.createdAt!),
    ];

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_eventIcon(event.type)),
      title: Text(title),
      subtitle:
          subtitleLines.isEmpty ? null : Text(subtitleLines.join('\n')),
    );
  }

  String _eventTitle(OperationLogEventModel event, String? otherDescription) {
    if (otherDescription != null) return 'Muu';
    if (event.type == OperationLogEventType.manualNote &&
        event.text.isNotEmpty) {
      return event.text;
    }
    return event.title;
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case OperationLogEventType.summarySaved:
        return Icons.summarize_outlined;
      case OperationLogEventType.quickAction:
        return Icons.bolt;
      case OperationLogEventType.manualNote:
        return Icons.notes;
      default:
        return Icons.history;
    }
  }

  String _shortDateTime(DateTime value) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final date = '${twoDigits(value.day)}.${twoDigits(value.month)}';
    final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
    return '$date $time';
  }

  String? _otherQuickActionDescription(OperationLogEventModel event) {
    const prefix = 'Muu: ';
    if (event.type != OperationLogEventType.quickAction ||
        !event.title.startsWith(prefix)) {
      return null;
    }

    final description = event.title.substring(prefix.length).trim();
    return description.isEmpty ? null : description;
  }

  String _formatCoordinates(OperationLogEventModel event) {
    final latitude = event.latitude!.toStringAsFixed(5);
    final longitude = event.longitude!.toStringAsFixed(5);
    final accuracy = event.accuracyMeters;
    if (accuracy == null) {
      return 'GPS: $latitude, $longitude';
    }
    return 'GPS: $latitude, $longitude (~${accuracy.round()} m)';
  }
}
