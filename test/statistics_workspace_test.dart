import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/certificate_model.dart';
import 'package:respondcrew_app/models/statistics_model.dart';
import 'package:respondcrew_app/models/statistics_workspace.dart';
import 'package:respondcrew_app/screens/statistics_screen.dart';
import 'package:respondcrew_app/services/statistics_service.dart';
import 'package:respondcrew_app/services/statistics_export_service.dart';
import 'event_statistics_test.dart' show eventRows;

CertificateModel certificate(
  String id,
  String expiry, {
  bool noExpiry = false,
  bool archived = false,
}) => CertificateModel(
  id: id,
  organizationId: 'org',
  commandId: '',
  userId: id,
  userName: 'Liige $id',
  title: 'Raadioside $id',
  type: 'radio',
  issuer: 'PPA',
  issuedAt: '2026-01-01',
  expiresAt: expiry,
  status: 'valid',
  note: '',
  createdBy: id,
  noExpiry: noExpiry,
  archived: archived,
);

class WorkspaceService extends Fake implements StatisticsService {
  bool admin = true, failCertificates = false;
  final scopes = <String>[];
  @override
  Future<ContributionReport> load({
    required String organizationId,
    required DateTime from,
    required DateTime to,
  }) async => ContributionReport({
    'canManage': admin,
    'eventDetails': eventRows,
    'members': [
      for (var i = 0; i < 20; i++)
        {
          'userId': '$i',
          'name': 'Liige $i',
          'dutyHours': i,
          'entries': [],
          'categories': {},
        },
    ],
  });
  @override
  Future<List<CertificateModel>> certificates({
    required String organizationId,
    required String currentUid,
    required bool organizationWide,
  }) async {
    scopes.add('$organizationId/$currentUid/$organizationWide');
    if (failCertificates) throw StateError('Unavailable');
    return [certificate(currentUid, '2026-10-30')];
  }
}

class CapturedExport extends StatisticsExportService {
  StatisticsDataset? data;
  bool? asPdf;
  @override
  Future<StatisticsExportResult> save(
    StatisticsDataset table, {
    required bool pdf,
    required String filename,
    Rect? origin,
  }) async {
    data = table;
    asPdf = pdf;
    return StatisticsExportResult.saved;
  }
}

void main() {
  test(
    'certificate queries distinguish unknown, expired, upcoming and timeless without inventing history',
    () {
      final all = [
        certificate('expired', '2026-10-06'),
        certificate('soon', '2026-11-06'),
        certificate('later', '2026-11-07'),
        certificate('unknown', ''),
        certificate('forever', '', noExpiry: true),
        certificate('archived', '2026-10-30', archived: true),
      ];
      List<CertificateModel> query({
        String status = '',
        String date = '',
        String member = '',
        String search = '',
      }) => filterStatisticsCertificates(
        all,
        now: DateTime(2026, 10, 7),
        from: DateTime(2026, 11, 6),
        to: DateTime(2026, 11, 6),
        status: status,
        dateField: date,
        memberId: member,
        search: search,
      );
      expect(query().length, 5);
      expect(query(status: 'expired').single.id, 'expired');
      expect(query(status: 'expiringSoon').single.id, 'soon');
      expect(query(status: 'unknownExpiry').single.id, 'unknown');
      expect(query(status: 'noExpiry').single.id, 'forever');
      expect(query(date: 'expiry').single.id, 'soon');
      expect(query(member: 'soon', search: 'PPA').single.id, 'soon');
      expect(query(member: 'soon', status: 'expired'), isEmpty);
    },
  );
  test(
    'CSV escapes formulas, multiline values and quotes, preserving unknown values',
    () {
      const table = StatisticsDataset(
        title: 'Test',
        columns: ['Name', 'Hours'],
        rows: [
          ['=bad("x")\nline', null],
          ['Jüri', 0],
        ],
      );
      expect(table.csv, contains("'=bad"));
      expect(table.csv, contains('""x""'));
      expect(table.csv, contains('"Jüri";"0"'));
      expect(table.csv, contains(';""'));
    },
  );
  testWidgets(
    'export includes all pages and respects current event search in CSV and PDF',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final exporter = CapturedExport();
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsScreen(
            organizationId: 'org',
            currentUid: '0',
            canViewStatistics: true,
            canViewOrganizationCertificates: true,
            service: WorkspaceService(),
            exporter: exporter,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liikmed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ekspordi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV tabel · 20 rida'));
      await tester.pumpAndSettle();
      expect(exporter.data!.rows.length, 20);
      await tester.tap(find.text('Sündmused'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pukseerimine');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ekspordi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF kokkuvõte'));
      await tester.pumpAndSettle();
      expect(exporter.asPdf, true);
      expect(exporter.data!.rows.length, 1);
      expect(exporter.data!.rows.single.first, 'Pukseerimine');
      expect(exporter.data!.filters, contains('Otsing: Pukseerimine'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'certificate access follows role and organization changes; failed query cannot export',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = WorkspaceService();
      Widget screen(String org, bool wide) => MaterialApp(
        home: StatisticsScreen(
          organizationId: org,
          currentUid: '0',
          canViewStatistics: true,
          canViewOrganizationCertificates: wide,
          service: service,
        ),
      );
      await tester.pumpWidget(screen('org', true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tunnistused'));
      await tester.pumpAndSettle();
      expect(service.scopes, ['org/0/true']);
      service.admin = false;
      await tester.pumpWidget(screen('other', false));
      await tester.pumpAndSettle();
      expect(find.text('Minu panus'), findsOneWidget);
      await tester.tap(find.text('Tunnistused'));
      await tester.pumpAndSettle();
      expect(service.scopes.last, 'other/0/false');
      expect(find.text('Ekspordi'), findsNothing);
      service.admin = true;
      service.failCertificates = true;
      await tester.pumpWidget(screen('org', true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tunnistused'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Väljavõtet ei koostatud'), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'PDF supports Estonian text and large multiline crews across pages',
    () async {
      final data = StatisticsDataset(
        title: 'Ühingu sündmused',
        columns: ['Sündmus', 'Osalejad', 'Tunnid'],
        filters: ['Eesti aeg'],
        rows: [
          for (var i = 0; i < 40; i++)
            [
              'Pääste $i',
              List.filled(40, 'Jüri Õun – päästja').join(', '),
              null,
            ],
        ],
      );
      final bytes = await statisticsPdf(
        data,
        ByteData.sublistView(
          File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
        ),
        ByteData.sublistView(
          File('assets/fonts/NotoSans-Bold.ttf').readAsBytesSync(),
        ),
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(5000));
    },
  );
}
