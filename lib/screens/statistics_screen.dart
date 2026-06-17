import 'package:flutter/material.dart';

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
          child: Text('Sul puudub õigus seda toimingut teha'),
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
            return Center(
              child: Text(
                'Statistika laadimine ebaõnnestus: ${snapshot.error}',
              ),
            );
          }

          final statistics = snapshot.data;
          if (statistics == null) {
            return const Center(child: Text('Statistikat ei leitud'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
}
