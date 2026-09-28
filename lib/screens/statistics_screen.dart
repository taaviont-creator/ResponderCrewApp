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
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.canViewStatistics != widget.canViewStatistics) {
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
          canManageActivities: report.canRecord,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Panus ja statistika'),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Arvestuse alused',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Arvestuse alused'),
              content: const Text(
                'Panusesse ja osalemistesse lähevad admini kinnitatud kirjed. Valvetunnid on eraldi; hilinemisega valmisolek on liikme detailides. Planeeritud eemalolekud on valveajast maha arvatud.\n\nVäljakutsele reageerimise vastus ei kinnita osalemist. Puuduv ajalugu või märkimata tunnid ei tähenda nullpanust.',
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
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
                        if (report.canRecord)
                          FilledButton.icon(
                            onPressed: () => _add(report),
                            icon: const Icon(Icons.add),
                            label: const Text('Lisa panus'),
                          ),
                        OutlinedButton(
                          onPressed: () => _activities(report),
                          child: Text(
                            report.canManage && report.total('pendingCount') > 0
                                ? 'Kinnita osalemised (${report.total('pendingCount')})'
                                : 'Tegevused',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final csv =
                                'Periood;${statisticsDate(_from)};${statisticsDate(_to)}\r\nValveajaloo algus;${report.trackingStartedAt?.toIso8601String() ?? 'puudub'}\r\n${contributionCsv(report)}';
                            await Clipboard.setData(ClipboardData(text: csv));
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
                      initialValue: _metric,
                      decoration: const InputDecoration(labelText: 'Järjesta'),
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
                                      ? statisticsHours(member.number(_metric))
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
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
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
                ),
              );
            },
          ),
  );
  Widget _summary(String title, String value) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 40) / 2,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(title),
          ],
        ),
      ),
    ),
  );
}
