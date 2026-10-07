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
      'member workspace preserves own and organization reading without exports at $width',
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
        expect(find.text('Ekspordi'), findsNothing);
        await tester.scrollUntilVisible(
          find.textContaining('pole sellel perioodil piisavalt andmeid'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.textContaining('pole sellel perioodil piisavalt andmeid'),
          findsOneWidget,
        );
        await tester.drag(find.byType(ListView).first, const Offset(0, 2500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Panused'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('Sadama niitmine'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('Sadama niitmine'), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ühing'));
        await tester.pumpAndSettle();
        expect(find.text('Ühingu ülevaade'), findsOneWidget);
        expect(find.text('Ekspordi'), findsNothing);
        await tester.pumpWidget(screen('other-org'));
        await tester.pumpAndSettle();
        expect(find.text('Minu panus'), findsOneWidget);
        expect(service.loads, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('CSV retains unknown duty and escaped user content', () {
    final data = report(missingDuty: true);
    expect(contributionCsv(data), contains('"Testliige";"";"1";"0";"1";"2"'));
    data.members.first.data['name'] = '=HYPERLINK("bad")';
    expect(contributionCsv(data), contains("'=HYPERLINK"));
  });
  testWidgets('admin can inspect the underlying member entries', (
    tester,
  ) async {
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
    await tester.tap(find.text('Liikmed'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Testliige'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Testliige').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sadama niitmine'), findsOneWidget);
    expect(
      find.text('Väljakutsetel osales: 0 • Reageerin-vastuseid: 1'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('permission denied does not load reports', (tester) async {
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
