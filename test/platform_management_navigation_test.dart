import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/platform_management_screen.dart';
import 'package:respondcrew_app/screens/center_sharing_screen.dart';

void main() {
  for (final failedPage in [false, true]) {
    testWidgets(
      'center requests load every page without publishing partial results: failure=$failedPage',
      (tester) async {
        final cursors = <Object?>[];
        await tester.pumpWidget(
          MaterialApp(
            home: CenterSharingScreen(
              call: (name, args) async {
                cursors.add(args['cursor']);
                if (failedPage && args['cursor'] != null) {
                  throw Exception('access revoked');
                }
                return {
                  'entries': [
                    {
                      'organizationId': args['cursor'] ?? 'first',
                      'name': args['cursor'] ?? 'First',
                      'centerId': 'tross',
                      'approved': false,
                      'revision': 1,
                    },
                  ],
                  'nextCursor': args['cursor'] == null ? 'Second' : null,
                };
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(cursors, [null, 'Second']);
        expect(find.text('First'), failedPage ? findsNothing : findsOneWidget);
        expect(find.text('Second'), failedPage ? findsNothing : findsOneWidget);
        if (failedPage) {
          expect(find.textContaining('laadimine ebaõnnestus'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'platform sections expose pending organizations, center approvals and access management on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PlatformManagementScreen(
            centersEnabled: true,
            pendingUpdates: const Stream.empty(),
            notices: const SizedBox(),
            call: (name, data) async {
              calls.add(name);
              if (name == 'getPlatformOverview') {
                return {
                  'organizations': [
                    {
                      'id': 'new',
                      'name': 'Uus ühing',
                      'status': 'pending',
                      'memberCount': 0,
                      'adminCount': 0,
                      'calloutCount': 0,
                    },
                  ],
                  'audit': [],
                };
              }
              if (name == 'getCenterSharingRequests') {
                return {
                  'entries': [
                    {
                      'organizationId': 'approved',
                      'name': 'Kaardi ühing',
                      'centerId': 'merevalvekeskus',
                      'approved': false,
                      'revision': 1,
                    },
                  ],
                };
              }
              if (name == 'getPlatformAccounts') {
                return {
                  'users': [
                    {
                      'uid': 'user',
                      'name': 'Testija',
                      'email': 'test@example.test',
                    },
                  ],
                  'pageToken': null,
                };
              }
              throw StateError(name);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final title in [
        'Taotlused',
        'Kaardikeskused',
        'Ühingud',
        'Kasutajakontod',
        'Auditlogi',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.text('Taotlused'));
      await tester.pumpAndSettle();
      expect(find.text('Uus ühing'), findsOneWidget);
      expect(find.text('Kaardile lisamise taotlused'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Kinnita jagamine'), 250);
      expect(find.text('Kinnita jagamine'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaardikeskused'));
      await tester.pumpAndSettle();
      expect(find.text('Ühingute nähtavus kaardil'), findsOneWidget);
      await tester.tap(find.text('Keskuste kasutajaõigused'));
      await tester.pumpAndSettle();
      expect(calls, contains('getPlatformAccounts'));
      expect(find.text('Testija'), findsOneWidget);
      expect(find.text('Otsi nime või e-posti järgi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'refresh reloads the visible center requests and replaces accounts without duplicates',
    (tester) async {
      var approved = false;
      var accountName = 'Enne';
      final accountPages = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PlatformManagementScreen(
            centersEnabled: true,
            pendingUpdates: const Stream.empty(),
            notices: const SizedBox(),
            call: (name, data) async {
              if (name == 'getPlatformOverview') {
                return {'organizations': [], 'audit': []};
              }
              if (name == 'getCenterSharingRequests') {
                return {
                  'entries': [
                    {
                      'organizationId': 'org',
                      'name': 'Testühing',
                      'centerId': 'merevalvekeskus',
                      'approved': approved,
                      'revision': approved ? 2 : 1,
                    },
                  ],
                };
              }
              if (name == 'getPlatformAccounts') {
                accountPages.add(data['pageToken']);
                return {
                  'users': [
                    {
                      'uid': 'user',
                      'name': accountName,
                      'email': 'test@example.test',
                    },
                  ],
                  'pageToken': 'next',
                };
              }
              throw StateError(name);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaardikeskused'));
      await tester.pumpAndSettle();
      expect(find.text('Kinnita jagamine'), findsOneWidget);
      approved = true; // Another platform administrator reviewed it.
      await tester.tap(find.byTooltip('Värskenda'));
      await tester.pumpAndSettle();
      expect(find.text('Jagamine kinnitatud'), findsOneWidget);
      expect(find.text('Kinnita jagamine'), findsNothing);
      await tester.tap(find.text('Keskuste kasutajaõigused'));
      await tester.pumpAndSettle();
      expect(find.text('Enne'), findsOneWidget);
      accountName = 'Pärast';
      await tester.tap(find.byTooltip('Värskenda'));
      await tester.pumpAndSettle();
      expect(find.text('Pärast'), findsOneWidget);
      expect(find.text('Enne'), findsNothing);
      expect(accountPages, [null, null]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
