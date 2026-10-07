import 'package:flutter/material.dart';
import '../models/activity_schedule.dart';
import '../models/certificate_model.dart';
import '../models/event_statistics.dart';
import '../models/statistics_model.dart';
import '../models/statistics_workspace.dart';
import '../services/statistics_service.dart';
import '../services/statistics_export_service.dart';
import '../widgets/app_layout.dart';
import '../widgets/statistics_charts.dart';
import '../widgets/statistics_workspace_widgets.dart';
import 'contribution_form_screen.dart';

enum StatisticsSection {
  organization,
  personal,
  members,
  events,
  contributions,
  certificates,
}

const _sections = {
  StatisticsSection.organization: 'Ühing',
  StatisticsSection.personal: 'Minu statistika',
  StatisticsSection.members: 'Liikmed',
  StatisticsSection.events: 'Sündmused',
  StatisticsSection.contributions: 'Panused',
  StatisticsSection.certificates: 'Tunnistused',
};

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.organizationId,
    this.organizationName,
    required this.currentUid,
    required this.canViewStatistics,
    required this.canViewOrganizationCertificates,
    this.service,
    this.exporter,
  });
  final String organizationId, currentUid;
  final String? organizationName;
  final bool canViewStatistics, canViewOrganizationCertificates;
  final StatisticsService? service;
  final StatisticsExportService? exporter;
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final _service = widget.service ?? StatisticsService();
  late final _exporter = widget.exporter ?? StatisticsExportService();
  late DateTime _from = DateTime(DateTime.now().year);
  DateTime _to = DateTime.now();
  Future<ContributionReport>? _future;
  Future<List<CertificateModel>>? _certificates;
  bool? _certificateScope;
  StatisticsSection? _section;
  String _member = '',
      _type = '',
      _status = '',
      _search = '',
      _metric = 'dutyHours',
      _certificateDate = '';
  bool _exporting = false;
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.currentUid != widget.currentUid ||
        oldWidget.canViewStatistics != widget.canViewStatistics ||
        oldWidget.canViewOrganizationCertificates !=
            widget.canViewOrganizationCertificates) {
      _section = null;
      _clearFilters();
      _certificates = null;
      _certificateScope = null;
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

  void _clearFilters() {
    _member = '';
    _type = '';
    _status = '';
    _search = '';
    _certificateDate = '';
    _searchController.clear();
  }

  void _select(StatisticsSection section) {
    setState(() {
      _section = section;
      _clearFilters();
    });
  }

  void _refresh() {
    setState(() {
      _certificates = null;
      _load();
    });
  }

  void _period(DateTime from, DateTime to) {
    setState(() {
      _from = from;
      _to = to;
      _load();
    });
  }

  Future<void> _pickPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null || !mounted) return;
    if (DateTime.utc(range.end.year, range.end.month, range.end.day)
            .difference(
              DateTime.utc(
                range.start.year,
                range.start.month,
                range.start.day,
              ),
            )
            .inDays >
        365) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vali kuni 366 päeva pikkune periood.')),
      );
      return;
    }
    _period(range.start, range.end);
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final year = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Vali aasta'),
        children: [
          for (var year = now.year; year >= 2000; year--)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, year),
              child: Text('$year'),
            ),
        ],
      ),
    );
    if (year != null && mounted) {
      _period(DateTime(year), year == now.year ? now : DateTime(year, 12, 31));
    }
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

  Future<void> _export(
    StatisticsDataset data,
    bool pdf,
    BuildContext anchor,
  ) async {
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exporting = true);
    try {
      final result = await _exporter.save(
        data,
        pdf: pdf,
        filename:
            'RespondCrew-${_section?.name ?? 'organization'}-${statisticsDate(_from)}-${statisticsDate(_to)}',
        origin: origin,
      );
      if (mounted && result != StatisticsExportResult.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == StatisticsExportResult.saved
                  ? 'Fail salvestatud / allalaadimine käivitatud.'
                  : 'Fail edastatud telefoni jagamisvaatesse.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Faili loomine või salvestamine ebaõnnestus. Proovi uuesti.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<String> _filters(ContributionReport report) => [
    'Ühing: ${widget.organizationName ?? widget.organizationId}',
    'Periood: ${ActivitySchedule.date(_from)} – ${ActivitySchedule.date(_to)} (Eesti aeg)',
    if (report.generatedAt != null)
      'Andmed seisuga: ${ActivitySchedule.format(report.generatedAt)}',
    if (_member.isNotEmpty)
      'Liige: ${report.members.where((m) => m.userId == _member).firstOrNull?.name ?? _member}',
    if (_type.isNotEmpty)
      'Liik/kategooria: ${eventTypeLabels[_type] ?? contributionTypes[_type] ?? certificateTypeLabels[_type] ?? _type}',
    if (_status.isNotEmpty)
      'Olek: ${eventStatusLabels[_status] ?? certificateStatusLabels[_status] ?? (_status == 'confirmed'
              ? 'Kinnitatud'
              : _status == 'pending'
              ? 'Ootab kinnitust'
              : _status)}',
    if (_search.isNotEmpty) 'Otsing: $_search',
  ];
  void _openMember(MemberContribution member) {
    setState(() {
      _section = StatisticsSection.members;
      _clearFilters();
      _member = member.userId;
    });
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(
      title: const Text('Statistika'),
      actions: [
        IconButton(
          tooltip: 'Arvestuse alused',
          icon: const Icon(Icons.info_outline),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Arvestuse alused'),
              content: const SingleChildScrollView(
                child: Text(
                  'Panuse tunnid ja osalemised põhinevad kinnitatud kirjetel. Valvetunnid on eraldi ning arvestavad planeeritud eemalolekuid ja ühingu valvepause. Puuduv ajalugu ei tähenda nulli.\n\nVäljakutsed on alguskuupäeva järgi. Testväljakutsed on välja jäetud. „Reageerin” vastus ei kinnita osalemist. Liikmefilter valib tema sündmused; sündmuse meeskonnas on kõik kinnitatud osalejad.\n\nTunnistused näitavad hetkeandmeid. Kuupäevafilter otsib tunnistusi väljastamise või aegumise kuupäeva järgi, mitte ajaloolist seisu.\n\nEksport sisaldab kõiki filtrile vastavaid ridu, mitte ainult nähtavat tabelilehte. CSV on tabelarvutuseks, PDF loetavaks kokkuvõtteks. Telefonis avaneb faili jagamine või salvestamine; veebis laaditakse fail alla.',
                ),
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
          tooltip: 'Värskenda',
          onPressed: _refresh,
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
              _section ??= report.canManage
                  ? StatisticsSection.organization
                  : StatisticsSection.personal;
              if (_section == StatisticsSection.events && !report.canManage) {
                _section = StatisticsSection.personal;
              }
              if (_section == StatisticsSection.certificates) {
                final wide =
                    report.canManage && widget.canViewOrganizationCertificates;
                if (_certificateScope != wide) {
                  _certificates = null;
                  _certificateScope = wide;
                }
                _certificates ??= _service.certificates(
                  organizationId: widget.organizationId,
                  currentUid: widget.currentUid,
                  organizationWide: wide,
                );
                return FutureBuilder<List<CertificateModel>>(
                  future: _certificates,
                  builder: (context, cert) => _workspace(
                    report,
                    certificates: cert.data,
                    certificateLoading:
                        cert.connectionState == ConnectionState.waiting,
                    certificateError: cert.hasError,
                  ),
                );
              }
              return _workspace(report);
            },
          ),
  );

  Widget _workspace(
    ContributionReport report, {
    List<CertificateModel>? certificates,
    bool certificateLoading = false,
    bool certificateError = false,
  }) {
    final personal = _section == StatisticsSection.personal;
    final all = report.members;
    final filteredMembers =
        all
            .where(
              (m) =>
                  (!personal || m.userId == widget.currentUid) &&
                  (_member.isEmpty || m.userId == _member) &&
                  (_search.isEmpty ||
                      m.name.toLowerCase().contains(_search.toLowerCase())),
            )
            .toList()
          ..sort((a, b) => b.number(_metric).compareTo(a.number(_metric)));
    final own = all.where((m) => m.userId == widget.currentUid).toList();
    final entries = statisticsEntries(
      personal || !report.canManage ? own : all,
      memberId: _member,
      category: _type,
      confirmation: _status,
      search: _search,
    );
    final events = filterEventStatistics(
      (report.eventDetails ?? []).map(EventStatistics.new).toList(),
      type: _type,
      status: _status,
      memberId: _member,
      search: _search,
    );
    final now = ActivitySchedule.inEstonia(DateTime.now());
    final certs = filterStatisticsCertificates(
      certificates ?? [],
      now: now,
      from: _from,
      to: _to,
      memberId: report.canManage && widget.canViewOrganizationCertificates
          ? _member
          : widget.currentUid,
      type: _type,
      status: _status,
      search: _search,
      dateField: _certificateDate,
    );
    final filters = _filters(report);
    final dataset = switch (_section!) {
      StatisticsSection.events => eventDataset(events, filters),
      StatisticsSection.contributions => entryDataset(entries, filters),
      StatisticsSection.certificates => certificateDataset(certs, now, [
        ...filters,
        'Hetkeolek: ${ActivitySchedule.date(now)}',
        _certificateDate.isEmpty
            ? 'Kõik kuupäevad; perioodifiltrit ei rakendata.'
            : _certificateDate == 'issued'
            ? 'Väljastatud valitud perioodil'
            : 'Aegub valitud perioodil',
      ]),
      _ => memberDataset(personal ? own : filteredMembers, filters),
    };
    final canExport =
        report.canManage &&
        !_exporting &&
        dataset.rows.isNotEmpty &&
        (_section != StatisticsSection.certificates ||
            (!certificateLoading && !certificateError)) &&
        (_section != StatisticsSection.events || report.eventDetails != null);
    return ListView(
      key: ValueKey('${widget.organizationId}-${_section!.name}'),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickYear,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _from.year == _to.year
                    ? '${_from.year} · Vali aasta'
                    : 'Vali aasta',
              ),
            ),
            OutlinedButton(
              onPressed: _pickPeriod,
              child: Text(
                '${ActivitySchedule.date(_from)} – ${ActivitySchedule.date(_to)}',
              ),
            ),
            TextButton(
              onPressed: () => _period(
                DateTime(DateTime.now().year, DateTime.now().month),
                DateTime.now(),
              ),
              child: const Text('See kuu'),
            ),
            if (report.canManage)
              Builder(
                builder: (anchor) => PopupMenuButton<String>(
                  enabled: canExport,
                  tooltip: 'Ekspordi filtreeritud andmed',
                  onSelected: (value) => _export(
                    value == 'attendance'
                        ? eventDataset(
                            events,
                            filters,
                            attendance: true,
                            memberId: _member,
                          )
                        : dataset,
                    value == 'pdf',
                    anchor,
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'csv',
                      child: Text('CSV tabel · ${dataset.rows.length} rida'),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Text('PDF kokkuvõte'),
                    ),
                    if (_section == StatisticsSection.events)
                      const PopupMenuItem(
                        value: 'attendance',
                        child: Text('Osalemised CSV'),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _exporting ? Icons.hourglass_top : Icons.download,
                          color: canExport
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).disabledColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ekspordi',
                          style: TextStyle(
                            color: canExport
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in _sections.entries)
              if (entry.key != StatisticsSection.events || report.canManage)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _section == entry.key,
                  onSelected: (_) => _select(entry.key),
                ),
          ],
        ),
        const SizedBox(height: 18),
        if (_section == StatisticsSection.organization || personal)
          ..._overview(report, personal ? own : all, personal),
        if (_section == StatisticsSection.members) ...[
          ..._queryControls(report, member: true, search: true, sort: true),
          _summary(filteredMembers),
          StatisticsDataTable(
            data: dataset,
            openRow: (i) => _memberDetails(filteredMembers[i]),
          ),
        ],
        if (_section == StatisticsSection.events) ...[
          ..._queryControls(
            report,
            member: true,
            search: true,
            types: eventTypeLabels,
            statuses: eventStatusLabels,
          ),
          if (report.eventDetails == null)
            const Text(
              'Sündmuste andmed pole serverist veel saadaval. Värskenda statistikat.',
            )
          else ...[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Sündmusi: ${events.length}'),
                Text('SAR: ${events.where((e) => e.type == 'sar').length}'),
                Text('Tross: ${events.where((e) => e.type == 'tross').length}'),
                Text(
                  'Kinnitatud osalemisi: ${events.fold<int>(0, (n, e) => n + e.participants.where((p) => _member.isEmpty || p['userId'] == _member).length)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Alguskuupäeva järgi · testväljakutseteta · ainult kinnitatud osalemised',
            ),
            if ((report.events['undated'] as num? ?? 0) > 0)
              Text(
                '${report.events['undated']} väljakutsel on kuupäev teadmata; neid perioodivalikus ei ole.',
              ),
            const SizedBox(height: 12),
            StatisticsDataTable(
              data: dataset,
              openRow: (i) => _eventDetails(events[i]),
            ),
          ],
        ],
        if (_section == StatisticsSection.contributions) ...[
          ..._queryControls(
            report,
            member: report.canManage,
            search: true,
            types: {...contributionTypes, 'callout': 'Väljakutsed'},
            statuses: const {
              'confirmed': 'Kinnitatud',
              'pending': 'Ootab kinnitust',
            },
          ),
          Text(
            'Kinnitatud panus: ${statisticsHours(entries.where((e) => e.confirmed).fold<num>(0, (n, e) => n + (e.data['hours'] as num? ?? 0)))} · Kinnitamisel: ${entries.where((e) => !e.confirmed).length}',
          ),
          if (report.canRecord)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _add(report),
                icon: const Icon(Icons.add),
                label: const Text('Lisa panus'),
              ),
            ),
          StatisticsDataTable(data: dataset),
        ],
        if (_section == StatisticsSection.certificates) ...[
          Text(
            report.canManage && widget.canViewOrganizationCertificates
                ? 'Ühingu tunnistused · hetkeseis'
                : 'Minu tunnistused · hetkeseis',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ..._queryControls(
            report,
            member: report.canManage && widget.canViewOrganizationCertificates,
            search: true,
            types: certificateTypeLabels,
            statuses: certificateStatusLabels,
            extra: _dropdown('Kuupäevad', _certificateDate, {
              '': 'Kõik kuupäevad',
              'issued': 'Väljastatud perioodil',
              'expiry': 'Aegub perioodil',
            }, (v) => setState(() => _certificateDate = v)),
          ),
          if (certificateLoading)
            const Center(child: CircularProgressIndicator())
          else if (certificateError)
            Column(
              children: [
                const Text(
                  'Tunnistuste laadimine ebaõnnestus. Väljavõtet ei koostatud.',
                ),
                TextButton(
                  onPressed: () => setState(() => _certificates = null),
                  child: const Text('Proovi uuesti'),
                ),
              ],
            )
          else ...[
            Text(
              '${certs.length} tunnistust · kehtivust hinnatakse ${ActivitySchedule.date(now)} seisuga',
            ),
            const SizedBox(height: 12),
            StatisticsDataTable(data: dataset),
          ],
        ],
      ],
    );
  }

  List<Widget> _queryControls(
    ContributionReport report, {
    bool member = false,
    bool search = false,
    bool sort = false,
    Map<String, String>? types,
    Map<String, String>? statuses,
    Widget? extra,
  }) => [
    Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (member)
          _dropdown('Liige', _member, {
            '': 'Kõik liikmed',
            for (final m in report.members) m.userId: m.name,
            if (_member.isNotEmpty &&
                !report.members.any((m) => m.userId == _member))
              _member: 'Valitud liige (perioodil andmed puuduvad)',
          }, (v) => setState(() => _member = v)),
        if (types != null)
          _dropdown('Liik / kategooria', _type, {
            '': 'Kõik liigid',
            ...types,
          }, (v) => setState(() => _type = v)),
        if (statuses != null)
          _dropdown('Olek', _status, {
            '': 'Kõik olekud',
            ...statuses,
          }, (v) => setState(() => _status = v)),
        if (sort)
          _dropdown('Järjesta', _metric, {
            'dutyHours': 'Valveaeg',
            'contributionHours': 'Panuse tunnid',
            'calloutCount': 'Väljakutsetel osalemisi',
            'activityCount': 'Tegevustes osalemisi',
          }, (v) => setState(() => _metric = v)),
        ?extra,
      ],
    ),
    if (search) ...[
      const SizedBox(height: 12),
      TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Otsi',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Tühjenda otsing',
            onPressed: () => setState(() {
              _search = '';
              _searchController.clear();
            }),
            icon: const Icon(Icons.close),
          ),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    ],
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => setState(_clearFilters),
        child: const Text('Tühjenda filtrid'),
      ),
    ),
  ];
  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> change,
  ) => LayoutBuilder(
    builder: (context, b) => SizedBox(
      width: b.maxWidth < 600 ? b.maxWidth : 250,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: options.containsKey(value) ? value : '',
        isExpanded: true,
        itemHeight: null,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) change(v);
        },
      ),
    ),
  );
  Widget _summary(List<MemberContribution> members) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        MetricValue(
          title: 'Valves oldud',
          value: members.any((m) => m.dutyHours != null)
              ? statisticsHours(
                  members.fold<num>(0, (n, m) => n + (m.dutyHours ?? 0)),
                )
              : '—',
        ),
        MetricValue(
          title: 'Panuse tunnid',
          value: statisticsHours(
            members.fold<num>(0, (n, m) => n + m.number('contributionHours')),
          ),
        ),
        MetricValue(
          title: 'Väljakutsetel osalemisi',
          value:
              '${members.fold<num>(0, (n, m) => n + m.number('calloutCount'))}',
        ),
        MetricValue(
          title: 'Koolitustel osalemisi',
          value:
              '${members.fold<num>(0, (n, m) => n + ((m.categories['training'] as Map?)?['count'] as num? ?? 0))}',
        ),
      ],
    ),
  );
  List<Widget> _overview(
    ContributionReport report,
    List<MemberContribution> members,
    bool personal,
  ) {
    final entries = statisticsEntries(members, confirmation: 'confirmed');
    return [
      Text(
        personal ? 'Minu panus' : 'Ühingu ülevaade',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      _summary(members),
      if (personal && members.isEmpty)
        const Text('Selle perioodi kohta pole sinu andmeid veel saadaval.'),
      if (report.dutyHistoryPending)
        const Text('Valveajalugu uueneb. Värskenda mõne hetke pärast.'),
      if (members.any((m) => m.dutyHours == null))
        Text(
          personal
              ? 'Sinu valveaja kohta pole sellel perioodil piisavalt andmeid.'
              : 'Mõne liikme valveajalugu puudub; kogusumma hõlmab ainult teadaolevat aega.',
        ),
      if (report.trackingStartedAt != null)
        Text(
          'Valveajalugu alates ${ActivitySchedule.format(report.trackingStartedAt)}. Varasem aeg pole teada.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (report.undatedCount > 0)
        Text('${report.undatedCount} osalemisel on kuupäev puudulik.'),
      const SizedBox(height: 16),
      if (!personal) ...[
        StatisticsGrid(
          children: [
            StatisticsRanking(
              title: 'Valves oldud aeg',
              members: members,
              metric: 'dutyHours',
              select: _openMember,
            ),
            StatisticsRanking(
              title: 'Panuse tunnid',
              members: members,
              metric: 'contributionHours',
              select: _openMember,
            ),
            StatisticsRanking(
              title: 'Väljakutsetel osalemine',
              members: members,
              metric: 'calloutCount',
              select: _openMember,
            ),
            StatisticsRanking(
              title: 'Koolitustel osalemine',
              members: members,
              metric: 'training',
              select: _openMember,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      StatisticsCharts(
        members: members,
        events: personal ? null : report.events,
      ),
      const SizedBox(height: 16),
      StatisticsPanel(
        title: 'Viimased kinnitatud panused',
        action: TextButton(
          onPressed: () {
            _select(StatisticsSection.contributions);
            if (personal) setState(() => _member = widget.currentUid);
          },
          child: const Text('Vaata kõiki'),
        ),
        child: Column(
          children: [
            if (entries.isEmpty) const Text('Kinnitatud panuseid ei ole.'),
            for (final e in entries.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title),
                subtitle: Text(
                  '${e.member.name} · ${ActivitySchedule.format(e.date)}',
                ),
                trailing: Text(statisticsHours(e.data['hours'] as num?)),
              ),
          ],
        ),
      ),
      if (report.canRecord)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _add(report),
            icon: const Icon(Icons.add),
            label: const Text('Lisa panus'),
          ),
        ),
    ];
  }

  Future<void> _memberDetails(MemberContribution m) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(m.name),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Valves: ${statisticsHours(m.dutyHours)} · Hilinemisega: ${statisticsHours(m.data['delayedHours'] as num?)}',
              ),
              Text(
                'Väljakutsetel osales: ${m.number('calloutCount')} • Reageerin-vastuseid: ${m.number('responseCount')}',
              ),
              if (!m.active) const Text('Endine liige'),
              for (final e in statisticsEntries([m]))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.title),
                  subtitle: Text(
                    '${ActivitySchedule.format(e.date)} · ${statisticsHours(e.data['hours'] as num?)}${e.confirmed ? '' : ' · Ootab kinnitust'}',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Sulge'),
        ),
      ],
    ),
  );
  Future<void> _eventDetails(EventStatistics event) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(event.title),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${event.typeLabel} · ${event.statusLabel}'),
              Text(ActivitySchedule.format(event.startedAt)),
              SelectableText('ID: ${event.id}'),
              if (event.participants.isEmpty)
                const Text('Kinnitatud osalejaid pole veel märgitud.'),
              for (final p in event.participants)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p['name'] as String),
                  subtitle: Text(
                    p['hours'] == null
                        ? 'Tunnid märkimata'
                        : statisticsHours(p['hours'] as num),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Sulge'),
        ),
      ],
    ),
  );
}
