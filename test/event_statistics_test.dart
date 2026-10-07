import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/event_statistics.dart';
import 'package:respondcrew_app/models/statistics_model.dart';
import 'package:respondcrew_app/screens/event_statistics_screen.dart';
import 'package:respondcrew_app/screens/statistics_screen.dart';
import 'package:respondcrew_app/services/statistics_service.dart';

final eventRows = [
  {
    'id': 'a',
    'title': 'SAR pääste',
    'type': 'sar',
    'status': 'closed',
    'startedAt': '2023-12-31T22:00:00Z',
    'participants': [
      {'userId': 'u', 'name': 'Mari', 'hours': 2},
      {'userId': 'v', 'name': 'Jüri', 'hours': null},
    ],
  },
  {
    'id': 'b',
    'title': 'Pukseerimine',
    'type': 'tross',
    'status': 'active',
    'startedAt': '2024-02-29T12:00:00Z',
    'participants': [
      {'userId': 'u', 'name': 'Mari', 'hours': 0},
    ],
  },
  {
    'id': 'c',
    'title': 'Osalejateta sündmus',
    'type': 'sar',
    'status': 'cancelled',
    'startedAt': '2024-03-01T12:00:00Z',
    'participants': [],
  },
];
ContributionReport report({bool admin = true, bool legacy = false}) =>
    ContributionReport({
      'canManage': admin,
      'members': [],
      if (!legacy) 'eventDetails': eventRows,
    });

class ExportService extends Fake implements StatisticsService {
  DateTime? from, to;
  @override
  Future<ContributionReport> load({
    required String organizationId,
    required DateTime from,
    required DateTime to,
  }) async {
    this.from = from;
    this.to = to;
    return report();
  }
}

void main() {
  test(
    'filters combine type, status, exact participant identity and text without dropping empty events by default',
    () {
      final events = eventRows.map(EventStatistics.new).toList();
      expect(filterEventStatistics(events).length, 3);
      expect(
        filterEventStatistics(
          events,
          type: 'sar',
          status: 'closed',
          memberId: 'v',
          search: ' PÄÄSTE ',
        ).single.id,
        'a',
      );
      expect(filterEventStatistics(events, memberId: 'u').map((e) => e.id), [
        'a',
        'b',
      ]);
      expect(
        filterEventStatistics(events, type: 'tross', memberId: 'v'),
        isEmpty,
      );
      expect(
        filterEventStatistics(events, status: 'cancelled').single.participants,
        isEmpty,
      );
    },
  );
  test(
    'event CSV includes empty events, known and unknown hours, Tallinn dates and protected spreadsheet cells',
    () {
      final events = [
        ...eventRows,
        {
          ...eventRows.first,
          'id': 'danger',
          'title': '=HYPERLINK("bad")\nÜhing;päev',
        },
      ].map(EventStatistics.new).toList();
      final csv = eventStatisticsCsv(
        events: events,
        organizationId: 'org',
        from: DateTime(2024),
        to: DateTime(2024, 12, 31),
        attendance: false,
      );
      expect(csv, contains('01.01.2024 kell 00:00'));
      expect(csv, contains('Osalejateta sündmus'));
      expect(csv, contains('Mari, Jüri'));
      expect(csv, contains('"\'=HYPERLINK(""bad"")\nÜhing;päev"'));
      expect(csv, contains('"Sündmusi valikus";"4"'));
    },
  );
  test(
    'attendance export contains only selected member and keeps missing hours empty',
    () {
      final events = filterEventStatistics(
        eventRows.map(EventStatistics.new).toList(),
        memberId: 'v',
      );
      final csv = eventStatisticsCsv(
        events: events,
        organizationId: 'org',
        from: DateTime(2024),
        to: DateTime(2024, 12, 31),
        attendance: true,
        memberId: 'v',
      );
      expect(csv, contains('"v";"Jüri";""'));
      expect(csv, isNot(contains('Mari')));
      expect(csv, isNot(contains('Osalejateta sündmus')));
      expect(
        events.single.participants.length,
        2,
      ); // Whole crew remains in the event view.
    },
  );
  for (final admin in [false, true]) {
    testWidgets('export access and legacy state admin=$admin', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EventStatisticsScreen(
            report: report(admin: admin, legacy: true),
            organizationId: 'org',
            from: DateTime(2024),
            to: DateTime(2024, 12, 31),
          ),
        ),
      );
      expect(
        find.textContaining(admin ? 'serveri uuendust' : 'ühingu admin'),
        findsOneWidget,
      );
      expect(find.text('Sündmused CSV'), findsNothing);
    });
  }
  for (final (width, scale) in [(320.0, 2.0), (1100.0, 1.0)]) {
    testWidgets(
      'event query fits $width with scale $scale and expands attendance',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: EventStatisticsScreen(
                report: report(),
                organizationId: 'org',
                from: DateTime(2024),
                to: DateTime(2024, 12, 31),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('SAR pääste'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('SAR pääste'));
        await tester.tap(find.text('SAR pääste'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Jüri'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Tunnid märkimata'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'year selection requests the whole leap year, then opens the same report period',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ExportService();
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsScreen(
            organizationId: 'org',
            currentUid: 'u',
            canViewStatistics: true,
            canViewOrganizationCertificates: false,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vali aasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      expect(service.from, DateTime(2024));
      expect(service.to, DateTime(2024, 12, 31));
      await tester.scrollUntilVisible(
        find.text('Sündmuste väljavõte'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Sündmuste väljavõte'));
      await tester.pumpAndSettle();
      expect(find.text('01.01.2024 – 31.12.2024'), findsOneWidget);
    },
  );
}
