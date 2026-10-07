import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/activity_schedule.dart';
import '../models/event_statistics.dart';
import '../models/statistics_model.dart';
import '../widgets/app_layout.dart';

class EventStatisticsScreen extends StatefulWidget {
  const EventStatisticsScreen({
    super.key,
    required this.report,
    required this.organizationId,
    required this.from,
    required this.to,
  });
  final ContributionReport report;
  final String organizationId;
  final DateTime from, to;
  @override
  State<EventStatisticsScreen> createState() => _EventStatisticsScreenState();
}

class _EventStatisticsScreenState extends State<EventStatisticsScreen> {
  String _type = '', _status = '', _member = '', _search = '';
  bool _exporting = false;

  Future<void> _export(
    BuildContext anchorContext,
    List<EventStatistics> events,
    bool attendance,
  ) async {
    if (!widget.report.canManage || _exporting) return;
    final box = anchorContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exporting = true);
    try {
      final csv = eventStatisticsCsv(
        events: events,
        organizationId: widget.organizationId,
        from: widget.from,
        to: widget.to,
        attendance: attendance,
        type: _type,
        status: _status,
        memberId: _member,
        search: _search,
        generatedAt: widget.report.generatedAt,
      );
      final name =
          'RespondCrew-${attendance ? 'osalemised' : 'sundmused'}-${statisticsDate(widget.from)}-${statisticsDate(widget.to)}.csv';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode('\uFEFF$csv')),
              mimeType: 'text/csv',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
          downloadFallbackEnabled: true,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Väljavõtte salvestamine ebaõnnestus. Proovi uuesti.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.report.canManage) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Sündmuste väljavõte')),
        body: const Center(
          child: Text('Väljavõtteid saab koostada ühingu admin.'),
        ),
      );
    }
    final all = (widget.report.eventDetails ?? [])
        .map(EventStatistics.new)
        .toList();
    final members = <String, String>{
      for (final e in all)
        for (final p in e.participants)
          p['userId'] as String: p['name'] as String,
    };
    final sortedMembers = members.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final events = filterEventStatistics(
      all,
      type: _type,
      status: _status,
      memberId: _member,
      search: _search,
    );
    final participants = events
        .expand((e) => e.participants)
        .where((p) => _member.isEmpty || p['userId'] == _member)
        .toList();
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Sündmuste väljavõte'),
        actions: [
          IconButton(
            tooltip: 'Väljavõtte selgitus',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Väljavõtte arvestus'),
                content: const SingleChildScrollView(
                  child: Text(
                    'Periood valitakse statistika lehel. Sündmused arvestatakse alguskuupäeva järgi Eesti ajas. Testväljakutsed on välja jäetud.\n\n„Reageerin” vastus ei kinnita osalemist. Liikmefilter valib tema sündmused; sündmuse juures jääb kogu kinnitatud meeskond nähtavaks. Osalemiste CSV sisaldab valitud liikme ridu.\n\nCSV avaneb tabelarvutuses. Telefonis saad faili salvestada või jagada; veebis on jagamise puudumisel allalaadimine.',
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${ActivitySchedule.date(widget.from)} – ${ActivitySchedule.date(widget.to)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('Alguskuupäeva järgi · testväljakutseteta'),
          const SizedBox(height: 12),
          if (widget.report.eventDetails == null)
            const Text(
              'Sündmuste väljavõte vajab serveri uuendust. Pärast uuendamist värskenda statistikat.',
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _filter('Liik', _type, {
                  '': 'Kõik liigid',
                  ...eventTypeLabels,
                }, (v) => setState(() => _type = v)),
                _filter('Olek', _status, {
                  '': 'Kõik olekud',
                  ...eventStatusLabels,
                }, (v) => setState(() => _status = v)),
                _filter('Kinnitatud osaleja', _member, {
                  '': 'Kõik liikmed',
                  for (final m in sortedMembers) m.key: m.value,
                }, (v) => setState(() => _member = v)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Otsi sündmust',
                hintText: 'Pealkiri või ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Sündmusi: ${events.length}'),
                Text(
                  'Erinevaid osalejaid: ${participants.map((p) => p['userId']).toSet().length}',
                ),
                Text('Kinnitatud osalemisi: ${participants.length}'),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Arvestuses on ainult kinnitatud osalemised.'),
            if ((widget.report.events['undated'] as num? ?? 0) > 0)
              Text(
                '${widget.report.events['undated']} ühingu väljakutsel puudub korrektne algusaeg ja neid ei saa perioodi väljavõttesse kaasata.',
              ),
            const SizedBox(height: 12),
            Builder(
              builder: (anchorContext) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: events.isEmpty || _exporting
                        ? null
                        : () => _export(anchorContext, events, false),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Sündmused CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: participants.isEmpty || _exporting
                        ? null
                        : () => _export(anchorContext, events, true),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Osalemised CSV'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              const Text('Valitud tingimustele vastavaid sündmusi ei ole.'),
            for (final event in events)
              Card(
                child: ExpansionTile(
                  title: Text(event.title),
                  subtitle: Text(
                    '${ActivitySchedule.format(event.startedAt)} · ${event.typeLabel} · ${event.statusLabel}\nKinnitatud osalejaid: ${event.participants.length}',
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText('ID: ${event.id}'),
                    if (event.endedAt != null)
                      Text('Lõpp: ${ActivitySchedule.format(event.endedAt)}'),
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
          ],
        ],
      ),
    );
  }

  Widget _filter(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> change,
  ) => LayoutBuilder(
    builder: (context, bounds) => SizedBox(
      width: bounds.maxWidth < 600 ? bounds.maxWidth : 280,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        itemHeight: null,
        decoration: InputDecoration(labelText: label),
        items: values.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (value) {
          if (value != null) change(value);
        },
      ),
    ),
  );
}
