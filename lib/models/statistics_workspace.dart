import 'activity_schedule.dart';
import 'calendar_date.dart';
import 'certificate_model.dart';
import 'event_statistics.dart';
import 'statistics_model.dart';

class StatisticsDataset {
  const StatisticsDataset({
    required this.title,
    required this.columns,
    required this.rows,
    this.filters = const [],
  });
  final String title;
  final List<String> columns, filters;
  final List<List<Object?>> rows;
  String get csv => [
    columns,
    ...rows,
  ].map((row) => row.map(statisticsCsvCell).join(';')).join('\r\n');
  String cell(Object? value) => value == null
      ? '—'
      : value is num
      ? value.toString().replaceAll('.', ',')
      : value.toString();
}

const certificateStatusLabels = {
  'valid': 'Kehtiv',
  'expiringSoon': 'Aegub 30 päeva jooksul',
  'expired': 'Aegunud',
  'missing': 'Puudub',
  'unknownExpiry': 'Kehtivusaeg teadmata',
  'noExpiry': 'Tähtajatu',
};
const certificateTypeLabels = {
  'firstAid': 'Esmaabi',
  'seaRescue': 'Merepääste',
  'radio': 'Raadioside',
  'navigation': 'Navigatsioon',
  'boatOperator': 'Väikelaevajuht',
  'safety': 'Ohutus',
  'other': 'Muu',
};

List<CertificateModel> filterStatisticsCertificates(
  List<CertificateModel> certificates, {
  required DateTime now,
  required DateTime from,
  required DateTime to,
  String memberId = '',
  String type = '',
  String status = '',
  String search = '',
  String dateField = '',
}) {
  final query = search.trim().toLowerCase();
  return certificates.where((c) {
    if (c.archived ||
        (memberId.isNotEmpty && c.userId != memberId) ||
        (type.isNotEmpty && c.type != type)) {
      return false;
    }
    final effective = c.displayStatusAt(now);
    if (status == 'noExpiry'
        ? (!c.noExpiry || effective == 'missing')
        : status.isNotEmpty && effective != status) {
      return false;
    }
    if (query.isNotEmpty &&
        ![
          c.title,
          c.userName,
          c.number,
          c.issuer,
        ].any((s) => s.toLowerCase().contains(query))) {
      return false;
    }
    if (dateField.isNotEmpty) {
      final date = parseCalendarDate(
        dateField == 'issued' ? c.issuedAt : c.expiresAt,
      );
      if (date == null ||
          date.isBefore(DateTime(from.year, from.month, from.day)) ||
          date.isAfter(DateTime(to.year, to.month, to.day))) {
        return false;
      }
    }
    return true;
  }).toList()..sort(
    (a, b) => a.userName.compareTo(b.userName) != 0
        ? a.userName.compareTo(b.userName)
        : a.title.compareTo(b.title),
  );
}

StatisticsDataset certificateDataset(
  List<CertificateModel> certificates,
  DateTime now,
  List<String> filters,
) => StatisticsDataset(
  title: 'Tunnistused',
  filters: filters,
  columns: const [
    'Liige',
    'Tunnistus',
    'Liik',
    'Väljaandja',
    'Number',
    'Väljastatud',
    'Kehtib kuni',
    'Hetkeolek',
  ],
  rows: [
    for (final c in certificates)
      [
        c.userName,
        c.title,
        certificateTypeLabels[c.type] ?? c.type,
        c.issuer,
        c.number,
        c.issuedAt,
        c.noExpiry ? 'Tähtajatu' : c.expiresAt,
        c.noExpiry && c.displayStatusAt(now) != 'missing'
            ? 'Tähtajatu'
            : certificateStatusLabels[c.displayStatusAt(now)],
      ],
  ],
);

