import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/response_readiness.dart';

void main() {
  group('ResponseReadiness', () {
    test('requires configured minimum crew and one level II rescuer', () {
      final readiness = ResponseReadiness.evaluate(
        minimumCrewRequired: 3,
        onDutyCount: 3,
        secondLevelOnDutyCount: 1,
      );

      expect(readiness.minimumCrewMet, isTrue);
      expect(readiness.secondLevelMet, isTrue);
      expect(readiness.isReady, isTrue);
      expect(readiness.missingRequirements, isEmpty);
    });

    test('is not ready when minimum crew is missing', () {
      final readiness = ResponseReadiness.evaluate(
        minimumCrewRequired: 3,
        onDutyCount: 2,
        secondLevelOnDutyCount: 1,
      );

      expect(readiness.isReady, isFalse);
      expect(readiness.missingRequirements, contains('Miinimumkoosseis puudu'));
    });

    test('is not ready when level II rescuer is missing', () {
      final readiness = ResponseReadiness.evaluate(
        minimumCrewRequired: 3,
        onDutyCount: 4,
        secondLevelOnDutyCount: 0,
      );

      expect(readiness.isReady, isFalse);
      expect(
        readiness.missingRequirements,
        contains('II astme merepäästja puudub'),
      );
    });

    test('unconfigured minimum crew never reports ready', () {
      final readiness = ResponseReadiness.evaluate(
        minimumCrewRequired: 0,
        onDutyCount: 5,
        secondLevelOnDutyCount: 2,
      );

      expect(readiness.isConfigured, isFalse);
      expect(readiness.isReady, isFalse);
      expect(
        readiness.missingRequirements,
        ['Miinimumkoosseis ei ole seadistatud'],
      );
    });

    test('negative source values are clamped to zero', () {
      final readiness = ResponseReadiness.evaluate(
        minimumCrewRequired: -1,
        onDutyCount: -2,
        secondLevelOnDutyCount: -3,
      );

      expect(readiness.minimumCrewRequired, 0);
      expect(readiness.onDutyCount, 0);
      expect(readiness.secondLevelOnDutyCount, 0);
      expect(readiness.isReady, isFalse);
    });
  });
}
