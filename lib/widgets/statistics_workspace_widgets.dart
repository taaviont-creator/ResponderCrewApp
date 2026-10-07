import 'package:flutter/material.dart';
import '../models/statistics_model.dart';
import '../models/statistics_workspace.dart';

class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class StatisticsGrid extends StatelessWidget {
  const StatisticsGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide =
          bounds.maxWidth >= 800 &&
          MediaQuery.textScalerOf(context).scale(16) < 25;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: wide ? (bounds.maxWidth - 12) / 2 : bounds.maxWidth,
              child: child,
            ),
        ],
      );
    },
  );
}

class StatisticsRanking extends StatelessWidget {
  const StatisticsRanking({
    super.key,
    required this.title,
    required this.members,
    required this.metric,
    required this.select,
  });
  final String title, metric;
  final List<MemberContribution> members;
  final ValueChanged<MemberContribution> select;
  num value(MemberContribution m) => metric == 'training'
      ? (((m.categories['training'] as Map?)?['count'] as num?) ?? 0)
      : m.number(metric);
  @override
  Widget build(BuildContext context) {
    final rows = [...members]..sort((a, b) => value(b).compareTo(value(a)));
    final max = rows.fold<num>(0, (n, m) => value(m) > n ? value(m) : n);
    return StatisticsPanel(
      title: title,
      child: Column(
        children: [
          if (rows.isEmpty) const Text('Selle perioodi kohta pole andmeid.'),
          for (final m in rows.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => select(m),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            metric == 'dutyHours'
                                ? statisticsHours(m.dutyHours)
                                : metric == 'contributionHours'
                                ? statisticsHours(value(m))
                                : '${value(m)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (metric != 'dutyHours' || m.dutyHours != null)
                        LinearProgressIndicator(
                          value: max > 0 ? (value(m) / max).toDouble() : 0,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(3),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (rows.length > 8)
            Text(
              'Näidatud 8 liiget ${rows.length}-st. Täielik võrdlus on jaotises „Liikmed”.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// The visible rows and file export share the same filtered dataset.
class StatisticsDataTable extends StatefulWidget {
  const StatisticsDataTable({super.key, required this.data, this.openRow});
  final StatisticsDataset data;
  final ValueChanged<int>? openRow;
  @override
  State<StatisticsDataTable> createState() => _StatisticsDataTableState();
}

class _StatisticsDataTableState extends State<StatisticsDataTable> {
  int _page = 0;
  static const _size = 15;
  @override
  void didUpdateWidget(covariant StatisticsDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Valitud tingimustele vastavaid andmeid ei ole.'),
      );
    }
    final start = _page * _size,
        end = (start + _size).clamp(0, data.rows.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, bounds) {
            if (bounds.maxWidth < 720 ||
                MediaQuery.textScalerOf(context).scale(16) > 25) {
              return Column(
                children: [
                  for (var i = start; i < end; i++)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: widget.openRow == null
                            ? null
                            : () => widget.openRow!(i),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data.cell(data.rows[i].first),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  if (widget.openRow != null)
                                    const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  for (var j = 1; j < data.columns.length; j++)
                                    Text(
                                      '${data.columns[j]}: ${data.cell(data.rows[i][j])}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 22,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 100,
                columns: [
                  for (final label in data.columns)
                    DataColumn(label: Text(label)),
                ],
                rows: [
                  for (var i = start; i < end; i++)
                    DataRow(
                      onSelectChanged: widget.openRow == null
                          ? null
                          : (_) => widget.openRow!(i),
                      cells: [
                        for (final value in data.rows[i])
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                data.cell(value),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${start + 1}–$end / ${data.rows.length} rida',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: 'Eelmine leht',
              onPressed: _page == 0 ? null : () => setState(() => _page--),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Järgmine leht',
              onPressed: end >= data.rows.length
                  ? null
                  : () => setState(() => _page++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
