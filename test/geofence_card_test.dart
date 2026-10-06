import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/geofence_service.dart';
import 'package:respondcrew_app/widgets/geofence_card.dart';

class FakeGeofence extends GeofenceService {
  bool fail = false;
  bool confirmed = false;
  @override
  Future<Map<String, dynamic>> call(
    String org,
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    if (fail) throw StateError('offline');
    return {
      'config': {
        'enabled': true,
        'innerMeters': 3000,
        'outerMeters': 8000,
        'delayMinutes': 15,
        'revision': 0,
        'latitude': 59.4,
      },
      'state': {
        'enabled': true,
        'sessionId': 'session',
        'zone': 'inner',
        'confirmationRequired': !confirmed,
      },
    };
  }

  @override
  Future<bool> permissionsReady() async => true;
  @override
  Future<Map<String, dynamic>?> localSession(String session) async => {};
  @override
  Future<String?> error(String session) async => null;
  @override
  Future<void> confirm(String org, String session) async {
    confirmed = true;
  }
}

void main() {
  testWidgets(
    'Returning member sees confirmation; rendering never grants duty',
    (tester) async {
      final service = FakeGeofence();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GeofenceCard(organizationId: 'org', service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.confirmed, false);
      expect(find.text('Kinnitan: olen valves'), findsOneWidget);
      await tester.tap(find.text('Kinnitan: olen valves'));
      await tester.pumpAndSettle();
      expect(service.confirmed, true);
      expect(find.text('Kinnitan: olen valves'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Offline state offers retry, not an enabled confirmation button',
    (tester) async {
      final service = FakeGeofence()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeofenceCard(organizationId: 'org', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Proovi uuesti'), findsOneWidget);
      expect(find.text('Kinnitan: olen valves'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
