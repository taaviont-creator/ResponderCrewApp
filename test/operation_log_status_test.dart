import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/operation_log_model.dart';

void main() {
  group('OperationLogStatus transitions', () {
    test('supports normal operational progression and shortcuts', () {
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.open,
          OperationLogStatus.enRoute,
        ),
        isTrue,
      );
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.open,
          OperationLogStatus.onScene,
        ),
        isTrue,
      );
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.onScene,
          OperationLogStatus.inProgress,
        ),
        isTrue,
      );
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.inProgress,
          OperationLogStatus.completed,
        ),
        isTrue,
      );
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.completed,
          OperationLogStatus.returnedToBase,
        ),
        isTrue,
      );
    });

    test('allows completing from any active operational phase', () {
      for (final status in [
        OperationLogStatus.open,
        OperationLogStatus.enRoute,
        OperationLogStatus.onScene,
        OperationLogStatus.inProgress,
      ]) {
        expect(
          OperationLogStatus.canTransition(
            status,
            OperationLogStatus.completed,
          ),
          isTrue,
        );
      }
    });

    test('does not allow reopening or moving backwards', () {
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.completed,
          OperationLogStatus.open,
        ),
        isFalse,
      );
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.onScene,
          OperationLogStatus.enRoute,
        ),
        isFalse,
      );
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.returnedToBase,
          OperationLogStatus.completed,
        ),
        isFalse,
      );
    });

    test('normalizes legacy source statuses before transition check', () {
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.created,
          OperationLogStatus.enRoute,
        ),
        isTrue,
      );
      expect(
        OperationLogStatus.canTransition(
          OperationLogStatus.departed,
          OperationLogStatus.onScene,
        ),
        isTrue,
      );
    });
  });
}
