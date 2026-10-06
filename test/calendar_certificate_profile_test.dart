import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/certificate_model.dart';
import 'package:respondcrew_app/models/availability_model.dart';
import 'package:respondcrew_app/models/planned_unavailability_model.dart';
import 'package:respondcrew_app/models/planned_unavailability_rule_model.dart';
import 'package:respondcrew_app/widgets/app_date_field.dart';
import 'package:respondcrew_app/widgets/certificate_editor.dart';
import 'package:respondcrew_app/widgets/member_duty_calendar.dart';
import 'package:respondcrew_app/widgets/member_profile_section.dart';

CertificateModel certificate({
  String expiry = '2027-10-06',
  bool lifetime = false,
}) => CertificateModel(
  id: 'c',
  organizationId: 'org',
  commandId: 'org',
  userId: 'u',
  userName: 'Taavi',
  title: 'Raadioside tunnistus',
  type: 'radio',
  issuer: 'Väljaandja',
  issuedAt: '2025-10-06',
  expiresAt: expiry,
  status: 'valid',
  note: '',
  createdBy: 'admin',
  number: 'ABC-123',
  noExpiry: lifetime,
);

void main() {
  test(
    'calendar dates are strict and retain their day without timezone conversion',
    () {
      expect(parseCalendarDate('2026-02-30'), isNull);
      expect(parseCalendarDate('31.04.2026'), isNull);
      expect(parseCalendarDate('2024-02-29'), DateTime(2024, 2, 29));
      expect(calendarDateIso(parseCalendarDate('6.10.2026')!), '2026-10-06');
      expect(calendarDateLabel(parseCalendarDate('2026-10-06')), '06.10.2026');
    },
  );

  test(
    'legacy unknown expiry is distinct from explicit lifetime and expiry boundaries',
    () {
      final now = DateTime(2026, 10, 6);
      expect(certificate(expiry: '').displayStatusAt(now), 'unknownExpiry');
      expect(
        certificate(expiry: '', lifetime: true).displayStatusAt(now),
        'valid',
      );
      expect(certificate(expiry: '2026-10-05').displayStatusAt(now), 'expired');
      expect(
        certificate(expiry: '2026-10-06').displayStatusAt(now),
        'expiringSoon',
      );
      expect(
        certificate(expiry: '2026-11-05').displayStatusAt(now),
        'expiringSoon',
      );
      expect(certificate(expiry: '2026-11-06').displayStatusAt(now), 'valid');
      expect(certificate().toMap()['number'], 'ABC-123');
    },
  );

  testWidgets(
    'calendar field selects a date, displays Estonian format, and clears optional value',
    (tester) async {
      DateTime? selected = DateTime(2026, 10, 6);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppDateField(
                label: 'Kehtib kuni',
                value: selected,
                optional: true,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('06.10.2026'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('7').last);
      await tester.tap(find.text('Vali'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 10, 7));
      expect(find.text('07.10.2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Tühjenda: Kehtib kuni'));
      await tester.pump();
      expect(selected, isNull);
    },
  );

  for (final width in [320.0, 900.0]) {
    testWidgets(
      'certificate editor retains values after failed save at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        CertificateDraft? saved;
        var attempts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => CertificateEditor(
                      existing: certificate(),
                      save: (draft) async {
                        attempts++;
                        if (attempts == 1) throw StateError('offline');
                        saved = draft;
                      },
                    ),
                  ),
                  child: const Text('Ava'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ava'));
        await tester.pumpAndSettle();
        expect(find.text('ABC-123'), findsOneWidget);
        await tester.ensureVisible(find.text('Tähtajatu tunnistus'));
        await tester.tap(find.text('Tähtajatu tunnistus'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvesta muudatused'));
        await tester.pumpAndSettle();
        expect(find.byType(CertificateEditor), findsOneWidget);
        expect(find.text('ABC-123'), findsOneWidget);
        await tester.tap(find.text('Salvesta muudatused'));
        await tester.pumpAndSettle();
        expect(saved?.number, 'ABC-123');
        expect(saved?.noExpiry, isTrue);
        expect(saved?.expiresAt, '');
        expect(saved?.issuedAt, '2025-10-06');
        expect(find.byType(CertificateEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty certificate requires name and issue date, expiry is not silently lifetime',
    (tester) async {
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CertificateEditor(save: (_) async => saved = true),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lisa tunnistus'));
      await tester.pumpAndSettle();
      expect(saved, isFalse);
      expect(find.text('Sisesta tunnistuse nimetus.'), findsOneWidget);
      expect(find.text('Vali väljastamise kuupäev.'), findsOneWidget);
      expect(find.text('Vali kuupäev või märgi tähtajatuks.'), findsOneWidget);
    },
  );

  test(
    'duty calendar includes overlapping periods and recurring absences, excluding peers and cancellations',
    () {
      PlannedUnavailabilityModel period(String user, String status) =>
          PlannedUnavailabilityModel(
            id: 'p',
            organizationId: 'org',
            commandId: 'org',
            userId: user,
            startAt: DateTime.utc(2026, 10, 5, 22),
            endAt: DateTime.utc(2026, 10, 6, 10),
            note: 'private',
            status: status,
            createdBy: user,
          );
      const rule = PlannedUnavailabilityRuleModel(
        id: 'r',
        organizationId: 'org',
        commandId: 'org',
        userId: 'u',
        daysOfWeek: [2],
        startTime: '12:00',
        endTime: '13:00',
        startMinute: 720,
        endMinute: 780,
        note: 'private',
        status: 'active',
        createdBy: 'u',
      );
      final lines = memberDayAbsences(
        userId: 'u',
        day: DateTime(2026, 10, 6),
        periods: [
          period('u', 'active'),
          period('other', 'active'),
          period('u', 'cancelled'),
        ],
        rules: [rule],
      );
      expect(lines.length, 2);
      expect(lines.last, contains('korduv'));
      expect(lines.join(), isNot(contains('private')));
    },
  );

  testWidgets(
    'profile sections are open and actions fit a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                MemberProfileSection(
                  title: 'Isiklik ja väljastatud varustus',
                  icon: Icons.inventory_2_outlined,
                  actions: [
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Lisa varustus'),
                    ),
                  ],
                  child: const Text('Kuivülikond'),
                ),
                MemberProfileSection(
                  title: 'Valvegraafik',
                  icon: Icons.calendar_month,
                  child: MemberDutyCalendar(
                    userId: 'u',
                    status: AvailabilityStatus.onDuty,
                    periods: const [],
                    rules: const [],
                    now: DateTime(2026, 10, 6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kuivülikond'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
