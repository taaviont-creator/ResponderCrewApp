import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/membership_tenure.dart';

void main() {
  test('membership tenure uses completed years and months', () {
    expect(
      membershipTenureLabel(DateTime(2020, 3, 15), asOf: DateTime(2026, 9, 28)),
      '6 aastat 6 kuud',
    );
    expect(
      membershipTenureLabel(DateTime(2025, 9, 28), asOf: DateTime(2026, 9, 28)),
      '1 aasta',
    );
  });

  test('membership tenure handles short and future periods', () {
    expect(
      membershipTenureLabel(DateTime(2026, 9, 1), asOf: DateTime(2026, 9, 28)),
      '27 päeva',
    );
    expect(
      membershipTenureLabel(DateTime(2026, 10, 1), asOf: DateTime(2026, 9, 28)),
      '0 päeva',
    );
  });
}
