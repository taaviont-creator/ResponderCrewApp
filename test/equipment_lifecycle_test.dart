import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/widgets/equipment_editor.dart';
import 'package:respondcrew_app/widgets/equipment_requests_panel.dart';
import 'package:respondcrew_app/screens/equipment_screen.dart';
import 'package:respondcrew_app/theme/app_theme.dart';
import 'equipment_care_test.dart' show CareService;

class RequestService extends CareService {
  final calls = <String>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> manage(
    String organizationId,
    String action, {
    String? id,
    Map<String, dynamic>? item,
  }) async {
    calls.add(action);
    if (fail && action != 'list') throw Exception('offline');
    return {
      'requests': [
        {
          'id': 'request',
          'submittedByName': 'Mari',
          'item': {
            'name': 'Kuivülikond',
            'category': 'safety',
            'status': 'ok',
            'note': '',
            'location': '',
            'nextMaintenanceDate': '',
          },
        },
      ],
    };
  }

  @override
  Future<void> checkMaintenanceDueNotifications({
    required String organizationId,
    required String createdBy,
    required bool canManageOrganizationEquipment,
  }) async {}
}

void main() {
  testWidgets(
    'own equipment form offers personal or organization ownership with approval explanation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: Scaffold(
            body: EquipmentEditor(chooseOwnership: true, save: (_) async {}),
          ),
        ),
      );
      expect(find.text('Minu isiklik varustus'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ühingu varustus minu käes').last);
      await tester.pumpAndSettle();
      expect(find.text('Saada kinnitamiseks'), findsOneWidget);
      expect(find.textContaining('Admin kinnitab'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'member can cancel own request but does not receive approval controls',
    (tester) async {
      final service = RequestService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                EquipmentRequestsPanel(
                  organizationId: 'org',
                  canManage: false,
                  service: service,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vaata ja kinnita'), findsNothing);
      await tester.tap(find.text('Tühista taotlus'));
      await tester.pumpAndSettle();
      expect(service.calls, ['list']);
      await tester.tap(find.widgetWithText(FilledButton, 'Tühista taotlus'));
      await tester.pumpAndSettle();
      expect(service.calls, contains('cancel'));
    },
  );
  testWidgets(
    'admin reviews request, failure remains visible and can be retried',
    (tester) async {
      final service = RequestService()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                EquipmentRequestsPanel(
                  organizationId: 'org',
                  canManage: true,
                  service: service,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vaata ja kinnita'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sama ese pole juba arvel'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Kinnita'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Toiming ebaõnnestus'), findsOneWidget);
      expect(find.text('Kuivülikond'), findsOneWidget);
    },
  );
  testWidgets(
    'inventory deletion requires confirmation and does not disappear on failure',
    (tester) async {
      final service = RequestService()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentScreen(
            organizationId: 'org',
            currentUid: 'admin',
            canManageEquipment: true,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Varustuse toimingud').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Varustuse toimingud').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kustuta varustus'));
      await tester.pumpAndSettle();
      expect(service.calls, isNot(contains('delete')));
      expect(find.textContaining('Varasemad aruanded'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Kustuta'));
      await tester.pumpAndSettle();
      expect(service.calls, contains('delete'));
      expect(find.textContaining('Kustutamine ebaõnnestus'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}
