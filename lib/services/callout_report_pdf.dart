import '../models/equipment_model.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

List<Map<String, dynamic>> _rows(dynamic value) => (value as List? ?? [])
    .map((v) => Map<String, dynamic>.from(v as Map))
    .toList();
String reportDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Märkimata';
  String two(int n) => n.toString().padLeft(2, '0');
  final offset = date.timeZoneOffset;
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)} (UTC${offset.isNegative ? '-' : '+'}${two(offset.inHours.abs())}:${two(offset.inMinutes.abs() % 60)})';
}

/// Projects the existing event, crew and log. No duplicate report data is saved.
Future<Uint8List> buildCalloutReportPdf(
  Map<String, dynamic> data, {
  required ByteData regularFont,
  required ByteData boldFont,
  bool includePrivate = false,
}) async {
  final report = Map<String, dynamic>.from(data['report'] as Map? ?? {});
  final event = Map<String, dynamic>.from(data['callout'] as Map? ?? {});
  final selected = Set<String>.from(report['equipmentIds'] as List? ?? []);
  final private = includePrivate && data['canEdit'] == true;
  final navy = PdfColor.fromHex('#123249');
  final widgets = <pw.Widget>[];
  void heading(String text) => widgets.add(
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: navy,
        ),
      ),
    ),
  );
  // Separate blocks allow long free text to flow over page boundaries.
  void paragraph(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      widgets.add(pw.Text('Lisamata'));
      return;
    }
    for (final line in text.split('\n')) {
      for (var start = 0; start < line.length || start == 0;) {
        var end = (start + 700).clamp(0, line.length);
        if (end < line.length) {
          final space = line.lastIndexOf(' ', end);
          if (space > start) end = space + 1;
        }
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(line.substring(start, end)),
          ),
        );
        if (end == line.length) break;
        start = end;
      }
    }
  }

  void field(String name, dynamic value) => paragraph(
    '$name: ${value == null || value.toString().isEmpty ? 'Märkimata' : value}',
  );
  heading(
    event['isTest'] == true
        ? 'TEST-/PROOVISÜNDMUS – ei ole ametlik aruanne'
        : 'Merepäästetööde aruanne',
  );
  paragraph(data['organizationName']);
  paragraph(report['status'] == 'completed' ? 'Aruanne valmis' : 'MUSTAND');
  if (private) paragraph('Sisaldab piiratud ligipääsuga isikuandmeid.');
  heading('Sündmuse põhiandmed');
  field('Sündmus', event['title']);
  field('ID', event['id']);
  field('Tüüp', event['calloutType'] == 'tross' ? 'Trossi / mereabi' : 'SAR');
  field('Algus', reportDate(event['startedAt'] ?? event['createdAt']));
  field('Lõpp', reportDate(event['endedAt'] ?? event['closedAt']));
  field('Asukoht', event['location']);
  if (event['latitude'] != null && event['longitude'] != null) {
    field('Koordinaadid', '${event['latitude']}, ${event['longitude']}');
  }
  field('Koostaja', data['authorName']);
  field('Meeskonna juht', data['leaderName']);
  heading('Reageerinud meeskond');
  final crew = _rows(data['crew']);
  if (crew.isEmpty) paragraph('Osalejaid pole kinnitatud.');
  for (final member in crew) {
    final level = member['level'] == 'level2'
        ? 'II aste'
        : member['level'] == 'level1'
        ? 'I aste'
        : 'aste märkimata';
    paragraph(
      '${member['name']} · $level${member['levelAtConfirmation'] == true ? '' : ' (praegune aste)'}${member['hours'] == null ? '' : ' · ${member['hours']} t'}',
    );
  }
  final gear = _rows(
    data['equipment'],
  ).where((e) => selected.contains(e['id']));
  for (final group in EquipmentCategory.groupEquipment(gear).entries) {
    heading(group.key);
    for (final item in group.value) {
      final registration =
          (report['equipmentRegistration'] as Map?)?[item['id']] ??
          item['registrationNumber'] ??
          '';
      paragraph(
        '${item['name']}${registration.toString().isEmpty ? '' : ' · $registration'}',
      );
    }
  }
  heading('Sündmuse kokkuvõte');
  paragraph(data['summary']);
  heading('Tulemus');
  paragraph(data['outcome']);
  heading('Operatiivlogi');
  final timeline = _rows(data['timeline'])
    ..sort(
      (a, b) =>
          (DateTime.tryParse(
                    (a['occurredAt'] ?? a['createdAt'] ?? '').toString(),
                  )?.millisecondsSinceEpoch ??
                  8640000000000000)
              .compareTo(
                DateTime.tryParse(
                      (b['occurredAt'] ?? b['createdAt'] ?? '').toString(),
                    )?.millisecondsSinceEpoch ??
                    8640000000000000,
              ),
    );
  if (timeline.isEmpty) paragraph('Logikanded puuduvad.');
  for (final entry in timeline) {
    paragraph(
      '${reportDate(entry['occurredAt'] ?? entry['createdAt'])} – ${entry['title'] ?? ''}',
    );
    paragraph(entry['text'] ?? entry['description']);
    paragraph(
      entry['origin'] == 'system' || entry['type'] == 'system'
          ? 'Automaatne kirje'
          : 'Liikme kirje',
    );
    if (entry['latitude'] != null && entry['longitude'] != null) {
      field('GPS', '${entry['latitude']}, ${entry['longitude']}');
    }
  }
  if (private) {
    heading('Seotud isikud · piiratud ligipääs');
    for (final person in _rows(data['persons'])) {
      for (final label in {
        'name': 'Nimi',
        'contact': 'Kontakt',
        'identifier': 'Isikukood / tunnus',
        'role': 'Roll',
        'notes': 'Märkused',
      }.entries) {
        field(label.value, person[label.key]);
      }
      widgets.add(pw.SizedBox(height: 8));
    }
  }
  if (private && _rows(data['attachments']).isNotEmpty) {
    heading('Manuste loend · failid säilivad sündmuse juures');
    for (final attachment in _rows(data['attachments'])) {
      paragraph(attachment['name']);
    }
  }
  heading('Ettepanekud ja tähelepanekud');
  paragraph(report['suggestions']);
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 200,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regularFont),
        bold: pw.Font.ttf(boldFont),
      ),
      build: (_) => widgets,
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('RespondCrew', style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    ),
  );
  return document.save();
}
