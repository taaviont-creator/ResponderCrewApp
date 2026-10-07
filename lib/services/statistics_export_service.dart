import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart'
    show SharePlus, ShareParams, ShareResultStatus;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/statistics_workspace.dart';

enum StatisticsExportResult { saved, shared, cancelled }

Future<Uint8List> statisticsPdf(
  StatisticsDataset table,
  ByteData regular,
  ByteData bold,
) async {
  final document = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    ),
  );
  // Split long cells into continuation rows so a large crew can span pages.
  final rows = <List<String>>[];
  for (final row in table.rows) {
    final cells = row.map(table.cell).toList();
    final chunks = cells
        .map(
          (s) => [
            for (var i = 0; i < s.length; i += 80)
              s.substring(i, (i + 80).clamp(0, s.length)),
          ],
        )
        .toList();
    final count = chunks.fold<int>(1, (n, c) => c.length > n ? c.length : n);
    for (var i = 0; i < count; i++) {
      rows.add([for (final c in chunks) i < c.length ? c[i] : '']);
    }
  }
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      maxPages: rows.length + 20,
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'RespondCrew · ${c.pageNumber}/${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (_) => [
        pw.Text(
          table.title,
          style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        for (final filter in table.filters)
          pw.Text(filter, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          'Ridu: ${table.rows.length}. Puuduv väärtus ei tähenda nulli.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: table.columns,
          data: rows,
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xff155a80),
          ),
          cellAlignment: pw.Alignment.topLeft,
          cellPadding: const pw.EdgeInsets.all(4),
          oddRowDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xffedf3f8),
          ),
        ),
      ],
    ),
  );
  return document.save();
}

class StatisticsExportService {
  Future<StatisticsExportResult> save(
    StatisticsDataset table, {
    required bool pdf,
    required String filename,
    Rect? origin,
  }) async {
    final bytes = pdf
        ? await statisticsPdf(
            table,
            await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
            await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
          )
        : Uint8List.fromList(utf8.encode('\uFEFF${table.csv}'));
    final name = '$filename.${pdf ? 'pdf' : 'csv'}';
    final file = XFile.fromData(
      bytes,
      mimeType: pdf ? 'application/pdf' : 'text/csv',
      name: name,
    );
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
      return result.status == ShareResultStatus.dismissed
          ? StatisticsExportResult.cancelled
          : StatisticsExportResult.shared;
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(
          label: pdf ? 'PDF' : 'CSV',
          extensions: [pdf ? 'pdf' : 'csv'],
        ),
      ],
    );
    if (location == null) return StatisticsExportResult.cancelled;
    // Web XFile.saveTo downloads directly; it does not rely on Web Share.
    await file.saveTo(location.path);
    return StatisticsExportResult.saved;
  }
}
