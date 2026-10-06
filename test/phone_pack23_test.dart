import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/equipment_model.dart';
import 'package:respondcrew_app/models/notification_preferences.dart';
import 'package:respondcrew_app/models/information_notification_open.dart';
import 'package:respondcrew_app/models/callout_model.dart';
import 'package:respondcrew_app/services/callout_alarm_notification_service.dart';
import 'package:respondcrew_app/screens/login_screen.dart';
import 'package:respondcrew_app/screens/callout_report_screen.dart';
import 'package:respondcrew_app/widgets/own_profile_editor.dart';
import 'package:respondcrew_app/widgets/crew_readiness_card.dart';

void main() {
  test(
    'equipment groups use stored category, unknown legacy values safely become other',
    () {
      final groups = EquipmentCategory.groupEquipment([
        {'id': 'suit', 'name': 'Kuivülikond', 'category': 'safety'},
        {'id': 'boat', 'name': 'Alus', 'category': 'vessel'},
        {'id': 'old', 'name': 'Mootor vana'},
      ]);
      expect(groups['Isikukaitsevarustus']!.single['id'], 'suit');
      expect(groups['Kasutatud alused ja tehnika']!.single['id'], 'boat');
      expect(groups['Muu varustus']!.single['id'], 'old');
      expect(groups.containsKey('Meditsiinivarustus'), isFalse);
      expect(
        EquipmentCategory.normalize('unknown-legacy'),
        EquipmentCategory.other,
      );
    },
  );
  test('notification defaults and user override agree with role policy', () {
    expect(
      NotificationPreferences.resolve(admin: true)['readinessLost'],
      isTrue,
    );
    expect(
      NotificationPreferences.resolve(admin: false)['readinessLost'],
      isFalse,
    );
    expect(
      NotificationPreferences.resolve(
        admin: true,
        stored: {'readinessLost': false},
      )['readinessLost'],
      isFalse,
    );
  });
  test('informative links cannot be mistaken for exact callout links', () {
    final info = {
      'type': 'organizationReadiness',
      'organizationId': 'o',
      'relatedId': 'not-callout',
    };
    expect(
      InformationNotificationOpen.fromData(info)?.type,
      'organizationReadiness',
    );
    expect(CalloutNotificationOpenEvent.fromData(info), isNull);
    for (final type in ['callout_alarm', 'tross_callout']) {
      final event = CalloutNotificationOpenEvent.fromData({
        'type': type,
        'organizationId': 'o',
        'calloutId': 'exact',
      });
      expect(event?.calloutId, 'exact');
      expect(event?.organizationId, 'o');
    }
    expect(
      InformationNotificationOpen.fromData({
        'type': 'platformApplication',
        'organizationId': 'bad/path',
      }),
      isNull,
    );
  });
  test(
    'SAR/Tross quick choices stay editable descriptions with separate structured type',
    () {
      expect(CalloutType.choices(CalloutType.sar), contains('Kadunud isik.'));
      expect(
        CalloutType.choices(CalloutType.tross),
        contains('Aku-/elektririke.'),
      );
      expect(
        CalloutType.choices(CalloutType.tross),
        contains('Alus madalikul kinni.'),
      );
      expect(CalloutType.validTarget(CalloutType.sar, null), isTrue);
      expect(CalloutType.validTarget(CalloutType.tross, 60), isTrue);
    },
  );
  testWidgets(
    'compact login fits small phone and exposes contact without requiring a help URL',
    (tester) async {
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      expect(find.text('RespondCrew'), findsOneWidget);
      expect(
        find.text('Mõeldud vabatahtlikele merepäästeühingutele.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Kontakt: taavi@purtsesar.ee'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kasutusjuhend'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('field editor changes phone only and preserves existing name', (
    tester,
  ) async {
    String? savedName, savedPhone;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnProfileEditor(
            name: 'Taavi',
            phone: '',
            field: 'phone',
            save: (name, phone) async {
              savedName = name;
              savedPhone = phone;
            },
          ),
        ),
      ),
    );
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '+372 5551234');
    await tester.tap(find.text('Salvesta'));
    await tester.pumpAndSettle();
    expect(savedName, 'Taavi');
    expect(savedPhone, '+372 5551234');
  });
  testWidgets(
    'report shows only selected equipment groups and identifies test report',
    (tester) async {
      final data = <String, dynamic>{
        'canEdit': false,
        'organizationName': 'Ühing',
        'report': {
          'equipmentIds': ['suit'],
        },
        'callout': {'title': 'Test', 'status': 'closed', 'isTest': true},
        'equipment': [
          {'id': 'suit', 'name': 'Kuivülikond', 'category': 'safety'},
          {'id': 'boat', 'name': 'Alus', 'category': 'vessel'},
        ],
        'timeline': [],
        'crew': [],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: CalloutReportScreen(
            organizationId: 'o',
            calloutId: 'c',
            loadReport: () async => data,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Varem aruandega seotud muu varustus'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Varem aruandega seotud muu varustus')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Varem aruandega seotud muu varustus'));
      await tester.pumpAndSettle();
      expect(find.text('Kuivülikond'), findsOneWidget);
      expect(find.text('Kasutatud alused ja tehnika'), findsNothing);
      expect(find.text('Meditsiinivarustus'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'live readiness renders server result and compact dashboard omits detailed roster',
    (tester) async {
      final state = <String, dynamic>{
        'ready': false,
        'minimum': 2,
        'missing': ['II astme merepäästja puudub'],
        'unavailableUserIds': <String>[],
        'crew': [
          {
            'userId': 'u',
            'name': 'Mari',
            'status': 'onDuty',
            'level': 'level1',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrewReadinessCard(
              organizationId: 'o',
              currentUid: 'u',
              compact: true,
              streamsForOrganization: (_) => CrewReadinessStreams(
                organization: Stream.value({'dutyPaused': false}),
                members: Stream.value([]),
                availability: const Stream.empty(),
                unavailable: const Stream.empty(),
                minimum: const Stream.empty(),
                readiness: Stream.value(state),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('II astme merepäästja puudub'),
        findsOneWidget,
      );
      expect(find.text('Mari · Mina'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
