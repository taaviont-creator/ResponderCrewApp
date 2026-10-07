import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/callout_model.dart';
import 'package:respondcrew_app/models/center_board.dart';
import 'package:respondcrew_app/models/center_context.dart';
import 'package:respondcrew_app/screens/center_dispatch_screen.dart';
import 'package:respondcrew_app/widgets/dispatch_callout_panel.dart';
import 'package:respondcrew_app/services/callout_alarm_notification_service.dart';

void main() {
  testWidgets(
    'quick information update does not require repeating incident details',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: DispatchEditor(
            center: const CenterContext(
              centerId: 'merevalvekeskus',
              name: 'Merevalvekeskus',
              service: 'sar',
              canDispatch: true,
            ),
            units: const [],
            incident: const {
              'id': 'incident',
              'revision': 2,
              'title': 'Lapsed merel',
              'description': 'Esialgne info',
              'radioChannel': 'VHF 16',
            },
            appendOnly: true,
            submit: (data) async {
              sent = data;
              throw StateError('offline');
            },
          ),
        ),
      );
      expect(
        find.widgetWithText(TextFormField, 'Sündmuse pealkiri'),
        findsNothing,
      );
      expect(
        find.widgetWithText(TextFormField, 'JRCC sidekanal (kui teada)'),
        findsNothing,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Uus vaatlus muuli juures',
      );
      await tester.tap(find.text('Saada täiendus'));
      await tester.pumpAndSettle();
      expect(sent?['action'], 'append');
      expect(sent?['message'], 'Uus vaatlus muuli juures');
      expect(sent?.containsKey('task'), false);
      expect(sent?.containsKey('targetOrganizationId'), false);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'update notifications open exact organization callout; old center grants stay read only',
    () {
      final event = CalloutNotificationOpenEvent.fromData({
        'type': 'callout_update',
        'organizationId': 'org-a',
        'relatedId': 'call-a',
      });
      expect(event?.calloutId, 'call-a');
      expect(event?.organizationId, 'org-a');
      expect(
        CenterContext.fromMap({
          'centerId': 'merevalvekeskus',
          'service': 'sar',
        })!.canDispatch,
        false,
      );
    },
  );
  testWidgets(
    'unknown-location dispatch selects two units, confirms recipients and preserves input on failure',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: DispatchEditor(
            center: const CenterContext(
              centerId: 'merevalvekeskus',
              name: 'Merevalvekeskus',
              service: 'sar',
              canDispatch: true,
            ),
            units: [
              CenterBoardItem.fromMap({
                'id': 'a',
                'name': 'Purtse',
                'status': 'ready',
              }),
              CenterBoardItem.fromMap({
                'id': 'b',
                'name': 'Toila',
                'status': 'unknown',
              }),
            ],
            submit: (data) async {
              sent = data;
              throw StateError('offline');
            },
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sündmuse pealkiri'),
        'Lapsed merel',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Mis juhtus? Teadaolev info ja ohud',
        ),
        'Aa rannast läksid lapsed madratsiga merele. Enam ei nähta.',
      );
      await tester.ensureVisible(find.text('Purtse'));
      await tester.tap(find.text('Purtse'));
      await tester.pump();
      await tester.ensureVisible(find.text('Toila'));
      await tester.tap(find.text('Toila'));
      await tester.pump();
      await tester.ensureVisible(find.text('Alarmeeri ühinguid'));
      await tester.tap(find.text('Alarmeeri ühinguid'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Purtse\nToila'), findsOneWidget);
      expect(sent, isNull);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Alarmeeri ühinguid').last,
      );
      await tester.pumpAndSettle();
      expect(sent!['position'], isNull);
      expect(sent!['positionKind'], 'unknown');
      expect((sent!['targets'] as List).length, 2);
      await tester.scrollUntilVisible(
        find.textContaining('Ühenduse viga'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('Ühenduse viga'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1400));
      await tester.pumpAndSettle();
      expect(find.text('Lapsed merel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ordinary member sees shared radio channel and responders but no organization acceptance controls',
    (tester) async {
      const callout = CalloutModel(
        id: 'call',
        organizationId: 'org',
        commandId: 'org',
        title: 'SAR',
        description: 'Info',
        location: '',
        status: 'active',
        priority: 'high',
        createdBy: 'center',
        createdByName: 'Keskus',
        dispatch: {
          'incidentId': 'shared',
          'centerName': 'Merevalvekeskus',
          'incidentStatus': 'active',
          'revision': 2,
          'radioChannel': 'VHF 16',
          'otherResponders': 'PPA alus',
          'organizations': [
            {'organizationId': 'peer', 'name': 'Toila', 'response': 'pending'},
          ],
          'message': 'Uus info',
          'response': 'pending',
          'acknowledgedRevision': 0,
        },
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DispatchCalloutPanel(callout: callout, canManage: false),
            ),
          ),
        ),
      );
      expect(find.text('JRCC sidekanal: VHF 16'), findsOneWidget);
      expect(find.text('Uus info'), findsOneWidget);
      expect(find.text('Muud reageerijad: PPA alus'), findsOneWidget);
      expect(find.textContaining('Toila ·'), findsOneWidget);
      expect(find.text('Ühing reageerib'), findsNothing);
      expect(find.text('Kinnita info loetuks'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
