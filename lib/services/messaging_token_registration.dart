/// APNs registration can finish after the iOS notification prompt closes.
/// Never request an FCM token before APNs has supplied its token.
Future<String?> messagingTokenWhenReady({
  required bool requiresApns,
  required Future<String?> Function() getApnsToken,
  required Future<String?> Function() getFcmToken,
  Future<void> Function(Duration)? wait,
  int attempts = 20,
}) async {
  if (requiresApns) {
    final pause = wait ?? Future<void>.delayed;
    var ready = false;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final token = await getApnsToken();
      if (token != null && token.isNotEmpty) {
        ready = true;
        break;
      }
      if (attempt + 1 < attempts) {
        await pause(const Duration(milliseconds: 500));
      }
    }
    if (!ready) return null;
  }
  return getFcmToken();
}
