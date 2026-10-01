import 'package:cloud_functions/cloud_functions.dart';

class OrganizationMapLocationService {
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-north1');

  Future<Map<String, dynamic>> load(String organizationId) async {
    final result = await _functions
        .httpsCallable('getOrganizationMapLocation')
        .call({'organizationId': organizationId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> save(
    String organizationId,
    int revision,
    Map<String, dynamic> location,
  ) async {
    await _functions.httpsCallable('saveOrganizationMapLocation').call({
      ...location,
      'organizationId': organizationId,
      'expectedRevision': revision,
    });
  }
}
