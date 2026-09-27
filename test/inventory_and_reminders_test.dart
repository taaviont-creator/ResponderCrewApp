import 'package:flutter_test/flutter_test.dart';
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
