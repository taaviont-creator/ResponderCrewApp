import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/availability_model.dart';
import 'package:respondcrew_app/models/availability_reminder_settings_model.dart';
import 'package:respondcrew_app/models/planned_unavailability_model.dart';
import 'package:respondcrew_app/models/planned_unavailability_rule_model.dart';
import 'package:respondcrew_app/services/availability_service.dart';
import 'package:respondcrew_app/services/availability_reminder_settings_service.dart';
import 'package:respondcrew_app/services/planned_unavailability_service.dart';
import 'package:respondcrew_app/screens/availability_screen.dart';
import 'package:respondcrew_app/widgets/personal_availability_card.dart';
import 'package:respondcrew_app/widgets/unavailability_editor.dart';
import 'package:respondcrew_app/widgets/activity_date_field.dart';
import 'package:respondcrew_app/theme/app_theme.dart';

PlannedUnavailabilityModel period({
  String status = 'active',
  String org = 'org',
}) => PlannedUnavailabilityModel(
  id: 'period',
  organizationId: org,
  commandId: org,
  userId: 'u',
  startAt: DateTime.now().subtract(const Duration(hours: 1)),
  endAt: DateTime.now().add(const Duration(hours: 3)),
  note: 'Arsti aeg',
  status: status,
  createdBy: 'u',
);
PlannedUnavailabilityRuleModel rule({String status = 'active'}) =>
    PlannedUnavailabilityRuleModel(
      id: 'rule',
      organizationId: 'org',
      commandId: 'org',
      userId: 'u',
      daysOfWeek: const [1, 3],
      startTime: '08:00',
      endTime: '17:00',
      startMinute: 480,
      endMinute: 1020,
      note: 'Tööaeg',
      status: status,
      createdBy: 'u',
    );

class FakePlans implements PlannedUnavailabilityService {
  List<PlannedUnavailabilityModel> periods = [];
  List<PlannedUnavailabilityRuleModel> rules = [];
  bool fail = false, readError = false;
  Completer<void>? pending;
  int subscriptions = 0;
  final writes = <String>[];
  Map<Symbol, dynamic>? lastArguments;
  @override
  Stream<List<PlannedUnavailabilityModel>> streamMyPeriods({
    required String organizationId,
    bool includeCancelled = false,
  }) {
    subscriptions++;
    return Stream.value(
      periods.where((p) => p.organizationId == organizationId).toList(),
    );
  }

  @override
  Stream<List<PlannedUnavailabilityRuleModel>> streamMyRules({
    required String organizationId,
    bool includeCancelled = false,
  }) {
    subscriptions++;
    return readError
        ? Stream.error(StateError('network'))
        : Stream.value(
            rules.where((r) => r.organizationId == organizationId).toList(),
          );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) async {
    writes.add(invocation.memberName.toString());
    lastArguments = invocation.namedArguments;
    if (fail) throw StateError('network');
    if (pending != null) await pending!.future;
  }
}

