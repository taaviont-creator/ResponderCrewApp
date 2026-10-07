import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/auth/auth_gate.dart';
import 'package:respondcrew_app/screens/app_context_screen.dart';
import 'package:respondcrew_app/services/center_access_service.dart';
import 'package:respondcrew_app/screens/main_navigation_shell.dart';
import 'package:respondcrew_app/widgets/app_layout.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'user';
}

class _Session extends StatefulWidget {
  const _Session(this.onCreate, this.path);
  final VoidCallback onCreate;
  final String path;
  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => Text(widget.path);
}

void main() {
  for (final path in ['/', '/uhingud']) {
    testWidgets(
      'organization draft survives access refresh and grant changes at $path',
      (tester) async {
        var fail = false;
        var granted = false;
        var created = 0;
        final access = CenterAccessService(
          load: () async {
            if (fail) throw Exception('offline');
            return {
              'serverNowMs': DateTime.now().millisecondsSinceEpoch,
              'contexts': [
                if (granted)
                  {
                    'centerId': 'merevalvekeskus',
                    'service': 'sar',
                    'validUntilMs': null,
                  },
              ],
            };
          },
        );
        final input = TextEditingController();
        await tester.pumpWidget(
          MaterialApp(
            home: AppContextScreen(
              centersEnabled: true,
              userId: 'user',
              path: path,
              access: access,
              navigate: (_) {},
              organizationHome: Column(
                children: [
                  _Session(() => created++, 'Open report'),
                  TextField(controller: input),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Salvestamata kokkuvõte',
        );
        expect(created, 1);
        fail = true;
        await access.refresh(invalidateFirst: false);
        await tester.pumpAndSettle();
        expect(created, 1);
        expect(find.text('Salvestamata kokkuvõte'), findsOneWidget);
        fail = false;
        granted = true;
        await access.refresh();
        await tester.pumpAndSettle();
        expect(created, 1);
        expect(find.text('Merevalvekeskus'), findsOneWidget);
        expect(find.text('Vali töökeskkond'), findsNothing);
        access.pause();
        await tester.pump();
        expect(created, 1);
        access.resume();
        await tester.pumpAndSettle();
        granted = false;
        await access.refresh();
        await tester.pumpAndSettle();
        expect(created, 1);
        expect(find.text('Merevalvekeskus'), findsNothing);
        expect(find.text('Salvestamata kokkuvõte'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        input.dispose();
      },
    );
  }
  testWidgets(
    'center-enabled organization context preserves desktop content width',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final access = CenterAccessService(
        load: () async => {
          'serverNowMs': DateTime.now().millisecondsSinceEpoch,
          'contexts': [
            {
              'centerId': 'merevalvekeskus',
              'service': 'sar',
              'validUntilMs': null,
            },
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppContextScreen(
            centersEnabled: true,
            userId: 'user',
            path: '/uhingud',
            navigate: (_) {},
            access: access,
            organizationHome: MainNavigationShell(
              currentIndex: 0,
              onDestinationSelected: (_) {},
              child: const AppScaffold(
                contentMaxWidth: 1280,
                body: ResponsiveSections(
                  primary: [Text('Operational overview')],
                  secondary: [Text('Quick actions')],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Quick actions')).dy,
        tester.getTopLeft(find.text('Operational overview')).dy,
      );
      expect(
        tester.getTopLeft(find.text('Quick actions')).dx,
        greaterThan(tester.getTopLeft(find.text('Operational overview')).dx),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'routing after sign-in retains the same authenticated session instead of checking again',
    (tester) async {
      final auth = StreamController<User?>.broadcast();
      var created = 0;
      Widget page(String path) => MaterialApp(
        home: AuthGate(
          authChanges: auth.stream,
          signedInBuilder: (_, user) => _Session(() => created++, path),
        ),
      );
      await tester.pumpWidget(page('/'));
      auth.add(_User());
      await tester.pump();
      expect(created, 1);
      await tester.pumpWidget(page('/keskus/sar'));
      expect(find.text('/keskus/sar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(created, 1);
      await tester.pumpWidget(const SizedBox());
      await auth.close();
    },
  );
  testWidgets(
    'first context load is explicit and brief loss of focus never invalidates access',
    (tester) async {
      final initial = Completer<Map<String, dynamic>>();
      var calls = 0;
      final access = CenterAccessService(
        load: () {
          calls++;
          return initial.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppContextScreen(
            centersEnabled: true,
            userId: 'user',
            path: '/',
            navigate: (_) {},
            access: access,
            organizationHome: const Text('Org home'),
          ),
        ),
      );
      expect(find.text('Laadin sinu töökeskkondi…'), findsOneWidget);
      expect(find.text('Org home'), findsNothing);
      initial.complete({
        'serverNowMs': DateTime.now().millisecondsSinceEpoch,
        'contexts': [
          {
            'centerId': 'merevalvekeskus',
            'service': 'sar',
            'validUntilMs': null,
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Vali töökeskkond'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 1);
      expect(access.contexts, hasLength(1));
      expect(find.text('Kontrolli uuesti'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a failed grant listener does not discard the first successful server access check',
    (tester) async {
      final initial = Completer<Map<String, dynamic>>();
      final changes = StreamController<Object?>.broadcast();
      var calls = 0;
      final access = CenterAccessService(
        load: () {
          calls++;
          return initial.future;
        },
        invalidations: changes.stream,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppContextScreen(
            centersEnabled: true,
            userId: 'user',
            path: '/',
            navigate: (_) {},
            access: access,
            organizationHome: const Text('Org home'),
          ),
        ),
      );
      changes.addError(Exception('grant watch permission denied'));
      await tester.pump();
      expect(find.text('Org home'), findsNothing);
      expect(find.text('Laadin sinu töökeskkondi…'), findsOneWidget);
      initial.complete({
        'serverNowMs': DateTime.now().millisecondsSinceEpoch,
        'contexts': [
          {
            'centerId': 'merevalvekeskus',
            'service': 'sar',
            'validUntilMs': null,
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(access.initialized, isTrue);
      expect(access.contexts, hasLength(1));
      expect(find.text('Vali töökeskkond'), findsOneWidget);
      expect(find.text('Org home'), findsNothing);
      expect(calls, 1); // No twenty-second retry is needed.
      await tester.pumpWidget(const SizedBox());
      await changes.close();
    },
  );

  testWidgets(
    'a failed grant listener after login triggers an immediate authoritative recheck',
    (tester) async {
      final changes = StreamController<Object?>.broadcast();
      var calls = 0;
      final access = CenterAccessService(
        load: () async {
          calls++;
          return {
            'serverNowMs': DateTime.now().millisecondsSinceEpoch,
            'contexts': calls == 1
                ? [
                    {
                      'centerId': 'merevalvekeskus',
                      'service': 'sar',
                      'validUntilMs': null,
                    },
                  ]
                : [],
          };
        },
        invalidations: changes.stream,
      );
      await tester.pump();
      expect(access.contexts, hasLength(1));
      changes.addError(Exception('watch disconnected'));
      await tester.pump();
      expect(calls, 2);
      expect(
        access.contexts,
        isEmpty,
      ); // The server removed access; a listener failure cannot retain it.
      access.dispose();
      await changes.close();
    },
  );
}
