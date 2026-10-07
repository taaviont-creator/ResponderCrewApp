import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/theme/app_theme.dart';
import 'package:respondcrew_app/widgets/app_layout.dart';
import 'package:respondcrew_app/widgets/status_badge.dart';
import 'package:respondcrew_app/widgets/primary_action_button.dart';
import 'package:respondcrew_app/widgets/personal_availability_card.dart';
import 'package:respondcrew_app/widgets/member_profile_section.dart';
import 'package:respondcrew_app/widgets/member_duty_calendar.dart';
import 'package:respondcrew_app/widgets/activity_calendar.dart';
import 'package:respondcrew_app/widgets/operation_log_actions.dart';
import 'package:respondcrew_app/widgets/certificate_editor.dart';
import 'package:respondcrew_app/widgets/operation_note_dialog.dart';
import 'package:respondcrew_app/widgets/equipment_editor.dart';
import 'package:respondcrew_app/screens/equipment_screen.dart';
import 'package:respondcrew_app/screens/equipment_care_screen.dart';
import 'equipment_care_test.dart' show CareService, boat;

class AuditEquipmentService extends CareService {
  @override
  Future<void> checkMaintenanceDueNotifications({
    required String organizationId,
    required String createdBy,
    required bool canManageOrganizationEquipment,
  }) async {}
}

void main() {
  testWidgets(
    'equipment form preserves failed draft and separates condition editing',
    (tester) async {
      var attempts = 0;
      EquipmentDraft? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: Scaffold(
            body: EquipmentEditor(
              existing: boat,
              save: (draft) async {
                attempts++;
                if (attempts == 1) throw StateError('offline');
                result = draft;
              },
            ),
          ),
        ),
      );
      expect(find.text('Olek'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Päästepaat parandatud nimega',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvesta'));
      await tester.pumpAndSettle();
      expect(find.text('Päästepaat parandatud nimega'), findsOneWidget);
      expect(find.textContaining('Andmed jäid vormile alles'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Salvesta'));
      await tester.pumpAndSettle();
      expect(result?.name, 'Päästepaat parandatud nimega');
      expect(result?.status, 'broken');
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      final cases = <String, Widget Function()>{
        'shared components': () => AppScaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StatusBadge(
                    label: 'Hoolduses / kasutusest väljas',
                    type: StatusBadgeType.critical,
                  ),
                  PrimaryActionButton(
                    label: 'Lisa tegevus või koolitus',
                    icon: Icons.add,
                    onPressed: () {},
                  ),
                  PersonalAvailabilityCard(
                    status: 'delayed',
                    minutes: 30,
                    plannedUnavailable: false,
                    saving: false,
                    onSelect: (_) {},
                    onDelayChanged: (_) {},
                  ),
                  MemberProfileSection(
                    title: 'Liikme tunnistused ja kvalifikatsioonid',
                    icon: Icons.school,
                    actions: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Lisa tunnistus'),
                      ),
                    ],
                    child: const Text(
                      'Pika nimetusega vabatahtliku merepäästja tunnistus',
                    ),
                  ),
                  MemberDutyCalendar(
                    userId: 'u',
                    status: 'onDuty',
                    periods: const [],
                    rules: const [],
                    now: DateTime(2026, 10, 7),
                  ),
                  ActivityCalendar(
                    activities: const [],
                    selectedDay: DateTime(2026, 10, 7),
                    onSelected: (_) {},
                  ),
                  OperationLogActions(
                    status: 'onScene',
                    onAction: (_) async {},
                    onComment: () async {},
                  ),
                  SectionHeading(
                    title: 'Pikema nimetusega olulised teavitused',
                    onOpen: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
        'inventory': () => EquipmentScreen(
          organizationId: 'org',
          currentUid: 'admin',
          canManageEquipment: true,
          service: AuditEquipmentService(),
        ),
        'equipment history': () => EquipmentCareScreen(
          item: boat,
          organizationId: 'org',
          currentUid: 'u',
          canManage: false,
          service: AuditEquipmentService(),
        ),
        'certificate form': () =>
            Scaffold(body: CertificateEditor(save: (_) async {})),
        'equipment form': () =>
            Scaffold(body: EquipmentEditor(save: (_) async {})),
        'equipment condition': () => Scaffold(
          body: EquipmentConditionDialog(
            status: 'outOfService',
            note: 'Mootori hooldus',
            save: (_, _) async {},
          ),
        ),
        'operation summary': () => Scaffold(
          body: OperationSummaryDialog(
            summary: 'Pikk sündmuse kokkuvõte',
            outcome: 'Tulemus',
            onSave: (_, _) async {},
          ),
        ),
      };
      for (final entry in cases.entries) {
        testWidgets('${entry.key}: width $width scale $scale', (tester) async {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.maritime,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: entry.value(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final vertical = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          if (vertical.evaluate().isNotEmpty) {
            for (var n = 0; n < 8; n++) {
              await tester.drag(vertical.first, const Offset(0, -350));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
        });
      }
    }
  }
}
