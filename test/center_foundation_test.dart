import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/center_context.dart';
import 'package:respondcrew_app/navigation/app_router.dart';
import 'package:respondcrew_app/screens/app_context_screen.dart';
import 'package:respondcrew_app/screens/center_workspace_screen.dart';
import 'package:respondcrew_app/services/center_access_service.dart';

Map<String, dynamic> response(List<String> services) => {
  'serverNowMs': DateTime.now().millisecondsSinceEpoch,
  'contexts': [
    for (final service in services)
      <String, dynamic>{
        'centerId': service == 'sar' ? 'merevalvekeskus' : 'tross',
        'service': service,
        'validUntilMs': null,
      },
  ],
};

void main() {
  test(
    'center routes preserve requested service and reject unknown model services',
    () async {
      const parser = AppRouteParser();
      for (final path in ['/keskus/sar', '/keskus/tross', '/uhingud']) {
        final route = await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('https://respondcrew.web.app$path')),
        );
        expect(route, path);
        expect(parser.restoreRouteInformation(route).uri.path, path);
      }
      expect(
        CenterContext.fromMap({'centerId': 'tross', 'service': 'sar'}),
        isNull,
      );
      expect(
        CenterContext.fromMap({
          'centerId': 'tross',
          'service': 'tross',
          'validUntilMs': 'tomorrow',
        }),
        isNull,
      );
    },
  );

  testWidgets(
    'a center-only user can choose both contexts without an organization',
    (tester) async {
      String? selected;
      final access = CenterAccessService(
        load: () async => response(['sar', 'tross']),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppContextScreen(
            centersEnabled: true,
            userId: 'center-only',
            path: '/',
            access: access,
            navigate: (p) => selected = p,
            organizationHome: const Text('Organization home'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Vali töökeskkond'), findsOneWidget);
      expect(find.text('Organization home'), findsNothing);
      await tester.tap(find.text('Trossi mereabi valmidus'));
      expect(selected, '/keskus/tross');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('ordinary member cannot enter a center through a direct URL', (
    tester,
  ) async {
    final access = CenterAccessService(load: () async => response([]));
    await tester.pumpWidget(
      MaterialApp(
        home: AppContextScreen(
          centersEnabled: true,
          userId: 'member',
          path: '/keskus/sar',
          access: access,
          navigate: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CenterWorkspaceScreen), findsNothing);
    expect(find.textContaining('ligipääsuõigus puudub'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('revocation and a failed recheck remove the center view', (
    tester,
  ) async {
    var services = ['sar'];
    var fail = false;
    final access = CenterAccessService(
      load: () async {
        if (fail) throw Exception('offline');
        return response(services);
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppContextScreen(
          centersEnabled: true,
          userId: 'center',
          path: '/keskus/sar',
          access: access,
          navigate: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CenterWorkspaceScreen), findsOneWidget);
    services = [];
    await access.refresh();
    await tester.pump();
    expect(find.byType(CenterWorkspaceScreen), findsNothing);
    services = ['sar'];
    await access.refresh();
    await tester.pump();
    expect(find.byType(CenterWorkspaceScreen), findsOneWidget);
    fail = true;
    await access.refresh(invalidateFirst: false);
    await tester.pump();
    expect(find.byType(CenterWorkspaceScreen), findsNothing);
    expect(find.textContaining('kontroll ebaõnnestus'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an older request cannot restore revoked access', (tester) async {
    final requests = <Completer<Map<String, dynamic>>>[];
    final access = CenterAccessService(
      load: () {
        final request = Completer<Map<String, dynamic>>();
        requests.add(request);
        return request.future;
      },
    );
    final fresh = access.refresh();
    requests[1].complete(response([]));
    await fresh;
    requests[0].complete(response(['sar']));
    await tester.pump();
    expect(access.contexts, isEmpty);
    access.dispose();
  });

  testWidgets('expired or malformed access never grants the center', (
    tester,
  ) async {
    final data = response(['sar']);
    (data['contexts'] as List).first['validUntilMs'] = data['serverNowMs'];
    final access = CenterAccessService(load: () async => data);
    await tester.pump();
    expect(access.contexts, isEmpty);
    access.dispose();
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('foundation is explicit and usable at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: CenterWorkspaceScreen(
            center: CenterContext(
              centerId: 'merevalvekeskus',
              name: 'Merevalvekeskus',
              service: 'sar',
            ),
            tilesEnabled: false,
          ),
        ),
      );
      expect(
        find.textContaining(
          'Väljasõiduvalmidus · Andmed uuenevad automaatselt.',
        ),
        findsOneWidget,
      );
      expect(find.text('Otsi ühingut'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
