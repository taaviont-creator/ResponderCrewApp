/// Stable across isolates, so a redelivered push updates its existing alert.
/// Different callouts also need different PendingIntent IDs for exact routing.
int calloutNotificationId(String organizationId, String calloutId) {
  var hash = 0x811c9dc5;
  for (final unit in '$organizationId/$calloutId'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x0fffffff;
  }
  return hash | 0x10000000;
}

bool isNativeSarDelivery(Map<String, dynamic> data) =>
    data['delivery'] == 'native_sar_v1' &&
    data['calloutType'] == 'sar' &&
    data['organizationId'] is String &&
    (data['organizationId'] as String).isNotEmpty &&
    data['calloutId'] is String &&
    (data['calloutId'] as String).isNotEmpty;
