import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/duty_crew.dart';
import 'package:respondcrew_app/screens/main_navigation_shell.dart';
import 'package:respondcrew_app/screens/menu_screen.dart';
import 'package:respondcrew_app/screens/register_screen.dart';
import 'package:respondcrew_app/screens/callout_report_screen.dart';
import 'package:respondcrew_app/theme/app_theme.dart';
import 'package:respondcrew_app/widgets/app_layout.dart';
import 'package:respondcrew_app/widgets/crew_readiness_card.dart';

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('register form scrolls above the keyboard with large text', (
    tester,
  ) async {
    viewport(tester, const Size(320, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.maritime,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!,
        ),
        home: const RegisterScreen(),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Loo konto'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Loo konto').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'statistics metrics fit bounded desktop and large-text phone content',
    (tester) async {
      viewport(tester, const Size(2400, 1000));
      for (final large in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.maritime,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!,
            ),
            home: AppScaffold(
              contentMaxWidth: large ? 320 : 1120,
              body: ListView(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < 10; i++)
                        MetricValue(
                          title: 'Koolitustel osalemisi $i',
                          value: '120',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(MetricValue).first).width,
          lessThanOrEqualTo(large ? 320 : 280),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'desktop rail retains detail and selection across viewport resize',
    (tester) async {
      viewport(tester, const Size(1440, 900));
      final navigator = GlobalKey<NavigatorState>();
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: StatefulBuilder(
            builder: (context, setState) => MainNavigationShell(
              navigatorKey: navigator,
              currentIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              child: AppScaffold(body: Text('Page $index')),
            ),
          ),
        ),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const AppScaffold(body: Text('Detail')),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 800);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Detail'), findsOneWidget);
      await tester.tap(find.text('Ühingu valmidus'));
      await tester.pumpAndSettle();
      expect(find.text('Page 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('main destinations and system back respect unsaved form veto', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var selected = 0, attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          navigatorKey: navigator,
          currentIndex: 0,
          onDestinationSelected: (value) => selected = value,
          child: const AppScaffold(body: Text('Home')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) attempts++;
          },
          child: const AppScaffold(body: Text('Unsaved report')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menüü'));
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(attempts, 1);
    expect(find.text('Unsaved report'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Unsaved report'), findsOneWidget);
  });

  for (final role in ['member', 'admin', 'platform']) {
    testWidgets('grouped menu preserves $role permissions on phone', (
      tester,
    ) async {
      viewport(tester, const Size(320, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: MenuScreen(
            organizationId: 'o',
            organizationName: 'Päästeühing',
            currentUid: 'u',
            currentUserName: 'Mari',
            isOrganizationAdmin: role == 'admin',
            isPlatformAdmin: role == 'platform',
            canCreateActivities: false,
            canViewStatistics: role == 'admin',
            canStartOperationLog: false,
            onOpenOrganizationSettings: () {},
            pendingInvites: const SizedBox.shrink(),
            platformBadge: const Icon(Icons.admin_panel_settings),
          ),
        ),
      );
      expect(find.text('Liikmed'), findsOneWidget);
      expect(find.text('Varustus'), findsOneWidget);
      expect(
        find.text('Panus ja statistika'),
        role == 'admin' ? findsOneWidget : findsNothing,
      );
      if (role != 'member') {
        await tester.scrollUntilVisible(
          find.text(role == 'admin' ? 'Ühingu seaded' : 'RespondCrew haldus'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      } else {
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
      }
      expect(
        find.text('Ühingu seaded'),
        role == 'admin' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('RespondCrew haldus'),
        role == 'platform' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'dashboard preview limits rows while retaining full readiness totals',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: AppScaffold(
            body: SingleChildScrollView(
              child: CrewReadinessView(
                members: [
                  for (var i = 0; i < 8; i++)
                    DutyCrewMember(
                      userId: '$i',
                      name: 'Liige $i',
                      status: 'onDuty',
                      level: i == 7 ? 'level2' : 'level1',
                    ),
                ],
                minimumCrew: 3,
                currentUid: 'x',
                memberPreviewLimit: 4,
                onContact: (_, _) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Valves: 8 / 3'), findsOneWidget);
      expect(find.text('Ühing on reageerimisvalmis'), findsOneWidget);
      expect(find.text('Liige 0'), findsOneWidget);
      expect(find.text('Liige 7'), findsNothing);
      expect(find.textContaining('Veel 4 liiget'), findsOneWidget);
    },
  );

  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'responsive sections preserve order and edit state at width $width',
      (tester) async {
        viewport(tester, Size(width, 1000));
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.maritime,
            home: AppScaffold(
              body: ResponsiveSections(
                primary: [
                  SettingsGroup(
                    title: 'Ühing',
                    icon: Icons.apartment,
                    children: [TextField(controller: controller)],
                  ),
                ],
                secondary: const [Text('Teavitused')],
              ),
            ),
          ),
        );
        if (width > 1000) {
          expect(
            tester.getTopLeft(find.text('Teavitused')).dx,
            greaterThan(tester.getTopLeft(find.text('Ühing')).dx),
          );
        } else {
          expect(
            tester.getTopLeft(find.text('Teavitused')).dy,
            greaterThan(tester.getTopLeft(find.text('Ühing')).dy),
          );
        }
        await tester.tap(find.text('Ühing'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Purtse');
        await tester.tap(find.text('Ühing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ühing'));
        await tester.pumpAndSettle();
        expect(find.text('Purtse'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'report save stays reachable at the top and after scrolling on phone',
    (tester) async {
      viewport(tester, const Size(320, 800));
      Map<String, dynamic>? saved;
      final data = <String, dynamic>{
        'canEdit': true,
        'operationLogId': 'log',
        'organizationName': 'Purtse',
        'summary': 'Abi osutatud',
        'report': {'revision': 1},
        'callout': {
          'title': 'Mereabi',
          'status': 'closed',
          'calloutType': 'tross',
        },
        'members': [],
        'crew': [],
        'equipment': [],
        'timeline': [],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          home: CalloutReportScreen(
            organizationId: 'o',
            calloutId: 'c',
            loadReport: () async => data,
            saveReport: (payload) async {
              saved = payload;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Salvesta mustand').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Salvesta mustand').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Salvesta mustand'));
      await tester.pumpAndSettle();
      expect(saved?['status'], 'draft');
      expect(saved?['summary'], 'Abi osutatud');
      expect(tester.takeException(), isNull);
    },
  );
}
