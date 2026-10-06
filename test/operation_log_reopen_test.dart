import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/widgets/operation_log_access_panel.dart';
import 'package:respondcrew_app/widgets/operation_log_actions.dart';

void main() {
  testWidgets(
    'first log opens and repeated collapse/reopen renews permission subscription',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var expanded = true, subscriptions = 0, cancellations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ListView(
                children: [
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text('Esimene logi'),
                    onExpansionChanged: (v) => setState(() => expanded = v),
                    children: [
                      if (expanded)
                        OperationLogAccessPanel(
                          createStream: () {
                            late StreamController<bool> controller;
                            controller = StreamController<bool>(
                              onListen: () {
                                subscriptions++;
                                controller.add(true);
                              },
                              onCancel: () {
                                cancellations++;
                              },
                            );
                            return controller.stream;
                          },
                          builder: (_, access) => access.data == true
                              ? OperationLogActions(
                                  status: 'open',
                                  onAction: (_) async {},
                                  onComment: () async {},
                                )
                              : const Text('Kontrollin õigust'),
                        ),
                    ],
                  ),
                  const ListTile(title: Text('Varasem logi')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Kiirtegevused'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Esimene logi'));
        await tester.pumpAndSettle();
        expect(cancellations, i + 1);
        expect(find.text('Varasem logi'), findsOneWidget);
        await tester.tap(find.text('Esimene logi'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Kiirtegevused'), findsOneWidget);
      }
      expect(subscriptions, 4);
    },
  );
}
