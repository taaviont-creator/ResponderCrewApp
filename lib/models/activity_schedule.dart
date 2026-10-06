import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Activity dates are stored in the existing string fields. New writes use UTC
/// ISO 8601; legacy dates without an offset are interpreted as Estonian time.
class ActivitySchedule {
  static final tz.Location zone = (() {
    tzdata.initializeTimeZones();
    return tz.getLocation('Europe/Tallinn');
  })();

  static DateTime inEstonia(DateTime value) => tz.TZDateTime.from(value, zone);

  static DateTime? fromSelection(DateTime date, int hour, int minute) {
    final value = tz.TZDateTime(
      zone,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    // Reject nonexistent local times at the spring DST transition.
    if (value.year != date.year ||
        value.month != date.month ||
        value.day != date.day ||
        value.hour != hour ||
        value.minute != minute) {
      return null;
    }
    return value;
  }

  static DateTime? parse(String raw) {
    final value = raw.trim();
    final estonian = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[ ,]+(?:kell\s+)?(\d{1,2})[:.](\d{2}))?$',
    ).firstMatch(value);
    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(?:[zZ]|[+-]\d{2}:?\d{2})?)?$',
    ).firstMatch(value);
    if (estonian == null && iso == null) return null;
    final m = estonian ?? iso!;
    final year = int.parse(m[estonian != null ? 3 : 1]!);
    final month = int.parse(m[2]!);
    final day = int.parse(m[estonian != null ? 1 : 3]!);
    final hour = int.parse(m[4] ?? '0');
    final minute = int.parse(m[5] ?? '0');
    final second = iso == null ? 0 : int.parse(iso[6] ?? '0');
    final check = DateTime.utc(year, month, day, hour, minute, second);
    if (check.year != year ||
        check.month != month ||
        check.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    if (iso != null && RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(value)) {
      final parsed = DateTime.tryParse(value);
      return parsed == null ? null : inEstonia(parsed);
    }
    return fromSelection(check, hour, minute);
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String two(int n) => n.toString().padLeft(2, '0');
  static String date(DateTime value) =>
      '${two(value.day)}.${two(value.month)}.${value.year}';
  static String format(DateTime? value) {
    if (value == null) return 'Aeg täpsustamata';
    final local = inEstonia(value);
    return '${date(local)} kell ${two(local.hour)}:${two(local.minute)}';
  }
}
