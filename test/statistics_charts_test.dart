import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/statistics_chart_data.dart';
import 'package:respondcrew_app/models/statistics_model.dart';
import 'package:respondcrew_app/widgets/statistics_charts.dart';

MemberContribution member(List<Map<String, dynamic>> entries) =>
    MemberContribution({
      'userId': 'u',
      'dutyHours': 100,
      'responseCount': 5,
      'entries': entries,
    });
Map<String, dynamic> entry(
  String category,
  num? hours, {
  bool confirmed = true,
  String kind = 'activity',
}) => {
  'category': category,
  'hours': hours,
  'confirmed': confirmed,
  'kind': kind,
};
const events = {
  'period': 5,
  'sar': 3,
  'tross': 2,
  'closed': 4,
  'cancelled': 1,
  'total': 25,
};

void main() {
  test(
    'confirmed member-hours include callouts but not duty, responses or pending work',
    () {
      final data = ContributionBreakdown.fromMembers([
        member([
          entry('training', 2),
          entry('training', 20, confirmed: false),
          entry('callout', 3, kind: 'callout'),
        ]),
        member([entry('training', 2)]),
      ]);
      expect(data.hours, 7);
      expect(data.rows.first.category, 'training');
      expect(
        data.rows.first.count,
        2,
      ); // Both people contribute to the same activity.
      expect(data.rows.last.hours, 3);
      expect(
        CalloutBreakdown(events).count('period'),
        5,
      ); // Events are not participant totals.
    },
  );
  test(
    'unknown and invalid hours stay unknown, zero remains a measured value',
    () {
      final data = ContributionBreakdown.fromMembers([
        member([
          entry('repair', null),
          entry('repair', double.nan),
          entry('repair', -1),
          entry('maintenance', 0),
          entry('new-category', 1),
        ]),
      ]);
      final repair = data.rows.singleWhere((r) => r.category == 'repair');
      expect(repair.knownHoursCount, 0);
      expect(repair.unknownHoursCount, 3);
      expect(data.unknownHoursCount, 3);
      expect(
        data.rows
            .singleWhere((r) => r.category == 'maintenance')
            .knownHoursCount,
        1,
      );
      expect(data.hours, 1);
      expect(data.rows.first.label, 'Muu tegevus (new-category)');
    },
  );
  test(
    'event distribution separates period, lifetime total and missing values',
    () {
      expect(CalloutBreakdown(events).slices, {'SAR': 3, 'Trossi mereabi': 2});
      expect(
        CalloutBreakdown({...events, 'period': 6}).slices['Muu / määramata'],
        1,
      );
      expect(CalloutBreakdown({}).hasDistribution, false);
      expect(CalloutBreakdown({'period': 5, 'sar': 3}).hasDistribution, false);
      expect(CalloutBreakdown({...events, 'period': 2}).hasDistribution, false);
      expect(
        CalloutBreakdown({
          ...events,
          'period': double.infinity,
        }).hasDistribution,
        false,
      );
      expect(
        CalloutBreakdown({'period': 0, 'sar': 0, 'tross': 0}).hasDistribution,
        true,
      );
    },
  );
  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    testWidgets(
      'charts are labelled and fit width $width with text scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StatisticsCharts(
                      events: events,
                      members: [
                        member([
                          entry('groundskeeping', 2),
                          entry('repair', null),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Panuse jaotus'), findsOneWidget);
        expect(find.text('Tunnid märkimata'), findsOneWidget);
        final barSize = tester.getSize(
          find.byKey(const ValueKey('contribution-bar-groundskeeping')),
        );
        expect(barSize.height, 10);
        expect(barSize.width, greaterThan(0));
        expect(
          find.bySemanticsLabel(
            'Remont: tunnid märkimata, 1 osalemist, 1 osalemisel tunnid puudu',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('SAR: 3'));
        expect(find.text('Trossi mereabi: 2'), findsOneWidget);
        expect(
          find.textContaining('Kõikidel perioodidel kokku: 25'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'empty contribution and absent callouts do not fabricate charts',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatisticsCharts(members: [], events: {}),
          ),
        ),
      );
      expect(
        find.text('Sellel perioodil pole veel kinnitatud panuseid.'),
        findsOneWidget,
      );
      expect(find.text('Väljakutsete jaotus pole saadaval.'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatisticsCharts(
              members: [],
              events: {'period': 0, 'sar': 0, 'tross': 0},
            ),
          ),
        ),
      );
      expect(
        find.text('Sellel perioodil väljakutseid ei olnud.'),
        findsOneWidget,
      );
    },
  );
}
