import 'package:cloud_functions/cloud_functions.dart';

class MemberContactService {
  Future<Uri?> contactUri({
    required String organizationId,
    required String userId,
    required bool sms,
  }) async {
    final result = await FirebaseFunctions.instanceFor(region: 'europe-north1')
        .httpsCallable('getOrganizationMemberContact')
        .call<Map<String, dynamic>>({
          'organizationId': organizationId,
          'userId': userId,
        });
    return phoneContactUri(result.data['phone'], sms: sms);
  }
}

Uri? phoneContactUri(Object? value, {required bool sms}) {
  if (value is! String) return null;
  final phone = value.replaceAll(RegExp(r'[\s()\-]'), '');
  if (!RegExp(r'^\+?[0-9]{3,20}$').hasMatch(phone)) return null;
  return Uri(scheme: sms ? 'sms' : 'tel', path: phone);
}
