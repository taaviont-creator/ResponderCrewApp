import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ResponseUnitService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-north1');
  String newId() =>
      FirebaseFirestore.instance.collection('responseUnits').doc().id;
  Future<Map<String, dynamic>> load(String organizationId) async {
    final result = await _functions.httpsCallable('getOrganizationUnits').call({
      'organizationId': organizationId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> save(String method, Map<String, dynamic> data) async {
    await _functions.httpsCallable(method).call(data);
  }

  static List<Map<String, dynamic>> rows(dynamic value) =>
      (value as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
}
