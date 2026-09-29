import 'package:respondcrew_app/widgets/crew_readiness_card.dart';
import 'package:respondcrew_app/models/duty_crew.dart';
import 'package:respondcrew_app/models/availability_model.dart';
import 'package:respondcrew_app/widgets/callout_departure_timing.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/callout_model.dart';
import 'package:respondcrew_app/services/operation_log_access_service.dart';
import 'package:respondcrew_app/widgets/active_callouts_card.dart';
import 'package:respondcrew_app/widgets/callout_response_controls.dart';
import 'package:respondcrew_app/widgets/operation_log_actions.dart';
import 'package:respondcrew_app/models/operation_log_model.dart';

CalloutResponseModel response(String value, {int? minutes, String note = ''}) =>
    CalloutResponseModel(
      id: 'c_u',
      calloutId: 'c',
      userId: 'u',
      userName: 'Taavi',
      organizationId: 'o',
      commandId: 'o',
      response: value,
      responseMinutes: minutes,
      note: note,
    );
CalloutModel callout({String status = 'active'}) => CalloutModel(
  id: 'c',
  organizationId: 'o',
  commandId: 'o',
  title: 'Alus madalikul',
  description: '',
  location: 'Purtse',
  status: status,
  priority: 'normal',
  createdBy: 'admin',
  createdByName: 'Admin',
  createdAt: DateTime(2026, 9, 29, 14, 32),
);
void main() {
  testWidgets(
    'roster name opens exact member without triggering phone actions',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CrewReadinessView(
                members: const [
                  DutyCrewMember(
                    userId: 'crew-u',
                    name: 'Mari',
                    status: AvailabilityStatus.onDuty,
                    level: 'level1',
                  ),
                ],
                minimumCrew: 1,
                currentUid: 'self',
                onOpenMember: (uid) => opened = uid,
                onContact: (_, sms) => fail('Profile tap must not dial'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mari'));
      expect(opened, 'crew-u');
    },
  );

  test(
    'participant departure quick entry contributes to existing departure timing',
    () {
      final time = DateTime(2026, 9, 29, 14, 42);
      final entry = OperationLogEventModel(
        id: 'e',
        organizationId: 'o',
        commandId: 'o',
        operationLogId: 'l',
        type: OperationLogEventType.quickAction,
        status: 'open',
        title: 'Väljasõit',
        text: 'Väljasõit',
        description: '',
        createdBy: 'u',
        createdAt: time,
      );
      expect(firstDeparture([entry]), time);
    },
  );

  test(
    'participation policy distinguishes append from management and follows attendance override',
    () {
      final member = {
        'userId': 'u',
        'organizationId': 'o',
        'commandId': 'o',
        'status': 'active',
        'isActive': true,
        'role': 'member',
      };
      final participation = {
        'userId': 'u',
        'organizationId': 'o',
        'calloutId': 'c',
        'response': 'responding',
      };
      bool allowed({
        Map<String, dynamic>? membership,
        Map<String, dynamic>? attendance,
        String status = 'active',
        String orgStatus = 'approved',
        String response = 'responding',
      }) => canAppendAsCalloutParticipant(
        organizationId: 'o',
        userId: 'u',
        calloutId: 'c',
        organization: {'status': orgStatus},
        membership: membership ?? member,
        callout: {'organizationId': 'o', 'status': status},
        response: {...participation, 'response': response},
        attendance: attendance,
      );
      expect(allowed(), isTrue);
      expect(allowed(response: 'delayed'), isTrue);
      expect(allowed(response: 'unavailable'), isFalse);
      expect(allowed(status: 'closed'), isFalse);
      expect(allowed(status: 'cancelled'), isFalse);
      expect(allowed(orgStatus: 'suspended'), isFalse);
      expect(allowed(membership: {...member, 'isActive': false}), isFalse);
      expect(allowed(membership: {...member, 'commandId': 'other'}), isFalse);
      expect(allowed(membership: {...member, 'userId': 'other'}), isFalse);
      expect(
        allowed(attendance: {...participation, 'status': 'absent'}),
        isFalse,
      );
      expect(
        allowed(
          response: 'unavailable',
          attendance: {...participation, 'status': 'confirmed'},
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'home and detail share saved response; busy saves, retry and close are safe',
    (tester) async {
      final stream = StreamController<CalloutResponseModel?>.broadcast();
      addTearDown(() {
        unawaited(stream.close());
      });
      var saves = 0;
      final pending = Completer<void>();
      Future<void> save(String value, int? minutes, String note) async {
        saves++;
        if (saves == 1) await pending.future;
        stream.add(response(value, minutes: minutes, note: note));
      }

      Widget controls(String key, {bool active = true}) =>
          CalloutResponseControls(
            key: ValueKey(key),
            calloutId: 'c',
            organizationId: 'o',
            userId: 'u',
            userName: 'Taavi',
            active: active,
            responseStream: stream.stream,
            onSave: save,
          );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(children: [controls('home'), controls('detail')]),
          ),
        ),
      );
      stream.add(null);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Tulen').first);
      await tester.pump();
      await tester.tap(find.text('Tulen').first);
      expect(saves, 1);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Vastust ei saanud salvestada'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tulen').first);
      await tester.pumpAndSettle();
      expect(find.text('Sinu vastus: Tulen'), findsNWidgets(2));
      await tester.tap(find.text('Ei tule').last);
      await tester.pumpAndSettle();
      expect(find.text('Sinu vastus: Ei tule'), findsNWidgets(2));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: controls('detail', active: false))),
      );
      await tester.pump();
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(button.onPressed, isNull);
      }
    },
  );

  testWidgets(
    'delay keeps minutes and note; controls fit a 320px phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      (String, int?, String)? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CalloutResponseControls(
                calloutId: 'c',
                organizationId: 'o',
                userId: 'u',
                userName: 'Taavi',
                active: true,
                responseStream: Stream.value(
                  response('delayed', minutes: 30, note: 'Tulen sadamasse'),
                ),
                onSave: (r, m, n) async {
                  saved = (r, m, n);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final b in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(
          tester.getSize(find.byWidget(b)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(find.text('Hilinen'));
      await tester.pumpAndSettle();
      expect(find.text('Tulen sadamasse'), findsOneWidget);
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(saved, ('delayed', 30, 'Tulen sadamasse'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active card opens exact callout and disappears when closed', (
    tester,
  ) async {
    final stream = StreamController<List<CalloutModel>>();
    addTearDown(() {
      unawaited(stream.close());
    });
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveCalloutsCard(
            organizationId: 'o',
            userId: 'u',
            userName: 'Taavi',
            calloutsStream: stream.stream,
            responseBuilder: (_) => const Text('Vastus'),
            onOpen: (id) => opened = id,
          ),
        ),
      ),
    );
    stream.add([callout()]);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('14:32'), findsOneWidget);
    await tester.tap(find.text('Ava väljakutse'));
    expect(opened, 'c');
    stream.add([callout(status: 'closed')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Alus madalikul'), findsNothing);
    expect(tester.getSize(find.byType(ActiveCalloutsCard)).height, 0);
  });

  testWidgets(
    'participant quick actions append only; informational end needs no confirmation',
    (tester) async {
      final entries = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OperationLogActions(
                status: OperationLogStatus.enRoute,
                appendOnly: true,
                onAction: (s) async {
                  entries.add(s);
                },
                onComment: () async {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Tagasi baasis'), findsNothing);
      await tester.ensureVisible(find.text('Sündmus lõpetatud'));
      await tester.tap(find.text('Sündmus lõpetatud'));
      await tester.pumpAndSettle();
      expect(entries, ['Sündmus lõpetatud']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Tagasisõit'), findsOneWidget);
    },
  );
}
