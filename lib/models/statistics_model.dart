const contributionTypes = <String, String>{
  'training': 'Koolitus',
  'exercise': 'Harjutus',
  'maintenance': 'Hooldus',
  'repair': 'Remont',
  'groundskeeping': 'Heakord / niitmine',
  'meeting': 'Koosolek',
  'event': 'Sündmus',
  'other': 'Muu tegevus',
};
String statisticsDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String statisticsHours(num? hours) =>
    hours == null ? '—' : '${hours.toStringAsFixed(1).replaceAll('.', ',')} t';
Map<String, dynamic> statisticsMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

class ContributionReport {
  ContributionReport(Map<String, dynamic> data)
    : events = Map<String, dynamic>.from(data['events'] as Map? ?? {}),
      members = (data['members'] as List)
          .map((m) => MemberContribution(statisticsMap(m)))
          .toList(),
      trackingStartedAt = DateTime.tryParse(
        data['trackingStartedAt'] as String? ?? '',
      ),
      dutyHistoryPending = data['dutyHistoryPending'] == true,
      undatedCount = (data['undatedCount'] as num?)?.toInt() ?? 0,
      canManage = data['canManage'] == true,
      canRecord = data['canRecord'] == true;
  final Map<String, dynamic> events;
  final List<MemberContribution> members;
  final DateTime? trackingStartedAt;
  final bool dutyHistoryPending, canManage, canRecord;
  final int undatedCount;
  num total(String field) =>
      members.fold<num>(0, (sum, member) => sum + member.number(field));
  bool get hasDuty => members.any((m) => m.data['dutyHours'] != null);
}

class MemberContribution {
  MemberContribution(this.data);
  final Map<String, dynamic> data;
  String get userId => data['userId'] as String;
  String get name => data['name'] as String? ?? 'Liige';
  bool get active => data['active'] == true;
  num number(String field) => data[field] as num? ?? 0;
  num? get dutyHours => data['dutyHours'] as num?;
  List<Map<String, dynamic>> get entries =>
      (data['entries'] as List).map(statisticsMap).toList();
  Map<String, dynamic> get categories => statisticsMap(data['categories']);
}

String contributionCsv(ContributionReport report) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+@\-\t\r\n]').hasMatch(text.trimLeft())) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<Object?>>[
    [
      'Liige',
      'Valves t',
      'Hilinemisega t',
      'Kinnitatud väljakutseid',
      'Kinnitatud tegevusi',
      'Panus t',
      'Ootel',
      'Tundideta osalemisi',
    ],
    for (final m in report.members)
      [
        m.name,
        m.data['dutyHours'],
        m.data['delayedHours'],
        m.number('calloutCount'),
        m.number('activityCount'),
        m.number('contributionHours'),
        m.number('pendingCount'),
        m.number('unknownHoursCount'),
      ],
    [],
    ['Liige', 'Kuupäev', 'Tegevus', 'Liik', 'Tunnid', 'Kinnitatud'],
    for (final m in report.members)
      for (final e in m.entries)
        [
          m.name,
          e['date'],
          e['title'],
          contributionTypes[e['category']] ?? 'Väljakutse',
          e['hours'],
          e['confirmed'] == true ? 'Jah' : 'Ootel',
        ],
  ];
  return rows.map((row) => row.map(cell).join(';')).join('\r\n');
}
