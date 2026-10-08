import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/equipment_model.dart';
import 'package:respondcrew_app/screens/equipment_screen.dart';
import 'package:respondcrew_app/screens/equipment_care_screen.dart';
import 'package:respondcrew_app/screens/contribution_form_screen.dart';
import 'package:respondcrew_app/services/equipment_service.dart';

EquipmentModel equipment(
  String name,
  String category, {
  String storage = 'shared',
  String assignee = '',
}) => EquipmentModel(
  id: name,
  organizationId: 'org',
  commandId: 'org',
  scope: 'organization',
  ownerUserId: '',
  name: name,
  category: category,
  status: 'broken',
  location: 'Baas',
  nextMaintenanceDate: '',
  note: 'Vajab remonti',
  createdBy: 'admin',
  storage: storage,
  assignedToUserId: assignee,
);
final boat = equipment('Päästepaat', 'vessel');

class CareService extends Fake implements EquipmentService {
  @override
  Future<Map<String, dynamic>> manage(
    String organizationId,
    String action, {
    String? id,
    Map<String, dynamic>? item,
  }) async => {'requests': <dynamic>[], 'hasMore': false};
  final items = [
    boat,
    equipment('Raadio', 'radio'),
    equipment('Kuivülikond', 'safety'),
    equipment('Laovest', 'safety', storage: 'warehouse'),
    equipment('Väljastatud vest', 'safety', assignee: 'u'),
  ];
  int streams = 0;
  @override
  Stream<List<EquipmentModel>> streamVisibleEquipment({
    required String organizationId,
    required String currentUserId,
    required bool canViewMemberPersonalEquipment,
  }) {
    streams++;
    return Stream.value(items);
  }

  @override
  Future<Map<String, dynamic>> care(
    String organizationId,
    String equipmentId, {
    String? cursor,
  }) async => {
    'status': 'broken',
    'note': 'Mootor ei käivitu',
    'canEdit': false,
    'history': [
      {
        'id': 'h',
        'before': null,
        'after': {'status': 'broken', 'note': 'Mootor ei käivitu'},
        'changed': ['status', 'note'],
        'actorName': 'Admin',
        'occurredAt': 1791306000000,
      },
    ],
    'works': [
      {
        'id': 'w',
        'title': 'Mootori remont',
        'type': 'repair',
        'date': '2026-10-06',
        'description': 'Õli vahetatud',
        'confirmedHours': 2.5,
        'crew': [
          {'name': 'Mari', 'confirmed': true, 'hours': 2.5},
          {'name': 'Jüri', 'confirmed': false, 'hours': 1},
        ],
      },
    ],
  };
}

void main() {
  test(
    'technique and supplies are disjoint, stock and issued equipment stay in their own views',
    () {
      expect(boat.appearsIn('technique', 'u'), true);
      expect(boat.appearsIn('supplies', 'u'), false);
      expect(equipment('R', 'radio').appearsIn('technique', 'u'), true);
      expect(equipment('D', 'safety').appearsIn('supplies', 'u'), true);
      expect(equipment('Old', 'other').appearsIn('supplies', 'u'), true);
      expect(
        equipment(
          'T',
          'vessel',
          storage: 'warehouse',
        ).appearsIn('technique', 'u'),
        false,
      );
      expect(
        equipment('T', 'vessel', assignee: 'u').appearsIn('technique', 'u'),
        false,
      );
      expect(
        equipment('T', 'vessel', assignee: 'u').appearsIn('mine', 'u'),
        true,
      );
    },
  );
  testWidgets(
    'five inventory views filter existing records without restarting streams on every selection',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CareService();
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentScreen(
            organizationId: 'org',
            currentUid: 'u',
            canManageEquipment: false,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Päästepaat'), findsOneWidget);
      expect(find.text('Raadio'), findsOneWidget);
      expect(find.text('Kuivülikond'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ühingu varustus'));
      await tester.pumpAndSettle();
      expect(find.text('Kuivülikond'), findsOneWidget);
      expect(find.text('Päästepaat'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ladu'));
      await tester.pumpAndSettle();
      expect(find.text('Laovest'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Minu varustus'));
      await tester.pumpAndSettle();
      expect(find.text('Väljastatud vest'), findsOneWidget);
      expect(service.streams, 1);
      expect(find.text('Muuda olekut'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed condition save retains comment and permits retry at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => EquipmentConditionDialog(
                    status: 'broken',
                    note: '',
                    save: (status, note) async {
                      calls++;
                      if (calls == 1) throw Exception('offline');
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvesta olek'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(find.byType(TextField), 'Mootor ei käivitu');
      await tester.tap(find.text('Salvesta olek'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Mootor ei käivitu'), findsOneWidget);
      expect(
        find.textContaining('Sisestatud andmed jäid alles'),
        findsOneWidget,
      );
      await tester.tap(find.text('Salvesta olek'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(EquipmentConditionDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'member can read history and confirmed repair hours without condition editor',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentCareScreen(
            item: boat,
            organizationId: 'org',
            currentUid: 'u',
            canManage: false,
            service: CareService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Muuda olekut'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hooldus ja remont'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mootori remont'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kinnitatud töö: 2,5 t'), findsOneWidget);
      expect(
        find.textContaining('Jüri · 1,0 t · Ootab kinnitust'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'repair contribution sends equipment identity with the original contribution request',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ContributionFormScreen(
            organizationId: 'org',
            currentUid: 'u',
            canManage: false,
            initialType: 'repair',
            initialEquipment: boat,
            requestId: 'repair',
            saveContribution: (data) async {
              saved = data;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mida tegid?'),
        'Mootori remont',
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Kulunud tunnid'),
        170,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kulunud tunnid'),
        '2,5',
      );
      await tester.scrollUntilVisible(
        find.text('Salvesta panus'),
        170,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvesta panus'));
      await tester.pumpAndSettle();
      expect(saved?['equipmentId'], boat.id);
      expect(saved?['hours'], 2.5);
      expect(saved?['memberIds'], ['u']);
      expect(tester.takeException(), isNull);
    },
  );
}
