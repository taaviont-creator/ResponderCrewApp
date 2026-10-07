import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/statistics_chart_data.dart';
import '../models/statistics_model.dart';

/// Native, labelled charts: no external chart service or duplicated storage.
class StatisticsCharts extends StatelessWidget {
  const StatisticsCharts({super.key, required this.members, this.events});
  final List<MemberContribution> members;
  final Map<String, dynamic>? events;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contribution = _ContributionChart(
        data: ContributionBreakdown.fromMembers(members),
      );
      if (events == null) return contribution;
      final callouts = _CalloutChart(data: CalloutBreakdown(events!));
      if (constraints.maxWidth >= 760 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: contribution),
            const SizedBox(width: 16),
            Expanded(child: callouts),
          ],
        );
      }
      return Column(
        children: [contribution, const SizedBox(height: 12), callouts],
      );
    },
  );
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.description,
    required this.children,
  });
  final String title, description;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _ContributionChart extends StatelessWidget {
  const _ContributionChart({required this.data});
  final ContributionBreakdown data;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ChartPanel(
      title: 'Panuse jaotus',
      description:
          'Kinnitatud osalemiste tunnid tegevuste kaupa. Valveaeg on eraldi.',
      children: [
        if (data.rows.isEmpty)
          const Text('Sellel perioodil pole veel kinnitatud panuseid.'),
        for (final row in data.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Semantics(
                container: true,
              label:
                  '${row.label}: ${row.knownHoursCount == 0 ? 'tunnid märkimata' : statisticsHours(row.hours)}, ${row.count} osalemist${row.unknownHoursCount > 0 ? ', ${row.unknownHoursCount} osalemisel tunnid puudu' : ''}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text(
                        row.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        row.knownHoursCount == 0
                            ? 'Tunnid märkimata'
                            : statisticsHours(row.hours),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  if (row.knownHoursCount > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 10,
                        child: ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              heightFactor: 1,
                              widthFactor: data.hours > 0
                                  ? row.hours / data.hours
                                  : 0,
                              child: ColoredBox(
                                key: ValueKey(
                                  'contribution-bar-${row.category}',
                                ),
                                color: row.category == 'callout'
                                    ? colors.tertiary
                                    : colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${row.count} osalemist${row.unknownHoursCount > 0 ? ' · ${row.unknownHoursCount} korral tunnid puudu' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        if (data.unknownHoursCount > 0)
          const Text(
            'Puuduvad tunnid ei ole diagrammis arvestatud nullpanusena.',
          ),
      ],
    );
  }
}

class _CalloutChart extends StatelessWidget {
  const _CalloutChart({required this.data});
  final CalloutBreakdown data;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = [colors.primary, colors.secondary, colors.outline];
    final slices = data.slices.entries.toList();
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette[i],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const SizedBox(width: 12, height: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('${slices[i].key}: ${slices[i].value}')),
              ],
            ),
          ),
      ],
    );
    return _ChartPanel(
      title: 'Väljakutsed perioodil',
      description:
          'Väljakutsete arv, mitte osalemiste arv. Testväljakutsed on välja jäetud.',
      children: [
        if (!data.hasDistribution)
          const Text('Väljakutsete jaotus pole saadaval.')
        else if (data.count('period') == 0)
          const Text('Sellel perioodil väljakutseid ei olnud.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final ring = Semantics(
              container: true,
                label: '${data.count('period')} väljakutset valitud perioodil',
                excludeSemantics: true,
                child: SizedBox(
                  width: 136,
                  height: 136,
                  child: CustomPaint(
                    painter: _RingPainter(
                      slices.map((s) => s.value).toList(),
                      palette,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(26),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${data.count('period')}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (constraints.maxWidth >= 340 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 24) {
                return Row(
                  children: [
                    ring,
                    const SizedBox(width: 20),
                    Expanded(child: legend),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ring),
                  const SizedBox(height: 12),
                  legend,
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Lõpetatud: ${data.count('closed') ?? '—'}'),
            Text('Tühistatud: ${data.count('cancelled') ?? '—'}'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Kõikidel perioodidel kokku: ${data.count('total') ?? '—'}. Jaotus sisaldab ka tühistatud väljakutseid.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.values, this.colors);
  final List<int> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    final rect = (Offset.zero & size).deflate(10);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}
