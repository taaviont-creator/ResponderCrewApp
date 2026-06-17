import 'package:flutter/services.dart';

class WakelockService {
  static const _channel = MethodChannel('respondcrew/wakelock');

  Future<void> toggle({required bool enable}) async {
    try {
      await _channel.invokeMethod<void>('toggle', {'enable': enable});
    } on MissingPluginException {
      // Wakelock is currently implemented only by the Android host app.
    } on PlatformException {
      // Keep wakelock failures non-blocking for operation log workflows.
    }
  }

  Future<void> disable() => toggle(enable: false);
}
