String calendarDateIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String calendarDateLabel(DateTime? date) => date == null
    ? 'Vali kuupäev'
    : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

DateTime? parseCalendarDate(String text) {
  final value = text.trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  final local = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(value);
  if (iso == null && local == null) return null;
  final year = int.parse(iso?[1] ?? local![3]!);
  final month = int.parse(iso?[2] ?? local![2]!);
  final day = int.parse(iso?[3] ?? local![1]!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}
