import 'package:flutter/services.dart';

class WakelockService {
  static const _channel = MethodChannel('respondcrew/wakelock');

  Future<void> toggle({required bool enable}) async {
    try {
      await _channel.invokeMethod<void>('toggle', {'enable': enable});
    } on MissingPluginException {
      // Other hosts may not implement the Android/iOS wakelock channel.
    } on PlatformException {
      // Keep wakelock failures non-blocking for operation log workflows.
    }
  }

  Future<void> disable() => toggle(enable: false);
}
