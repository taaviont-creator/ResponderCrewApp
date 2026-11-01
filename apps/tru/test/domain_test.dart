import 'package:flutter_test/flutter_test.dart';
import 'package:tru_app/domain.dart';
import 'package:tru_app/schedule.dart';

void main() {
  final start = DateTime.utc(2026, 11, 2, 6);
  TruEvent incident() => TruEvent(title: 'Torm', location: 'Ladu', region: 'Ida',
    kind: Kind.incident, start: start, end: start.add(const Duration(days: 3)));

  test('Multiple periods, overnight participation, and half-open boundaries', () {
    final e = incident();
    e.addSlot('A', TimeSlot(start, start.add(const Duration(hours: 8))));
    e.addSlot('A', TimeSlot(start.add(const Duration(hours: 14)), start.add(const Duration(hours: 26))));
    expect(e.plannedAt(start), 1);
    expect(e.plannedAt(start.add(const Duration(hours: 8))), 0);
    expect(e.plannedAt(start.add(const Duration(hours: 24))), 1);
    expect(e.plannedAt(start.add(const Duration(hours: 26))), 0);
    expect(e.response('A').presence, 'Pole saabunud');
  });
  test('Coverage identifies a short gap between participation periods', () {
    final e = incident();
    e.addSlot('A', TimeSlot(start, start.add(const Duration(hours: 1))));
    e.addSlot('B', TimeSlot(start.add(const Duration(hours: 2)), start.add(const Duration(hours: 4))));
    final segments = e.coverageUntil(start.add(const Duration(hours: 4)));
    expect(segments.map((s) => s.count), [1, 0, 1]);
    expect(segments[1].period.start, start.add(const Duration(hours: 1)));
    expect(segments[1].period.end, start.add(const Duration(hours: 2)));
  });
  test('Reject reversed, overlapping, and out-of-event periods', () {
    final e = incident();
    expect(() => TimeSlot(start, start), throwsArgumentError);
    e.addSlot('A', TimeSlot(start, start.add(const Duration(hours: 8))));
    expect(() => e.addSlot('A', TimeSlot(start.add(const Duration(hours: 7)),
      start.add(const Duration(hours: 10)))), throwsArgumentError);
    expect(() => e.addSlot('A', TimeSlot(start.subtract(const Duration(hours: 1)), start)), throwsArgumentError);
    expect(() => e.addSlot('A', TimeSlot(start.add(const Duration(days: 3)),
      start.add(const Duration(days: 4)))), throwsArgumentError);
  });
  test('Changed answer removes stale planned coverage; return later is possible', () {
    final e = incident();
    e.addSlot('A', TimeSlot(start, start.add(const Duration(hours: 8))));
    e.answer('A', Reply.no);
    expect(e.plannedAt(start), 0);
    e.answer('A', Reply.later);
    expect(e.response('A').slots, isEmpty);
    e.addSlot('A', TimeSlot(start, start.add(const Duration(hours: 2))));
    expect(e.response('A').reply, Reply.yes);
    e.closed = true;
    expect(() => e.answer('A', Reply.yes), throwsStateError);
    expect(() => e.addSlot('A', TimeSlot(start, start.add(const Duration(hours: 1)))), throwsStateError);
  });
  test('Transfer preserves ownership, home and condition and records custody', () {
    final item = Equipment('Gen', 'Ida', 'Ida', 'Vajab hooldust');
    item.transfer('Lääne', 'Vastuvõtja', start);
    expect(item.owner, 'TRU'); expect(item.home, 'Ida');
    expect(item.condition, 'Vajab hooldust'); expect(item.location, 'Lääne');
    expect(item.transfers.single.from, 'Ida'); expect(item.custodian, 'Vastuvõtja');
    expect(() => item.transfer('', 'A', start), throwsArgumentError);
    expect(() => item.transfer('Lääne', 'A', start), throwsArgumentError);
    expect(item.transfers.length, 1);
  });
  test('Estonian calendar validation and nonexistent DST time', () {
    expect(ActivitySchedule.parse('31.02.2026 12:00'), isNull);
    expect(ActivitySchedule.parse('29.03.2026 03:30'), isNull);
    expect(ActivitySchedule.parse('02.11.2026 08:00')?.toUtc(), start);
  });
}
