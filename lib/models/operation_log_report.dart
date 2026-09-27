import 'operation_log_model.dart';

/// A factual extract of stored events, available before and after completion.
/// Missing positions or times are never inferred from another event.
String buildOperationLogReport(
  OperationLogModel log,
  List<OperationLogEventModel> events,
) {
  final ordered = events
      .where(
        (event) =>
            event.operationLogId == log.id &&
            (event.organizationId.isNotEmpty
                    ? event.organizationId
                    : event.commandId) ==
                (log.organizationId.isNotEmpty
                    ? log.organizationId
                    : log.commandId),
      )
      .toList();
  ordered.sort((a, b) {
    if (a.createdAt == null && b.createdAt != null) return 1;
    if (b.createdAt == null && a.createdAt != null) return -1;
    final timeOrder = a.createdAt?.compareTo(b.createdAt!) ?? 0;
    return timeOrder == 0 ? a.id.compareTo(b.id) : timeOrder;
  });
  const statuses = {
    OperationLogStatus.open: 'Avatud',
    OperationLogStatus.enRoute: 'Teel',
    OperationLogStatus.onScene: 'Kohal',
    OperationLogStatus.inProgress: 'Tegevuses',
    OperationLogStatus.completed: 'Lõpetatud',
    OperationLogStatus.returnedToBase: 'Baasis tagasi',
  };
  final lines = <String>[
    log.title,
    'Staatus: ${statuses[OperationLogStatus.normalize(log.status)]}',
    'Logi algus: ${operationLogEventTime(log.timestamp ?? log.createdAt)}',
    if (log.createdByName.isNotEmpty) 'Logi alustaja: ${log.createdByName}',
    if (log.description.isNotEmpty) log.description,
    '',
    'Sündmuste ajalugu',
    if (ordered.isEmpty) 'Salvestatud sündmusi ei ole.',
  ];
  for (final event in ordered) {
    final title = event.text.isNotEmpty ? event.text : event.title;
    lines.add('${operationLogEventTime(event.createdAt)} — $title');
    if (event.description.isNotEmpty && event.description != title) {
      lines.add(event.description);
    }
    lines.add('Autor: ${event.createdByName.isNotEmpty ? event.createdByName : event.createdBy.isNotEmpty ? event.createdBy : 'Teadmata'}');
    lines.add(operationLogEventLocation(event));
    lines.add('');
  }
  if (log.summary.isNotEmpty) lines.addAll(['Lõppkokkuvõte', log.summary, '']);
  if (log.outcome.isNotEmpty) lines.addAll(['Tulemus', log.outcome]);
  return lines.join('\n').trim();
}

String operationLogEventTime(DateTime? value) {
  if (value == null) return 'Kellaaeg pole salvestatud';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String operationLogEventLocation(OperationLogEventModel event) {
  final lat = event.latitude;
  final lon = event.longitude;
  if (lat == null ||
      lon == null ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 90 ||
      lon.abs() > 180) {
    return 'Asukohta ei salvestatud';
  }
  final accuracy = event.accuracyMeters;
  final accuracyLabel = accuracy != null && accuracy.isFinite && accuracy >= 0
      ? ' (täpsus ~${accuracy.round()} m)'
      : '';
  return 'GPS: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}$accuracyLabel';
}
