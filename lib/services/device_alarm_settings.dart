import 'package:flutter/services.dart';

/// Device settings are deliberately separate from organization preferences.
class DeviceAlarmSettings {
  const DeviceAlarmSettings();
  static const channel = MethodChannel('respondcrew/notifications');

  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.from(
    await channel.invokeMapMethod<String, dynamic>('getSettings') ?? {},
  );

  Future<String?> open(String destination) =>
      channel.invokeMethod<String>(destination);
}
