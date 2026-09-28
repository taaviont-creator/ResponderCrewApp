DateTime membershipDateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String membershipDateLabel(DateTime value) {
  final date = membershipDateOnly(value);
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String membershipTenureLabel(DateTime startedAt, {DateTime? asOf}) {
  final start = membershipDateOnly(startedAt);
  final end = membershipDateOnly(asOf ?? DateTime.now());
  if (end.isBefore(start)) return '0 päeva';

  var completedMonths = (end.year - start.year) * 12 + end.month - start.month;
  if (end.day < start.day) completedMonths--;
  if (completedMonths < 0) completedMonths = 0;

  final years = completedMonths ~/ 12;
  final months = completedMonths % 12;
  if (years > 0) {
    final parts = <String>[
      '$years ${years == 1 ? 'aasta' : 'aastat'}',
      if (months > 0) '$months ${months == 1 ? 'kuu' : 'kuud'}',
    ];
    return parts.join(' ');
  }
  if (months > 0) return '$months ${months == 1 ? 'kuu' : 'kuud'}';

  final days = end.difference(start).inDays;
  return '$days ${days == 1 ? 'päev' : 'päeva'}';
}
