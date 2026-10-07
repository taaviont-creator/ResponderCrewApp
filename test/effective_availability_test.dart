import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/availability_model.dart';
import 'package:respondcrew_app/models/activity_schedule.dart';
import 'package:respondcrew_app/models/effective_availability.dart';
import 'package:respondcrew_app/models/planned_unavailability_model.dart';
import 'package:respondcrew_app/models/planned_unavailability_rule_model.dart';

void main() {
  group('EffectiveAvailability', () {
    final now = ActivitySchedule.parse('2026-09-27 12:00')!;

    test('keeps manual status when no planned unavailability is active', () {
      expect(
        EffectiveAvailability.resolve(
          userId: 'u1',
          manualStatus: AvailabilityStatus.onDuty,
          periods: const [],
          rules: const [],
          now: now,
        ),
        AvailabilityStatus.onDuty,
      );
    });

    test('active planned period overrides manual on-duty status', () {
      final period = PlannedUnavailabilityModel(
        id: 'p1',
        organizationId: 'org',
        commandId: 'org',
        userId: 'u1',
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 1)),
        note: '',
        status: PlannedUnavailabilityStatus.active,
        createdBy: 'u1',
      );

      expect(
        EffectiveAvailability.resolve(
          userId: 'u1',
          manualStatus: AvailabilityStatus.onDuty,
          periods: [period],
          rules: const [],
          now: now,
        ),
        AvailabilityStatus.offDuty,
      );
    });

    test('cancelled period does not override manual status', () {
      final period = PlannedUnavailabilityModel(
        id: 'p1',
        organizationId: 'org',
        commandId: 'org',
        userId: 'u1',
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 1)),
        note: '',
        status: PlannedUnavailabilityStatus.cancelled,
        createdBy: 'u1',
      );

      expect(
        EffectiveAvailability.resolve(
          userId: 'u1',
          manualStatus: AvailabilityStatus.delayed,
          periods: [period],
          rules: const [],
          now: now,
        ),
        AvailabilityStatus.delayed,
      );
    });

    test('active recurring rule overrides manual status', () {
      final rule = PlannedUnavailabilityRuleModel(
        id: 'r1',
        organizationId: 'org',
        commandId: 'org',
        userId: 'u1',
        daysOfWeek: [now.weekday],
        startTime: '11:00',
        endTime: '13:00',
        startMinute: 11 * 60,
        endMinute: 13 * 60,
        note: '',
        status: PlannedUnavailabilityRuleStatus.active,
        createdBy: 'u1',
      );

      expect(
        EffectiveAvailability.resolve(
          userId: 'u1',
          manualStatus: AvailabilityStatus.onDuty,
          periods: const [],
          rules: [rule],
          now: now,
        ),
        AvailabilityStatus.offDuty,
      );
    });

    test('unknown manual status fails closed to off duty', () {
      expect(
        EffectiveAvailability.resolve(
          userId: 'u1',
          manualStatus: 'unexpected',
          periods: const [],
          rules: const [],
          now: now,
        ),
        AvailabilityStatus.offDuty,
      );
    });
  });
}
