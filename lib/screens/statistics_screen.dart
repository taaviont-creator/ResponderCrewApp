import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/statistics_model.dart';
import '../services/statistics_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.canViewStatistics,
    required this.canViewOrganizationCertificates,
  });

  final String organizationId;
  final String currentUid;
  final bool canViewStatistics;
  final bool canViewOrganizationCertificates;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _statisticsService = StatisticsService();
  Future<StatisticsSummary>? _statisticsFuture;

  @override
  void initState() {
    super.initState();
    if (widget.canViewStatistics) {
      _statisticsFuture = _loadStatistics();
    }
  }

  Future<StatisticsSummary> _loadStatistics() {
    return _statisticsService.loadOrganizationStatistics(
      organizationId: widget.organizationId,
      currentUid: widget.currentUid,
      canViewOrganizationCertificates: widget.canViewOrganizationCertificates,
    );
  }

  void _refreshStatistics() {
    if (!widget.canViewStatistics) return;
    setState(() {
      _statisticsFuture = _loadStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canViewStatistics) {
      return const Scaffold(
        body: Center(
          child: Text('Sul puudub õigus seda toimingut teha.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistika'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Värskenda',
            onPressed: _refreshStatistics,
          ),
        ],
      ),
      body: FutureBuilder<StatisticsSummary>(
        future: _statisticsFuture!,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Statistika laadimine ebaõnnestus.'),
            );
          }

          final statistics = snapshot.data;
          if (statistics == null) {
            return const Center(child: Text('Statistikat ei leitud.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (statistics.hasConfirmedParticipationStatistics) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Kopeeri CSV'),
                    onPressed: () => _copyStatisticsCsv(statistics),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _buildStatisticTile('Liikmeid', statistics.memberCount),
              _buildStatisticTile('Valves', statistics.onDutyCount),
              _buildStatisticTile('Hilinenud', statistics.delayedCount),
              _buildStatisticTile('Valvest väljas', statistics.offDutyCount),
              const Divider(),
              _buildStatisticTile('Varustust kokku', statistics.equipmentCount),
              _buildStatisticTile(
                'Vajab hooldust',
                statistics.equipmentNeedsMaintenanceCount,
              ),
              _buildStatisticTile(
                'Katki / kasutusest väljas',
                statistics.equipmentUnavailableCount,
              ),
              const Divider(),
              _buildStatisticTile(
                'Operatsioonilogi kandeid',
                statistics.operationLogCount,
              ),
              _buildStatisticTile(
                'Tegevusi/koolitusi kokku',
                statistics.upcomingActivityCount,
              ),
              if (statistics.hasConfirmedParticipationStatistics) ...[
                const Divider(),
                _buildStatisticTile(
                  'Kinnitatud osalemisi',
                  statistics.confirmedParticipationCount!,
                ),
                _buildStatisticTextTile(
                  'Kinnitatud tunnid',
                  _formatHours(statistics.confirmedParticipationHours!),
                ),
                if (statistics.hasMemberContributionStatistics)
                  _buildMemberContributionSection(
                    statistics.memberContributions!,
                  ),
              ],
              const Divider(),
              _buildStatisticTile(
                widget.canViewOrganizationCertificates
                    ? 'Kehtivaid kvalifikatsioone'
                    : 'Minu kehtivaid kvalifikatsioone',
                statistics.validCertificateCount,
              ),
              _buildStatisticTile(
                widget.canViewOrganizationCertificates
                    ? 'Aegunud kvalifikatsioone'
                    : 'Minu aegunud kvalifikatsioone',
                statistics.expiredCertificateCount,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copyStatisticsCsv(StatisticsSummary statistics) async {
    await Clipboard.setData(
      ClipboardData(text: _buildStatisticsCsv(statistics)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV kopeeritud lõikelauale.')),
    );
  }

  String _buildStatisticsCsv(StatisticsSummary statistics) {
    final rows = <List<String>>[
      const ['Jaotis', 'Näitaja', 'Väärtus'],
      ['Koond', 'Liikmeid', statistics.memberCount.toString()],
      ['Koond', 'Valves', statistics.onDutyCount.toString()],
      ['Koond', 'Hilinenud', statistics.delayedCount.toString()],
      ['Koond', 'Valvest väljas', statistics.offDutyCount.toString()],
      ['Varustus', 'Varustust kokku', statistics.equipmentCount.toString()],
      [
        'Varustus',
        'Vajab hooldust',
        statistics.equipmentNeedsMaintenanceCount.toString(),
      ],
      [
        'Varustus',
        'Katki / kasutusest väljas',
        statistics.equipmentUnavailableCount.toString(),
      ],
      [
        'Tegevused',
        'Operatsioonilogi kandeid',
        statistics.operationLogCount.toString(),
      ],
      [
        'Tegevused',
        'Tegevusi/koolitusi kokku',
        statistics.upcomingActivityCount.toString(),
      ],
    ];

    if (statistics.hasConfirmedParticipationStatistics) {
      rows.addAll([
        [
          'Osalemine',
          'Kinnitatud osalemisi',
          statistics.confirmedParticipationCount!.toString(),
        ],
        [
          'Osalemine',
          'Kinnitatud tunnid',
          _formatHours(statistics.confirmedParticipationHours!),
        ],
      ]);
    }

    rows.addAll([
      [
        'Kvalifikatsioonid',
        widget.canViewOrganizationCertificates
            ? 'Kehtivaid kvalifikatsioone'
            : 'Minu kehtivaid kvalifikatsioone',
        statistics.validCertificateCount.toString(),
      ],
      [
        'Kvalifikatsioonid',
        widget.canViewOrganizationCertificates
            ? 'Aegunud kvalifikatsioone'
            : 'Minu aegunud kvalifikatsioone',
        statistics.expiredCertificateCount.toString(),
      ],
    ]);

    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(_csvLine(row));
    }

    final contributions = statistics.memberContributions;
    if (contributions != null) {
      buffer
        ..writeln()
        ..writeln(_csvLine(const ['Liikmete panus']))
        ..writeln(
          _csvLine(
            const ['Liige', 'Kinnitatud osalemisi', 'Kinnitatud tunnid'],
          ),
        );
      for (final contribution in contributions) {
        buffer.writeln(
          _csvLine([
            contribution.displayName,
            contribution.confirmedParticipationCount.toString(),
            _formatHours(contribution.confirmedParticipationHours),
          ]),
        );
      }
    }

    return buffer.toString();
  }

  String _csvLine(List<String> cells) => cells.map(_csvCell).join(';');

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(';') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _formatHours(double hours) {
    var formatted = hours.toStringAsFixed(2);
    if (formatted.endsWith('00')) {
      formatted = hours.toStringAsFixed(0);
    } else if (formatted.endsWith('0')) {
      formatted = hours.toStringAsFixed(1);
    }
    return formatted.replaceAll('.', ',');
  }

  Widget _buildMemberContributionSection(
    List<MemberContributionSummary> contributions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Liikmete panus',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (contributions.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Kinnitatud osalemisi ei ole veel.'),
          )
        else
          ...contributions.map(_buildMemberContributionTile),
      ],
    );
  }

  Widget _buildStatisticTile(String label, int value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value.toString(),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildStatisticTextTile(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildMemberContributionTile(MemberContributionSummary contribution) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(contribution.displayName),
      subtitle: Text(
        'Kinnitatud osalemisi: '
        '${contribution.confirmedParticipationCount}',
      ),
      trailing: Text(
        _formatHours(contribution.confirmedParticipationHours),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
