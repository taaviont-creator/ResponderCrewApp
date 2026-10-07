import '../widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/statistics_model.dart';
import '../services/statistics_service.dart';
import 'contribution_form_screen.dart';
import 'activities_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canViewStatistics,
    required this.canViewOrganizationCertificates,
    this.service,
  });
  final StatisticsService? service;
  final String organizationId, currentUid;
  final bool canViewStatistics, canViewOrganizationCertificates;
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final _service = widget.service ?? StatisticsService();
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  Future<ContributionReport>? _future;
  String _metric = 'dutyHours';
  String _search = '';
  bool _showOrganization = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.currentUid != widget.currentUid ||
        oldWidget.canViewStatistics != widget.canViewStatistics) {
      _showOrganization = false;
      _load();
    }
  }

  void _load() {
    _future = widget.canViewStatistics
        ? _service.load(
            organizationId: widget.organizationId,
            from: _from,
            to: _to,
          )
        : null;
  }

  void _refresh() => setState(_load);
  Future<void> _pickPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays > 365) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vali kuni 366 päeva pikkune periood.')),
      );
      return;
    }
    setState(() {
      _from = range.start;
      _to = range.end;
      _load();
    });
  }

  Future<void> _add(ContributionReport report) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionFormScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          members: report.members,
          canManage: report.canManage,
        ),
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _activities(ContributionReport report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivitiesScreen(
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          canManageActivities: report.canCreateActivities,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(
      title: const Text('Statistika'),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Arvestuse alused',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Arvestuse alused'),
              content: const Text(
                'Panusesse ja osalemistesse lähevad kinnitatud kirjed. Valvetunnid on eraldi; hilinemisega valmisolek on liikme detailides. Planeeritud eemalolekud ja ühingu valvepausid on valveajast maha arvatud.\n\nVäljakutsele reageerimise vastus ei kinnita osalemist. Puuduv ajalugu või märkimata tunnid ei tähenda nullpanust.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Selge'),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: _refresh,
          tooltip: 'Värskenda',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: !widget.canViewStatistics
        ? const Center(child: Text('Sul puudub statistika vaatamise õigus.'))
        : FutureBuilder<ContributionReport>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Statistika laadimine ebaõnnestus.'),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Proovi uuesti'),
                      ),
                    ],
                  ),
                );
              }
              final report = snapshot.data!;
              final members =
                  report.members
                      .where(
                        (m) => m.name.toLowerCase().contains(
                          _search.toLowerCase(),
                        ),
                      )
                      .toList()
                    ..sort(
                      (a, b) => b.number(_metric).compareTo(a.number(_metric)),
                    );
              final maximum = members.fold<num>(
                0,
                (max, m) => m.number(_metric) > max ? m.number(_metric) : max,
              );
              return RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  await _future;
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickPeriod,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            '${statisticsDate(_from)} – ${statisticsDate(_to)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _from = DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                            );
                            _to = DateTime.now();
                            _load();
                          }),
                          child: const Text('See kuu'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _from = DateTime(DateTime.now().year);
                            _to = DateTime.now();
                            _load();
                          }),
                          child: const Text('See aasta'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!report.canManage) ...[
                      ..._personalOverview(report),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _showOrganization = !_showOrganization,
                        ),
                        icon: Icon(
                          _showOrganization
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          _showOrganization
                              ? 'Peida ühingu ülevaade'
                              : 'Vaata ühingu ülevaadet',
                        ),
                      ),
                    ],
                    if (report.canManage || _showOrganization) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in const {
                            'total': 'Sündmusi kokku',
                            'period': 'Sündmusi perioodil',
                            'sar': 'SAR perioodil',
                            'tross': 'TROSS perioodil',
                            'closed': 'Lõpetatud perioodil',
                            'cancelled': 'Tühistatud perioodil',
                          }.entries)
                            _summary(
                              entry.value,
                              '${report.events[entry.key] ?? '—'}',
                            ),
                          _summary(
                            'Valves oldud',
                            report.hasDuty
                                ? statisticsHours(report.total('dutyHours'))
                                : '—',
                          ),
                          _summary(
                            'Panuse tunnid',
                            statisticsHours(report.total('contributionHours')),
                          ),
                          _summary(
                            'Väljakutsetel osalemisi',
                            '${report.total('calloutCount')}',
                          ),
                          _summary(
                            'Koolitustel osalemisi',
                            '${report.members.fold<int>(0, (n, m) => n + ((m.categories['training'] as Map?)?['count'] as num? ?? 0).toInt())}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        report.dutyHistoryPending
                            ? 'Valveajalugu uueneb. Värskenda mõne hetke pärast.'
                            : report.trackingStartedAt == null
                            ? 'Valvetundide ajalugu pole veel käivitatud.'
                            : 'Valveajalugu alates ${statisticsDate(report.trackingStartedAt!.toLocal())} kell ${report.trackingStartedAt!.toLocal().hour.toString().padLeft(2, '0')}:${report.trackingStartedAt!.toLocal().minute.toString().padLeft(2, '0')}. Varasem aeg pole teada.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),

                      if (report.undatedCount > 0)
                        Text(
                          '${report.undatedCount} osalemist jäi välja puuduva või vigase tegevuse kuupäeva tõttu.',
                        ),
                      if (report.total('unknownHoursCount') > 0)
                        Text(
                          '${report.total('unknownHoursCount')} kinnitatud osalemisel puuduvad tunnid.',
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (report.canManage && report.canRecord)
                            FilledButton.icon(
                              onPressed: () => _add(report),
                              icon: const Icon(Icons.add),
                              label: const Text('Lisa panus'),
                            ),
                          if (report.canManage)
                            OutlinedButton(
                              onPressed: () => _activities(report),
                              child: const Text('Tegevuste osalemised'),
                            ),
                          if (report.canManage)
                            OutlinedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivitiesScreen(
                                      organizationId: widget.organizationId,
                                      currentUid: widget.currentUid,
                                      canManageActivities: report.canManage,
                                      contributionsOnly: true,
                                    ),
                                  ),
                                );
                                if (mounted) _refresh();
                              },
                              child: const Text('Vaata panuseid'),
                            ),
                          if (report.canManage)
                            TextButton.icon(
                              onPressed: () async {
                                final csv =
                                    'Periood;${statisticsDate(_from)};${statisticsDate(_to)}\r\nValveajaloo algus;${report.trackingStartedAt?.toIso8601String() ?? 'puudub'}\r\n${contributionCsv(report)}';
                                await Clipboard.setData(
                                  ClipboardData(text: csv),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Perioodi statistika ja kirjed kopeeritud CSV-na.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('CSV'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Liikmete panus',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        itemHeight: null,
                        initialValue: _metric,
                        decoration: const InputDecoration(
                          labelText: 'Järjesta',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'dutyHours',
                            child: Text('Valves oldud aeg'),
                          ),
                          DropdownMenuItem(
                            value: 'contributionHours',
                            child: Text('Panuse tunnid'),
                          ),
                          DropdownMenuItem(
                            value: 'calloutCount',
                            child: Text('Väljakutsed'),
                          ),
                          DropdownMenuItem(
                            value: 'activityCount',
                            child: Text('Tegevustes osalemine'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _metric = value!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Otsi liiget',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                      const SizedBox(height: 12),
                      if (members.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Selles vaates pole liikmeid ega osalemisi.',
                          ),
                        ),
                      for (final member in members)
                        Card(
                          child: ExpansionTile(
                            key: ValueKey(
                              '${widget.organizationId}-${member.userId}',
                            ),
                            title: Text(member.name),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _metric == 'dutyHours'
                                        ? statisticsHours(member.dutyHours)
                                        : _metric == 'contributionHours'
                                        ? statisticsHours(
                                            member.number(_metric),
                                          )
                                        : '${member.number(_metric)} osalemist',
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: maximum > 0
                                        ? (member.number(_metric) / maximum)
                                              .toDouble()
                                        : 0,
                                  ),
                                ],
                              ),
                            ),
                            childrenPadding: const EdgeInsets.all(16),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (!member.active) const Text('Endine liige'),
                              Text(
                                'Valves: ${statisticsHours(member.dutyHours)} • Hilinemisega: ${statisticsHours(member.data['delayedHours'] as num?)}',
                              ),
                              Text(
                                'Väljakutsetel osales: ${member.number('calloutCount')} • Reageerin-vastuseid: ${member.number('responseCount')}',
                              ),
                              Text(
                                'Panus: ${statisticsHours(member.number('contributionHours'))} • Tegevusi: ${member.number('activityCount')}',
                              ),
                              for (final c in member.categories.entries)
                                Text(
                                  '${contributionTypes[c.key] ?? c.key}: ${(c.value as Map)['count']} korda · ${statisticsHours((c.value as Map)['hours'] as num?)}',
                                ),
                              if (member.number('pendingCount') > 0)
                                Text(
                                  'Kinnitamisel: ${member.number('pendingCount')}',
                                ),
                              if (member.number('unknownHoursCount') > 0)
                                Text(
                                  'Tunnid puudu: ${member.number('unknownHoursCount')} osalemisel',
                                ),
                              const Divider(),
                              if (member.entries.isEmpty)
                                const Text(
                                  'Sellel perioodil pole tegevuste ega väljakutsete osalemisi.',
                                ),
                              for (final e in member.entries)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    e['kind'] == 'callout'
                                        ? Icons.notifications_active_outlined
                                        : Icons.task_alt,
                                  ),
                                  title: Text(e['title'] as String),
                                  subtitle: Text(
                                    '${statisticsDate(DateTime.parse(e['date'] as String).toLocal())} · ${contributionTypes[e['category']] ?? 'Väljakutse'} · ${e['hours'] == null ? 'Tunnid märkimata' : statisticsHours(e['hours'] as num)}${e['confirmed'] == true ? '' : ' · Ootab kinnitust'}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
  );
  List<Widget> _personalOverview(ContributionReport report) {
    final member = report.members
        .where((m) => m.userId == widget.currentUid)
        .firstOrNull;
    return [
      Text('Minu panus', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (member == null)
        const Text('Selle perioodi kohta pole sinu andmeid veel saadaval.')
      else ...[
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            _summary('Valves oldud', statisticsHours(member.dutyHours)),
            _summary(
              'Panuse tunnid',
              statisticsHours(member.number('contributionHours')),
            ),
            _summary(
              'Väljakutsetel osalemisi',
              '${member.number('calloutCount')}',
            ),
            _summary(
              'Koolitustel osalemisi',
              '${(member.categories['training'] as Map?)?['count'] ?? 0}',
            ),
          ],
        ),
        if (report.dutyHistoryPending)
          const Text('Valveajalugu uueneb. Värskenda mõne hetke pärast.'),
        if (member.dutyHours == null)
          const Text(
            'Sinu valveaja kohta pole sellel perioodil piisavalt andmeid.',
          ),
        if (member.number('pendingCount') > 0)
          Text('Kinnitamisel: ${member.number('pendingCount')} osalemist'),
        const SizedBox(height: 16),
        if (member.entries.isEmpty)
          const Text('Sellel perioodil pole veel osalemisi ega panuseid.')
        else
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Minu osalemised ja panused (${member.entries.length})',
            ),
            children: [
              for (final entry in member.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry['title'] as String),
                  subtitle: Text(
                    '${statisticsDate(DateTime.parse(entry['date'] as String).toLocal())} · ${entry['hours'] == null ? 'Tunnid märkimata' : statisticsHours(entry['hours'] as num)}${entry['confirmed'] == true ? '' : ' · Ootab kinnitust'}',
                  ),
                ),
            ],
          ),
      ],
      if (report.canRecord)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _add(report),
            icon: const Icon(Icons.add),
            label: const Text('Lisa panus'),
          ),
        ),
    ];
  }

  Widget _summary(String title, String value) =>
      MetricValue(title: title, value: value);
}
