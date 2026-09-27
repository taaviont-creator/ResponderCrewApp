import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:respondcrew_app/widgets/equipment_item_card.dart';
import 'package:respondcrew_app/widgets/status_badge.dart';
import 'package:respondcrew_app/models/equipment_model.dart';
import 'package:respondcrew_app/models/certificate_reminder_open.dart';
import 'package:respondcrew_app/services/callout_alarm_notification_service.dart';

EquipmentModel item({
  String storage = 'warehouse',
  String assignee = '',
  String scope = EquipmentScope.organization,
  String owner = '',
}) => EquipmentModel(
  id: 'vest',
  organizationId: 'org',
  commandId: 'org',
  scope: scope,
  ownerUserId: owner,
  name: 'Vest',
  category: EquipmentCategory.safety,
  status: EquipmentStatus.needsMaintenance,
  location: 'Ladu',
  nextMaintenanceDate: '',
  note: '',
  createdBy: 'admin',
  storage: storage,
  assignedToUserId: assignee,
);
void main() {
  testWidgets(
    'equipment card fits 320px with large text and long recipient name',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EquipmentItemCard(
                  name: 'Generaator haagisel',
                  description:
                      'Väljastatud: Pikk liikmenimi · Sadama päästejaam',
                  statusLabel: 'Vajab hooldust',
                  statusType: StatusBadgeType.equipmentWarning,
                  statusIcon: Icons.build_outlined,
                  actions: IconButton(
                    onPressed: () {},
                    tooltip: 'Varustuse toimingud',
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Generaator haagisel'), findsOneWidget);
    },
  );
  test(
    'issue moves stock into recipient and member views while keeping condition',
    () {
      final stock = item();
      expect(stock.appearsIn('warehouse', 'me'), isTrue);
      expect(stock.appearsIn('shared', 'me'), isFalse);
      final issued = item(assignee: 'me');
      expect(issued.appearsIn('warehouse', 'me'), isFalse);
      expect(issued.appearsIn('shared', 'me'), isFalse);
      expect(issued.appearsIn('mine', 'me'), isTrue);
      expect(issued.appearsIn('mine', 'other'), isFalse);
      expect(issued.appearsIn('members', 'other'), isTrue);
      expect(issued.status, stock.status);
      expect(item().appearsIn('warehouse', 'me'), isTrue);
    },
  );
  test(
    'legacy/shared and personally-owned items stay separate from warehouse',
    () {
      expect(item(storage: 'shared').appearsIn('shared', 'me'), isTrue);
      final personal = item(scope: EquipmentScope.personal, owner: 'me');
      expect(personal.appearsIn('mine', 'me'), isTrue);
      expect(personal.appearsIn('warehouse', 'me'), isFalse);
      expect(personal.appearsIn('members', 'me'), isFalse);
    },
  );
  test(
    'certificate taps identify the exact member and never become callout taps',
    () {
      final data = {
        'type': 'certificate_reminder',
        'organizationId': 'org',
        'memberUserId': 'member',
        'relatedId': 'cert',
      };
      final event = CertificateReminderOpen.fromData(data)!;
      expect(event.organizationId, 'org');
      expect(event.memberUserId, 'member');
      expect(CalloutNotificationOpenEvent.fromData(data), isNull);
      expect(CertificateReminderOpen.fromPayload('invalid'), isNull);
      expect(
        CertificateReminderOpen.fromData({
          'type': 'certificate_reminder',
          'organizationId': 'org',
        }),
        isNull,
      );
    },
  );
}