StatisticsDataset memberDataset(
  List<MemberContribution> members,
  List<String> filters,
) => StatisticsDataset(
  title: 'Liikmete statistika',
  filters: filters,
  columns: const [
    'Liige',
    'Valves (t)',
    'Hilinemisega (t)',
    'Panus (t)',
    'Väljakutsetel osalemisi',
    'Tegevustes osalemisi',
    'Koolitustel osalemisi',
    'Kinnitamisel',
    'Tundideta osalemisi',
  ],
  rows: [
    for (final m in members)
      [
        m.name,
        m.dutyHours,
        m.data['delayedHours'],
        m.number('contributionHours'),
        m.number('calloutCount'),
        m.number('activityCount'),
        (m.categories['training'] as Map?)?['count'] ?? 0,
        m.number('pendingCount'),
        m.number('unknownHoursCount'),
      ],
  ],
);

class StatisticsEntry {
  StatisticsEntry(this.member, this.data);
  final MemberContribution member;
  final Map<String, dynamic> data;
  bool get confirmed => data['confirmed'] == true;
  String get category => data['kind'] == 'callout'
      ? 'callout'
      : data['category'] as String? ?? 'other';
  String get title => data['title'] as String? ?? '';
  DateTime? get date => DateTime.tryParse(data['date'] as String? ?? '');
}

List<StatisticsEntry> statisticsEntries(
  List<MemberContribution> members, {
  String memberId = '',
  String category = '',
  String confirmation = '',
  String search = '',
}) {
  final query = search.trim().toLowerCase();
  final rows = [
    for (final m in members)
      for (final e in m.entries) StatisticsEntry(m, e),
  ];
  return rows
      .where(
        (r) =>
            (memberId.isEmpty || r.member.userId == memberId) &&
            (category.isEmpty || r.category == category) &&
            (confirmation.isEmpty ||
                r.confirmed == (confirmation == 'confirmed')) &&
            (query.isEmpty ||
                '${r.title} ${r.member.name}'.toLowerCase().contains(query)),
      )
      .toList()
    ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
}

StatisticsDataset entryDataset(
  List<StatisticsEntry> entries,
  List<String> filters,
) => StatisticsDataset(
  title: 'Panused ja osalemised',
  filters: filters,
  columns: const [
    'Liige',
    'Kuupäev',
    'Tegevus',
    'Kategooria',
    'Tunnid',
    'Kinnitus',
  ],
  rows: [
    for (final r in entries)
      [
        r.member.name,
        ActivitySchedule.format(r.date),
        r.title,
        r.category == 'callout'
            ? 'Väljakutse'
            : contributionTypes[r.category] ?? r.category,
        r.data['hours'],
        r.confirmed ? 'Kinnitatud' : 'Ootab kinnitust',
      ],
  ],
);

StatisticsDataset eventDataset(
  List<EventStatistics> events,
  List<String> filters, {
  bool attendance = false,
  String memberId = '',
}) => StatisticsDataset(
  title: attendance ? 'Sündmustel osalemised' : 'Sündmuste kokkuvõte',
  filters: filters,
  columns: attendance
      ? const [
          'Sündmus',
          'Algus',
          'Liik',
          'Olek',
          'Liige',
          'Tunnid',
          'Sündmuse ID',
        ]
      : const [
          'Sündmus',
          'Algus',
          'Lõpp',
          'Liik',
          'Olek',
          'Osalejaid',
          'Kinnitatud meeskond',
          'Teadaolevad töötunnid',
          'Tundideta osalemisi',
          'Sündmuse ID',
        ],
  rows: attendance
      ? [
          for (final e in events)
            for (final p in e.participants.where(
              (p) => memberId.isEmpty || p['userId'] == memberId,
            ))
              [
                e.title,
                ActivitySchedule.format(e.startedAt),
                e.typeLabel,
                e.statusLabel,
                p['name'],
                p['hours'],
                e.id,
              ],
        ]
      : [
          for (final e in events)
            [
              e.title,
              ActivitySchedule.format(e.startedAt),
              e.endedAt == null ? null : ActivitySchedule.format(e.endedAt),
              e.typeLabel,
              e.statusLabel,
              e.participants.length,
              e.participants.isEmpty
                  ? 'Osalemine kinnitamata'
                  : e.participants.map((p) => p['name']).join(', '),
              e.participants.isEmpty || e.unknownHours == e.participants.length
                  ? null
                  : e.hours,
              e.unknownHours,
              e.id,
            ],
        ],
);
