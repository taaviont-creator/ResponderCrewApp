import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:respondcrew_app/models/center_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/main_center_demo.dart';
import 'package:respondcrew_app/models/center_board.dart';
import 'package:respondcrew_app/screens/center_workspace_screen.dart';
import 'package:respondcrew_app/services/center_board_service.dart';

Map<String, dynamic> board() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'serverNowMs': now,
    'items': [
      {
        'id': 'one',
        'name': 'One',
        'status': 'ready',
        'freshUntilMs': now + 90000,
      },
    ],
  };
}

void main() {
  test(
    'invalid coordinates never produce a marker and stale state is unknown',
    () {
      final now = DateTime.now().toUtc();
      for (final coordinates in [
        <String, dynamic>{},
        {'latitude': 58},
        {'latitude': 91, 'longitude': 25},
        {'latitude': double.nan, 'longitude': 25},
      ]) {
        expect(CenterBoardItem.fromMap(coordinates).hasPosition, isFalse);
      }
      final row = CenterBoardItem.fromMap({
        'latitude': 58,
        'longitude': 25,
        'status': 'ready',
        'freshUntilMs': now.millisecondsSinceEpoch + 1000,
      });
      expect(row.hasPosition, isTrue);
      expect(
        row.effectiveStatus(now, connected: true),
        CenterReadinessStatus.ready,
      );
      expect(
        row.effectiveStatus(now, connected: false),
        CenterReadinessStatus.unknown,
      );
      expect(
        row.effectiveStatus(
          now.add(const Duration(seconds: 1)),
          connected: true,
        ),
        CenterReadinessStatus.unknown,
      );
    },
  );

  test('offline retains gray history, revoked access clears it', () async {
    Object? failure;
    final service = CenterBoardService(
      autoRefresh: false,
      load: () async {
        if (failure != null) throw failure;
        return board();
      },
    );
    await service.refresh();
    expect(service.freshConnection, isTrue);
    failure = Exception('offline');
    await service.refresh();
    expect(service.items, hasLength(1));
    expect(
      service.items.single.effectiveStatus(
        service.now,
        connected: service.freshConnection,
      ),
      CenterReadinessStatus.unknown,
    );
    failure = FirebaseFunctionsException(
      code: 'permission-denied',
      message: 'revoked',
    );
    await service.refresh();
    expect(service.items, isEmpty);
    service.dispose();
  });

  test('late response cannot restore revoked data', () async {
    final delayed = Completer<Map<String, dynamic>>();
    var calls = 0;
    final service = CenterBoardService(
      autoRefresh: false,
      load: () {
        if (calls++ == 0) return delayed.future;
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'revoked',
        );
      },
    );
    await service.refresh();
    delayed.complete(board());
    await Future<void>.delayed(Duration.zero);
    expect(service.items, isEmpty);
    expect(service.connected, isFalse);
    service.dispose();
  });

  testWidgets(
    'asynchronously loaded base is visibly centered on a narrow map',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final loaded = Completer<Map<String, dynamic>>();
      final service = CenterBoardService(
        autoRefresh: false,
        load: () => loaded.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CenterWorkspaceScreen(
            center: const CenterContext(
              centerId: 'merevalvekeskus',
              name: 'Merevalvekeskus',
              service: 'sar',
            ),
            service: service,
            tilesEnabled: false,
          ),
        ),
      );
      await tester.pump();
      final data = board();
      (data['items'] as List).first.addAll({
        'latitude': 59.4348,
        'longitude': 26.99311,
      });
      loaded.complete(data);
      await tester.pumpAndSettle();
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        map.mapController!.camera.visibleBounds.contains(
          const LatLng(59.4348, 26.99311),
        ),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('marker-one')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 1366.0]) {
    testWidgets('demo service switch, offline and layout at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixtures =
          jsonDecode(File('assets/center-demo.json').readAsStringSync())
              as Map<String, dynamic>;
      await tester.pumpWidget(
        MaterialApp(home: CenterDemo(fixtures: fixtures, tilesEnabled: false)),
      );
      await tester.pumpAndSettle();
      CenterBoardService current() => tester
          .widget<CenterWorkspaceScreen>(find.byType(CenterWorkspaceScreen))
          .service!;
      expect(
        current().items.firstWhere((e) => e.id == 'west').status,
        CenterReadinessStatus.unavailable,
      );
      await tester.tap(find.text('Trossi keskus').first);
      await tester.pumpAndSettle();
      expect(
        current().items.firstWhere((e) => e.id == 'west').status,
        CenterReadinessStatus.ready,
      );
      expect(current().items.where((e) => !e.hasPosition), hasLength(1));
      await tester.tap(find.text('Katkesta ühendus'));
      await tester.pumpAndSettle();
      expect(current().items, hasLength(7));
      expect(current().freshConnection, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
