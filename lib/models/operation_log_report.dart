import 'package:cloud_firestore/cloud_firestore.dart';
import 'operation_log_model.dart';

/// A factual extract of stored events, available before and after completion.
/// Missing positions or times are never inferred from another event.
String buildOperationLogReport(
  OperationLogModel log,
  List<OperationLogEventModel> events, {
  List<Map<String, dynamic>> participants = const [],
  List<Map<String, dynamic>> attendanceHistory = const [],
}) {
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
    if (a.eventTime == null && b.eventTime != null) return 1;
    if (b.eventTime == null && a.eventTime != null) return -1;
    final timeOrder = a.eventTime?.compareTo(b.eventTime!) ?? 0;
    return timeOrder == 0 ? a.id.compareTo(b.id) : timeOrder;
  });
  final lines = <String>[
    log.title,
    'Staatus: ${OperationLogStatus.label(log.status)}',
    'Logi algus: ${operationLogEventTime(log.timestamp ?? log.createdAt)}',
    if (log.createdByName.isNotEmpty) 'Logi alustaja: ${log.createdByName}',
    if (log.description.isNotEmpty) log.description,
    '',
    if (log.calloutId != null)
      buildAttendanceReport(log, participants, attendanceHistory),
    'Sündmuste ajalugu',
    if (ordered.isEmpty) 'Salvestatud sündmusi ei ole.',
  ];
  for (final event in ordered) {
    final title = event.text.isNotEmpty ? event.text : event.title;
    lines.add('${operationLogEventTime(event.eventTime)} — $title');
    if (event.description.isNotEmpty && event.description != title) {
      lines.add(event.description);
    }
    if (event.occurredAt != null) {
      lines.add('Lisatud: ${operationLogEventTime(event.createdAt)}');
    }
    if (event.summarySnapshot.isNotEmpty) {
      lines.add('Kokkuvõte: ${event.summarySnapshot}');
    }
    lines.add(
      'Autor: ${event.createdByName.isNotEmpty
          ? event.createdByName
          : event.createdBy.isNotEmpty
          ? event.createdBy
          : 'Teadmata'}',
    );
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

String buildAttendanceReport(
  OperationLogModel log,
  List<Map<String, dynamic>> participants,
  List<Map<String, dynamic>> history,
) {
  final org = log.organizationId.isNotEmpty
      ? log.organizationId
      : log.commandId;
  bool matches(Map<String, dynamic> p) =>
      p['organizationId'] == org && p['calloutId'] == log.calloutId;
  String status(dynamic p) => p == null
      ? 'Märkimata'
      : p['status'] == 'confirmed'
      ? 'Osales${p['hours'] == null ? '' : ' (${p['hours']} t)'}'
      : 'Ei osalenud';
  DateTime? date(dynamic value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;
  final people = participants
      .where((p) => matches(p) && p['status'] == 'confirmed')
      .toList();
  final changes = history.where(matches).toList()
    ..sort(
      (a, b) => (date(a['createdAt']) ?? DateTime(1970)).compareTo(
        date(b['createdAt']) ?? DateTime(1970),
      ),
    );
  return <String>[
    'Väljakutse osalejad',
    if (people.isEmpty) 'Osalejaid pole veel kinnitatud.',
    for (final p in people)
      '${p['userName'] ?? 'Liige'} — ${p['hours'] == null ? 'tunnid märkimata' : '${p['hours']} t'}',
    if (changes.isNotEmpty) '',
    if (changes.isNotEmpty) 'Osalejate muudatuste ajalugu',
    for (final c in changes)
      '${operationLogEventTime(date(c['createdAt']))} — ${c['userName'] ?? 'Liige'}: ${status(c['before'])} → ${status(c['after'])}. Muutja: ${c['createdByName'] ?? c['createdBy'] ?? 'Teadmata'}',
    '',
  ].join('\n');
}
