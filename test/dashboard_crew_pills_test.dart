import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/duty_crew.dart';
import 'package:respondcrew_app/theme/app_theme.dart';
import 'package:respondcrew_app/widgets/crew_readiness_card.dart';

const crew = [
  DutyCrewMember(
    userId: 'a',
    name: 'Hannes',
    status: 'onDuty',
    level: 'level2',
  ),
  DutyCrewMember(
    userId: 'b',
    name: 'Taavi Onton',
    status: 'onDuty',
    level: 'level2',
  ),
  DutyCrewMember(userId: 'c', name: 'Tarvo', status: 'onDuty', level: 'level2'),
  DutyCrewMember(userId: 'd', name: 'Tõnu', status: 'onDuty', level: ''),
];

Future<void> render(
  WidgetTester tester, {
  double width = 950,
  double scale = 1,
  List<DutyCrewMember> members = crew,
  Map<String, dynamic>? authoritative,
  bool paused = false,
  String? busy,
  void Function(String, bool)? contact,
  ValueChanged<String>? profile,
  VoidCallback? details,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CrewReadinessView(
            members: members,
            minimumCrew: 3,
            currentUid: 'b',
            memberPreviewLimit: 4,
            authoritative: authoritative,
            organizationPaused: paused,
            pauseReason: 'Hooaeg läbi',
            busyUserId: busy,
            onContact: contact ?? (_, _) {},
            onOpenMember: profile,
            onOpenDetails: details,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'dashboard pills wrap horizontally and expose separate profile, phone, SMS and details actions',
    (tester) async {
      final actions = <String>[];
      await render(
        tester,
        contact: (uid, sms) => actions.add('$uid:$sms'),
        profile: (uid) => actions.add(uid),
        details: () => actions.add('details'),
      );
      expect(find.text('Ühing on reageerimisvalmis'), findsOneWidget);
      expect(find.text('Valves: 4 / 3'), findsOneWidget);
      expect(find.text('II aste: olemas'), findsOneWidget);
      expect(find.text('II aste'), findsNWidgets(3));
      expect(find.text('Aste puudub'), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('crew-pill-a'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('crew-pill-b'))).dy,
      );
      await tester.tap(find.text('Hannes'));
      await tester.tap(find.byTooltip('Helista: Taavi Onton'));
      await tester.tap(find.byTooltip('SMS: Tõnu'));
      await tester.tap(find.text('Detailid'));
      expect(actions, ['a', 'b:false', 'd:true', 'details']);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'long names fit a 320px phone with scale $scale and 48px contact targets',
      (tester) async {
        const name = 'Aleksander Väga Pika Perekonnanimega Merepäästja';
        await render(
          tester,
          width: 320,
          scale: scale,
          members: const [
            DutyCrewMember(
              userId: 'a',
              name: name,
              status: 'onDuty',
              level: 'level2',
            ),
            DutyCrewMember(
              userId: 'b',
              name: 'Jaan',
              status: 'delayed',
              level: 'level1',
              arrivalMinutes: 30,
            ),
          ],
          details: () {},
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Hilinemisega (+30 min)'), findsOneWidget);
        for (final tooltip in [
          'Helista: $name',
          'SMS: $name',
          'Helista: Jaan',
          'SMS: Jaan',
        ]) {
          final size = tester.getSize(find.byTooltip(tooltip));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      },
    );
  }
  testWidgets(
    'delayed II-level member is orange and does not satisfy on-duty qualification',
    (tester) async {
      await render(
        tester,
        members: const [
          DutyCrewMember(
            userId: 'a',
            name: 'Jaan',
            status: 'delayed',
            level: 'level2',
            arrivalMinutes: 15,
          ),
        ],
      );
      expect(find.text('Valves: 0 / 3'), findsOneWidget);
      expect(find.text('II aste: puudub'), findsOneWidget);
      expect(find.text('Ühing ei ole reageerimisvalmis'), findsOneWidget);
      final pill = tester.widget<Material>(
        find.byKey(const ValueKey('crew-pill-a')),
      );
      expect(pill.color, AppColors.delayedSurface);
      expect(find.text('Hilinemisega (+15 min)'), findsOneWidget);
    },
  );
  for (final entry in {
    'unknown': 'Ühingu valmidus teadmata',
    'delayed': 'Ühing reageerib viivitusega',
  }.entries) {
    testWidgets(
      'server ${entry.key} status takes precedence over local green crew counts',
      (tester) async {
        await render(
          tester,
          authoritative: {
            'ready': false,
            'operationalStatus': entry.key,
            'missing': ['Serveri põhjus'],
            'onDutyCount': 4,
            'secondLevelOnDutyCount': 3,
          },
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Ühing on reageerimisvalmis'), findsNothing);
        expect(find.text('Serveri põhjus'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'organization pause retains reason and member contacts; busy contact disables duplicate actions',
    (tester) async {
      await render(tester, paused: true, busy: 'a');
      expect(find.text('Ühing on valvest maas'), findsOneWidget);
      expect(find.text('Hooaeg läbi'), findsOneWidget);
      expect(find.text('Ühing on reageerimisvalmis'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Helista: Hannes',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'SMS: Tõnu',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
