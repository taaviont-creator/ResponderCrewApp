import 'activity_schedule.dart';
import 'statistics_model.dart';

const eventTypeLabels = {'sar': 'SAR', 'tross': 'Trossi mereabi'};
const eventStatusLabels = {
  'active': 'Aktiivne',
  'closed': 'Lõpetatud',
  'cancelled': 'Tühistatud',
};

class EventStatistics {
  EventStatistics(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String? ?? 'Väljakutse';
  String get type => data['type'] as String? ?? 'sar';
  String get status => data['status'] as String? ?? 'active';
  String get typeLabel => eventTypeLabels[type] ?? 'Määramata liik';
  String get statusLabel => eventStatusLabels[status] ?? 'Määramata olek';
  DateTime? get startedAt =>
      DateTime.tryParse(data['startedAt'] as String? ?? '');
  DateTime? get endedAt => DateTime.tryParse(data['endedAt'] as String? ?? '');
  List<Map<String, dynamic>> get participants =>
      (data['participants'] as List? ?? []).map(statisticsMap).toList();
  double get hours =>
      participants.fold(0, (sum, p) => sum + (p['hours'] as num? ?? 0));
  int get unknownHours => participants.where((p) => p['hours'] == null).length;
}

List<EventStatistics> filterEventStatistics(
  List<EventStatistics> events, {
  String type = '',
  String status = '',
  String memberId = '',
  String search = '',
}) {
  final query = search.trim().toLowerCase();
  return events
      .where(
        (event) =>
            (type.isEmpty || event.type == type) &&
            (status.isEmpty || event.status == status) &&
            (memberId.isEmpty ||
                event.participants.any((p) => p['userId'] == memberId)) &&
            (query.isEmpty ||
                event.title.toLowerCase().contains(query) ||
                event.id.toLowerCase().contains(query)),
      )
      .toList();
}

String eventStatisticsCsv({
  required List<EventStatistics> events,
  required String organizationId,
  required DateTime from,
  required DateTime to,
  required bool attendance,
  String type = '',
  String status = '',
  String memberId = '',
  String search = '',
  DateTime? generatedAt,
}) {
  String date(DateTime? value) =>
      value == null ? '' : ActivitySchedule.format(value);
  String hours(num? value) =>
      value == null ? '' : value.toString().replaceAll('.', ',');
  final rows = <List<Object?>>[
    ['Ühingu ID', organizationId],
    ['Periood', statisticsDate(from), statisticsDate(to)],
    ['Andmed seisuga (Eesti aeg)', date(generatedAt)],
    ['Liik', eventTypeLabels[type] ?? (type.isEmpty ? 'Kõik' : type)],
    ['Olek', eventStatusLabels[status] ?? (status.isEmpty ? 'Kõik' : status)],
    ['Osaleja ID filter', memberId],
    ['Otsing', search.trim()],
    [
      'Arvestus',
      'Alguskuupäeva järgi; testväljakutsed välja jäetud; ainult kinnitatud osalemised.',
    ],
    [
      'Tunnid',
      'Liikmete töötunnid, mitte sündmuse kestus. Tühi väärtus tähendab märkimata tunde.',
    ],
    ['Sündmusi valikus', events.length],
    [],
    if (!attendance) ...[
      [
        'Sündmuse ID',
        'Pealkiri',
        'Liik',
        'Olek',
        'Algus (Eesti aeg)',
        'Lõpp (Eesti aeg)',
        'Kinnitatud osalejaid',
        'Osalejad',
        'Osalejate ID-d',
        'Teadaolevad töötunnid',
        'Tundideta osalemisi',
      ],
      for (final event in events)
        [
          event.id,
          event.title,
          event.typeLabel,
          event.statusLabel,
          date(event.startedAt),
          date(event.endedAt),
          event.participants.length,
          event.participants.map((p) => p['name']).join(', '),
          event.participants.map((p) => p['userId']).join(', '),
          event.participants.isEmpty ||
                  event.unknownHours == event.participants.length
              ? ''
              : hours(event.hours),
          event.unknownHours,
        ],
    ] else ...[
      [
        'Sündmuse ID',
        'Pealkiri',
        'Liik',
        'Olek',
        'Algus (Eesti aeg)',
        'Liikme ID',
        'Liige',
        'Kinnitatud tunnid',
      ],
      for (final event in events)
        for (final p in event.participants.where(
          (p) => memberId.isEmpty || p['userId'] == memberId,
        ))
          [
            event.id,
            event.title,
            event.typeLabel,
            event.statusLabel,
            date(event.startedAt),
            p['userId'],
            p['name'],
            hours(p['hours'] as num?),
          ],
    ],
  ];
  return rows.map((row) => row.map(statisticsCsvCell).join(';')).join('\r\n');
}
