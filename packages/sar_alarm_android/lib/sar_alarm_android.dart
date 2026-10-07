import 'package:flutter/services.dart';

/// Registered by Flutter in both the foreground and Firebase background engine.
class NativeSarAlarm {
  static const channel = MethodChannel('respondcrew/native_sar_alarm');

  static Future<bool> show({required int id, required String payload}) async =>
      await channel
          .invokeMethod<bool>('show', {'id': id, 'payload': payload}) ??
      false;

  static Future<bool> scheduleTest() async =>
      await channel.invokeMethod<bool>('scheduleTest') ?? false;

  static Future<void> cancelTest() => channel.invokeMethod<void>('cancelTest');
}
