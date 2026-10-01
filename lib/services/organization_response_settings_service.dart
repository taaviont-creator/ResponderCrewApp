import 'package:cloud_functions/cloud_functions.dart';

class OrganizationResponseSettingsService {
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-north1');

  Future<Map<String, dynamic>> load(String organizationId) async {
    final result = await _functions
        .httpsCallable('getOrganizationResponseSettings')
        .call({'organizationId': organizationId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<int> save(
    String organizationId,
    int revision,
    Map<String, dynamic> value,
  ) async {
    final result = await _functions
        .httpsCallable('saveOrganizationResponseSettings')
        .call({
          ...value,
          'organizationId': organizationId,
          'expectedRevision': revision,
        });
    return (result.data['revision'] as num).toInt();
  }
}
