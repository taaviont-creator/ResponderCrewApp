import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/statistics_model.dart';
import 'package:respondcrew_app/screens/statistics_screen.dart';
import 'package:respondcrew_app/services/statistics_service.dart';

ContributionReport report({bool missingDuty = false, bool canManage = true}) =>
    ContributionReport({
      'canManage': canManage,
      'canRecord': true,
      'trackingStartedAt': '2026-09-28T10:00:00Z',
      'dutyHistoryPending': false,
      'undatedCount': 0,
      'members': [
        {
          'userId': 'u',
          'name': 'Testliige',
          'active': true,
          'dutyHours': missingDuty ? null : 8.5,
          'delayedHours': 1,
          'contributionHours': 2,
          'activityCount': 1,
          'calloutCount': 0,
          'responseCount': 1,
          'pendingCount': 0,
          'unknownHoursCount': 0,
          'categories': {
            'groundskeeping': {'count': 1, 'hours': 2},
          },
          'entries': [
            {
              'id': 'a',
              'kind': 'activity',
              'category': 'groundskeeping',
              'title': 'Sadama niitmine',
              'date': '2026-09-28T10:00:00Z',
              'hours': 2,
              'confirmed': true,
            },
          ],
        },
      ],
    });

class ReportService extends Fake implements StatisticsService {
  ReportService(this.result);
  final ContributionReport result;
  int loads = 0;
  @override
  Future<ContributionReport> load({
    required String organizationId,
    required DateTime from,
    required DateTime to,
  }) async {
    loads++;
    return result;
  }
}

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'member statistics shows own contribution, preserves organization reading and hides exports at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = ReportService(
          report(canManage: false, missingDuty: true),
        );
        Widget screen(String org) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: StatisticsScreen(
            organizationId: org,
            currentUid: 'u',
            canViewStatistics: true,
            canViewOrganizationCertificates: false,
            service: service,
          ),
        );
        await tester.pumpWidget(screen('org'));
        await tester.pumpAndSettle();
        expect(find.text('Minu panus'), findsOneWidget);
        expect(find.text('Liikmete panus'), findsNothing);
        expect(find.text('CSV'), findsNothing);
        expect(
          find.textContaining('pole sellel perioodil piisavalt andmeid'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Minu osalemised ja panused (1)'),
          250,
        );
        await tester.tap(find.text('Minu osalemised ja panused (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Sadama niitmine'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Vaata ühingu ülevaadet'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Vaata ühingu ülevaadet'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Liikmete panus'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Liikmete panus'), findsOneWidget);
        expect(find.text('CSV'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(screen('other-org'));
        await tester.pumpAndSettle();
        expect(find.text('Liikmete panus'), findsNothing);
        expect(service.loads, 2);
      },
    );
  }
  test(
    'CSV preserves unknown duty and separates confirmed attendance from response',
    () {
      final data = report(missingDuty: true);
      final csv = contributionCsv(data);
      expect(csv, contains('"Testliige";"";"1";"0";"1";"2"'));
      expect(csv, contains('Sadama niitmine'));
      expect(csv, contains('Heakord / niitmine'));
      data.members.first.data['name'] = '=HYPERLINK("bad")';
      expect(contributionCsv(data), contains("'=HYPERLINK"));
    },
  );
  testWidgets(
    'phone layout shows measured contribution and expands the underlying work',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ReportService(report());
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
      expect(find.text('Statistika'), findsOneWidget);
      expect(find.text('Panuse tunnid'), findsWidgets);
      expect(find.textContaining('Valveajalugu alates'), findsOneWidget);
      expect(find.text('Minu panus'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('CSV'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('CSV'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Testliige'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Testliige'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testliige'));
      await tester.pumpAndSettle();
      expect(find.text('Sadama niitmine'), findsOneWidget);
      expect(
        find.text('Väljakutsetel osales: 0 • Reageerin-vastuseid: 1'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(service.loads, 1);
    },
  );
  testWidgets('permission denied does not request organization report', (
    tester,
  ) async {
    final service = ReportService(report());
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          organizationId: 'org',
          currentUid: 'u',
          canViewStatistics: false,
          canViewOrganizationCertificates: false,
          service: service,
        ),
      ),
    );
    expect(find.text('Sul puudub statistika vaatamise õigus.'), findsOneWidget);
    expect(service.loads, 0);
  });
}
