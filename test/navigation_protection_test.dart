import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/navigation/navigation_protection.dart';
import 'package:respondcrew_app/navigation/app_router.dart';
import 'package:respondcrew_app/screens/organization_response_settings_screen.dart';
import 'organization_response_settings_test.dart' show FakeResponseSettings;
import 'package:respondcrew_app/screens/callout_report_screen.dart';
import 'package:respondcrew_app/screens/main_navigation_shell.dart';
import 'callout_report_test.dart' show report;

void main() {
  testWidgets(
    'router honours active form guard for context and browser routes',
    (tester) async {
      var allowed = false;
      final router = AppRouter();
      await tester.pumpWidget(
        NavigationLeaveGuard(
          confirmLeave: () async => allowed,
          child: const SizedBox(),
        ),
      );
      router.navigate('/keskus/sar');
      await tester.pump();
      expect(router.currentConfiguration, '/');
      await router.setNewRoutePath('/keskus/tross');
      expect(router.currentConfiguration, '/');
      allowed = true;
      router.navigate('/keskus/sar');
      await tester.pump();
      expect(router.currentConfiguration, '/keskus/sar');
      router.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'embedded service settings save before external navigation, failure=$fail',
      (tester) async {
        final service = FakeResponseSettings()..failSave = fail;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrganizationResponseSettingsScreen(
                organizationId: 'o',
                service: service,
                embedded: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final contact = find.widgetWithText(TextFormField, 'Kontakti nimetus');
        await tester.ensureVisible(contact);
        await tester.enterText(contact, 'Valveteenistus');
        await tester.pump();
        final result = NavigationProtection.confirm();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvesta ja jätka'));
        await tester.pumpAndSettle();
        expect(await result, !fail);
        expect(service.writes.single['contactName'], 'Valveteenistus');
        expect(find.text('Valveteenistus'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final choice in [
    'Jätka täitmist',
    'Lahku salvestamata',
    'Salvesta ja jätka',
    'failed',
  ]) {
    testWidgets('external navigation protects report: $choice', (tester) async {
      var data = report(true);
      var opened = false;
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              TextButton(
                onPressed: () async {
                  if (await NavigationProtection.confirm()) opened = true;
                },
                child: const Text('Ava täpne väljakutse'),
              ),
              Expanded(
                child: CalloutReportScreen(
                  organizationId: 'o',
                  calloutId: 'c',
                  loadReport: () async => data,
                  saveReport: (value) async {
                    saved = value;
                    if (choice == 'failed') throw Exception('offline');
                    data = {...data, 'summary': value['summary']};
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final summary = find.widgetWithText(TextField, 'Kokkuvõte');
      await tester.scrollUntilVisible(
        summary,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(summary, 'Pooleliolev aruanne');
      await tester.tap(find.text('Ava täpne väljakutse'));
      await tester.pumpAndSettle();
      expect(opened, false);
      expect(
        await NavigationProtection.confirm(),
        false,
      ); // No concurrent navigation while dialog open.
      await tester.tap(
        find.text(choice == 'failed' ? 'Salvesta ja jätka' : choice),
      );
      await tester.pumpAndSettle();
      expect(
        opened,
        choice == 'Lahku salvestamata' || choice == 'Salvesta ja jätka',
      );
      if (choice == 'failed' || choice == 'Salvesta ja jätka') {
        expect(saved?['summary'], 'Pooleliolev aruanne');
      }
      if (choice == 'failed') {
        expect(find.textContaining('Sisestatud andmed on alles'), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox());
      expect(
        await NavigationProtection.confirm(),
        true,
      ); // Disposed form never blocks a new session.
    });
  }

  testWidgets('one destination tap continues after discarding report', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          currentIndex: 0,
          navigatorKey: navigator,
          onDestinationSelected: (v) => selected = v,
          child: const Text('Home'),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => CalloutReportScreen(
          organizationId: 'o',
          calloutId: 'c',
          loadReport: () async => report(true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final summary = find.widgetWithText(TextField, 'Kokkuvõte');
    await tester.scrollUntilVisible(
      summary,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(summary, 'Draft');
    await tester.tap(find.text('Menüü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lahku salvestamata'));
    await tester.pumpAndSettle();
    expect(selected, 4);
    expect(find.byType(CalloutReportScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
