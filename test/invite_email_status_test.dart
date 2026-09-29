import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/widgets/invite_email_status.dart';

void main() {
  test('SMTP acceptance does not promise inbox delivery', () {
    expect(inviteEmailStatusLabel('accepted'), contains('meiliserverile'));
    expect(inviteEmailStatusLabel('accepted'), isNot(contains('kohale')));
  });
  test(
    'missing, failed and unknown email states offer the existing manual fallback',
    () {
      for (final status in [null, 'failed', 'unknown', 'sending']) {
        expect(
          inviteEmailStatusLabel(status).toLowerCase(),
          contains('jaga kutse teksti'),
        );
      }
    },
  );
}