class FakeAvailability implements AvailabilityService {
  int reads = 0;
  @override
  Stream<AvailabilityModel?> streamMyAvailability({
    required String userId,
    required String organizationId,
  }) {
    reads++;
    return Stream.value(
      AvailabilityModel(
        id: 'a',
        userId: userId,
        organizationId: organizationId,
        commandId: organizationId,
        status: 'onDuty',
        manualStatus: 'onDuty',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReminders implements AvailabilityReminderSettingsService {
  @override
  Stream<AvailabilityReminderSettingsModel> streamMySettings({
    required String userId,
    required String organizationId,
  }) => Stream.value(
    AvailabilityReminderSettingsModel.defaults(
      userId: userId,
      organizationId: organizationId,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('et'),
  supportedLocales: const [Locale('et')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);
Future<void> openEditor(
  WidgetTester tester,
  FakePlans service, {
  PlannedUnavailabilityModel? p,
  PlannedUnavailabilityRuleModel? r,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    app(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            child: const Text('Ava'),
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => UnavailabilityEditor(
                organizationId: 'org',
                service: service,
                period: p,
                rule: r,
              ),
            ),
          ),
        ),
      ),
      scale: scale,
    ),
  );
  await tester.tap(find.text('Ava'));
  await tester.pumpAndSettle();
}

Future<void> weekly(WidgetTester tester) async {
  await tester.tap(find.text('Ei kordu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Igal nädalal').last);
  await tester.pumpAndSettle();
}

void phone(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'status card renders and all choices are tappable at 320px scale $scale',
      (tester) async {
        phone(tester, 320);
        String? selected;
        await tester.pumpWidget(
          app(
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PersonalAvailabilityCard(
                    status: 'onDuty',
                    minutes: 15,
                    saving: false,
                    plannedUnavailable: false,
                    onSelect: (s) => selected = s,
                    onDelayChanged: (_) {},
                  ),
                  const Text('Järgmine plokk'),
                ],
              ),
            ),
            scale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        for (final label in ['Valves', 'Hilinemisega', 'Mitte valves']) {
          final f = find.widgetWithText(OutlinedButton, label);
          expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
          await tester.tap(f);
        }
        expect(selected, 'offDuty');
        expect(
          tester.getBottomLeft(find.byType(PersonalAvailabilityCard)).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Järgmine plokk')).dy),
        );
      },
    );
  }
  testWidgets('active schedule prevents duty and delayed selection', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: PersonalAvailabilityCard(
            status: 'onDuty',
            minutes: 15,
            saving: false,
            plannedUnavailable: true,
            onSelect: (s) => selected = s,
            onDelayChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Valves'));
    await tester.tap(find.text('Hilinemisega'));
    expect(selected, isNull);
    expect(find.textContaining('praegu aktiivne'), findsOneWidget);
    await tester.tap(find.text('Mitte valves'));
    expect(selected, 'offDuty');
  });
  testWidgets(
    'one add form saves a one-off period without creating a weekly rule',
    (tester) async {
      final service = FakePlans();
      await openEditor(tester, service);
      expect(find.byType(ActivityDateField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'Reis');
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(service.writes, ['Symbol("createMyPeriod")']);
      expect(service.lastArguments![#organizationId], 'org');
      expect(service.lastArguments![#note], 'Reis');
      expect(find.byType(UnavailabilityEditor), findsNothing);
    },
  );
  testWidgets(
    'weekly choice validates weekdays then saves in existing rule collection',
    (tester) async {
      final service = FakePlans();
      await openEditor(tester, service);
      await weekly(tester);
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(find.text('Vali vähemalt üks nädalapäev.'), findsOneWidget);
      expect(service.writes, isEmpty);
      await tester.tap(find.widgetWithText(FilterChip, 'E'));
      await tester.tap(find.widgetWithText(FilterChip, 'R'));
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(service.writes, ['Symbol("createMyRule")']);
      expect(service.lastArguments![#daysOfWeek], [1, 5]);
    },
  );
  testWidgets('editing retains ID and type for both existing record kinds', (
    tester,
  ) async {
    final service = FakePlans();
    await openEditor(tester, service, p: period());
    expect(find.byType(DropdownButtonFormField<bool>), findsNothing);
    await tester.tap(find.text('Salvesta'));
    await tester.pumpAndSettle();
    expect(service.writes.last, 'Symbol("updateMyPeriod")');
    expect(service.lastArguments![#periodId], 'period');
    await openEditor(tester, service, r: rule());
    expect(find.byType(DropdownButtonFormField<bool>), findsNothing);
    await tester.tap(find.text('Salvesta'));
    await tester.pumpAndSettle();
    expect(service.writes.last, 'Symbol("updateMyRule")');
    expect(service.lastArguments![#ruleId], 'rule');
    expect(service.writes.length, 2);
  });
  testWidgets(
    'failed save retains form; pending save blocks back and duplicate writes',
    (tester) async {
      final service = FakePlans()..fail = true;
      await openEditor(tester, service);
      await tester.enterText(find.byType(TextField), 'Säilita mind');
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kontrolli ühendust'), findsOneWidget);
      expect(find.text('Säilita mind'), findsOneWidget);
      service.fail = false;
      service.pending = Completer<void>();
      await tester.tap(find.text('Salvesta'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(UnavailabilityEditor), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(service.writes.length, 2);
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(UnavailabilityEditor), findsNothing);
    },
  );
  testWidgets(
    'narrow weekly editor has no overflow and retains note on mode change',
    (tester) async {
      phone(tester, 320);
      final service = FakePlans();
      await openEditor(tester, service);
      await tester.enterText(find.byType(TextField), 'Reis');
      await weekly(tester);
      expect(find.text('Reis'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Katkesta'));
      await tester.pumpAndSettle();
      expect(service.writes, isEmpty);
    },
  );
  testWidgets(
    'personal page unites plans and keeps subscriptions stable across clock and filter; org switch isolates data',
    (tester) async {
      final plans = FakePlans()
        ..periods = [period()]
        ..rules = [rule(status: 'cancelled')];
      final availability = FakeAvailability();
      Widget page(String org) => app(
        AvailabilityScreen(
          organizationId: org,
          currentUid: 'u',
          currentUserName: 'Mari',
          canViewOrganizationReadiness: true,
          availabilityService: availability,
          plannedUnavailabilityService: plans,
          reminderService: FakeReminders(),
        ),
      );
      await tester.pumpWidget(page('org'));
      await tester.pumpAndSettle();
      expect(find.text('Minu mittevalved'), findsOneWidget);
      expect(find.text('Lisa aeg'), findsOneWidget);
      expect(find.text('Arsti aeg'), findsOneWidget);
      expect(find.text('Tööaeg'), findsNothing);
      await tester.tap(find.text('Näita tühistatud'));
      await tester.pumpAndSettle();
      expect(find.text('Tööaeg'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(plans.subscriptions, 2);
      expect(availability.reads, 1);
      await tester.pumpWidget(page('other'));
      await tester.pumpAndSettle();
      expect(find.text('Arsti aeg'), findsNothing);
      expect(find.text('Tööaeg'), findsNothing);
      expect(find.text('Planeeritud mittevalveid ei ole.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('unified editor remains usable with large text at 320px', (
    tester,
  ) async {
    phone(tester, 320);
    final service = FakePlans();
    await openEditor(tester, service, r: rule(), scale: 1.8);
    expect(tester.takeException(), isNull);
    expect(find.text('Salvesta').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Katkesta'));
    await tester.pumpAndSettle();
  });
  testWidgets('invalid one-off end is rejected without a write', (
    tester,
  ) async {
    final service = FakePlans();
    await openEditor(tester, service);
    final fields = tester
        .widgetList<ActivityDateField>(find.byType(ActivityDateField))
        .toList();
    fields.last.onChanged(
      fields.first.value!.subtract(const Duration(minutes: 1)),
    );
    await tester.pump();
    await tester.tap(find.text('Salvesta'));
    await tester.pumpAndSettle();
    expect(find.text('Lõpuaeg peab olema algusest hilisem.'), findsOneWidget);
    expect(service.writes, isEmpty);
  });
  testWidgets('unified page fits 320px with both plan kinds', (tester) async {
    phone(tester, 320);
    final plans = FakePlans()
      ..periods = [period()]
      ..rules = [rule()];
    await tester.pumpWidget(
      app(
        AvailabilityScreen(
          organizationId: 'org',
          currentUid: 'u',
          currentUserName: 'Mari',
          canViewOrganizationReadiness: true,
          availabilityService: FakeAvailability(),
          plannedUnavailabilityService: plans,
          reminderService: FakeReminders(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Arsti aeg'), findsOneWidget);
    expect(find.text('Tööaeg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed schedule read does not imply safe on-duty status or empty plans',
    (tester) async {
      final plans = FakePlans()..readError = true;
      await tester.pumpWidget(
        app(
          AvailabilityScreen(
            organizationId: 'org',
            currentUid: 'u',
            currentUserName: 'Mari',
            canViewOrganizationReadiness: true,
            availabilityService: FakeAvailability(),
            plannedUnavailabilityService: plans,
            reminderService: FakeReminders(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Staatust või planeeringuid ei saanud laadida.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Valves'), findsNothing);
      expect(find.text('Planeeritud mittevalveid ei ole.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
