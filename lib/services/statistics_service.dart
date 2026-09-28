import 'package:cloud_functions/cloud_functions.dart';
import '../models/statistics_model.dart';

class StatisticsService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-north1');
  Future<ContributionReport> load({
    required String organizationId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await _functions
        .httpsCallable(
          'getContributionStatistics',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
        )
        .call({
          'organizationId': organizationId,
          'from': statisticsDate(from),
          'to': statisticsDate(to),
        });
    return ContributionReport(statisticsMap(result.data));
  }

  Future<void> record(Map<String, dynamic> data) async {
    await _functions.httpsCallable('recordMemberContribution').call(data);
  }

  Future<void> saveAttendance(Map<String, dynamic> data) async {
    await _functions.httpsCallable('saveCalloutAttendance').call(data);
  }
}
