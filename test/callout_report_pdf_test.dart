import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/callout_report_pdf.dart';

void main() {
  test(
    'long Estonian report exports offline with the existing log and crew',
    () async {
      final regular = ByteData.sublistView(
        await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes(),
      );
      final bold = ByteData.sublistView(
        await File('assets/fonts/NotoSans-Bold.ttf').readAsBytes(),
      );
      final data = <String, dynamic>{
        'organizationName': 'Näidisühing – Õäöü',
        'canEdit': true,
        'callout': {
          'id': 'test-event',
          'title': 'Alus madalikul kinni',
          'createdAt': '2026-09-01T10:00:00Z',
          'closedAt': '2026-09-01T12:00:00Z',
          'location': 'Purtse sadam',
          'calloutType': 'sar',
        },
        'report': {
          'status': 'completed',
          'equipmentIds': ['boat'],
          'suggestions': 'Täiendavat analüüsi ei vaja.',
        },
        'authorName': 'Koostaja Näidis',
        'leaderName': 'Juht Näidis',
        'crew': [
          {
            'name': 'Päästja Näidis',
            'level': 'level2',
            'levelAtConfirmation': true,
            'hours': 2,
          },
        ],
        'equipment': [
          {'id': 'boat', 'name': 'Päästepaat', 'registrationNumber': 'TEST-01'},
          {'id': 'unused', 'name': 'UNUSED-SECRET'},
        ],
        'summary': List.filled(
          90,
          'Õnnetuse põhjuseks oli mootoririke. Mõlemad abivajajad jõudsid ohutult sadamasse.',
        ).join(' '),
        'outcome': 'Abi osutatud.',
        'persons': [
          {'name': 'PRIVATE-PERSON', 'identifier': 'PRIVATE-ID'},
        ],
        'timeline': List.generate(
          35,
          (i) => {
            'createdAt': DateTime.utc(2026, 9, 1, 10, i).toIso8601String(),
            'title': 'Tegevus $i',
            'description': 'Asukoht ja tegevus märgitud.',
            'origin': 'member',
          },
        ),
      };
      final bytes = await buildCalloutReportPdf(
        data,
        regularFont: regular,
        boldFont: bold,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(10000));
      if (Platform.environment['RESPONDCREW_PDF_QA'] == '1') {
        await File('.local-cache/report-preview.pdf').writeAsBytes(bytes);
      }
    },
  );
}
