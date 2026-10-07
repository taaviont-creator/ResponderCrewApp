import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/callout_model.dart';
import 'package:respondcrew_app/models/operation_log_model.dart';
import 'package:respondcrew_app/widgets/callout_departure_timing.dart';
import 'package:respondcrew_app/widgets/create_callout_dialog.dart';
import 'package:respondcrew_app/theme/app_theme.dart';

OperationLogEventModel departure(String type, String status, DateTime time) =>
    OperationLogEventModel(
      id: 'e',
      organizationId: 'o',
      commandId: 'o',
      operationLogId: 'l',
      type: type,
      status: status,
      title: '',
      text: '',
      description: '',
      createdBy: 'u',
      createdAt: time,
    );
CalloutModel callout(DateTime time) => CalloutModel(
  id: 'c',
  organizationId: 'o',
  commandId: 'o',
  title: 'Ülesanne',
  description: '',
  location: '',
  status: 'active',
  priority: 'normal',
  createdBy: 'u',
  createdByName: '',
  calloutType: 'tross',
  responseTargetMinutes: 60,
  createdAt: time,
);
void main() {
  test(
    'actual departure is the first real departure transition, never activation or a note',
    () {
      final start = DateTime(2026, 9, 27, 12);
      expect(
        firstDeparture([
          departure('statusChange', 'open', start),
          departure('manualNote', 'enRoute', start),
        ]),
        isNull,
      );
      expect(
        firstDeparture([
          departure(
            'statusChange',
            'enRoute',
            start.add(const Duration(minutes: 20)),
          ),
          departure(
            'statusChange',
            'departed',
            start.add(const Duration(minutes: 10)),
          ),
        ]),
        start.add(const Duration(minutes: 10)),
      );
    },
  );
  testWidgets(
    'target expiry informs without changing callout status; registered departure stops elapsed warning',
    (tester) async {
      final start = DateTime.now().subtract(const Duration(hours: 2));
      final c = callout(start);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalloutDepartureTiming(callout: c, events: const []),
          ),
        ),
      );
      expect(find.text('Väljasõidu sihtaeg ületatud'), findsOneWidget);
      expect(c.status, 'active');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalloutDepartureTiming(
              callout: c,
              events: [
                departure(
                  'statusChange',
                  'enRoute',
                  start.add(const Duration(minutes: 30)),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Väljasõidu sihtaeg ületatud'), findsNothing);
      expect(find.textContaining('Tegelik väljasõit:'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'quick creation fits 320px at 200 percent text without exposing extra fields',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.maritime,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: CreateCalloutDialog(onSave: (_) async {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'TROSSI mereabi'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'TROSSI mereabi'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
