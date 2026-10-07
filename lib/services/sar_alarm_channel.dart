import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Audio usage is immutable after an Android channel is first created.
/// v2 used the notification stream; v3 uses alarm volume. Keep any deliberate
/// mute, disabled channel, custom sound and vibration choices during migration.
const sarAlarmChannelId = 'sar_alarm_v3';
const sarAlarmChannelName = 'SAR-väljakutse häire';
// A named resource URI stays valid when Android reallocates numeric resource
// IDs on upgrade. Keep the resource explicitly in res/raw/keep.xml.
const sarAlarmSound = UriAndroidNotificationSound(
  'android.resource://com.example.respondcrew_app/raw/sar_alarm',
);

AndroidNotificationSound? _migratedSound(AndroidNotificationChannel? old) {
  final sound = old?.sound;
  if (old == null || sound is RawResourceAndroidNotificationSound) {
    return sarAlarmSound;
  }
  if (sound is UriAndroidNotificationSound &&
      sound.sound.startsWith(
        'android.resource://com.example.respondcrew_app/',
      )) {
    return sarAlarmSound;
  }
  return sound;
}

AndroidNotificationChannel? sarAlarmChannelToCreate(
  List<AndroidNotificationChannel> existing,
) {
  if (existing.any((channel) => channel.id == sarAlarmChannelId)) return null;
  final previous = existing.where((channel) => channel.id == 'sar_alarm_v2');
  final old = previous.isEmpty ? null : previous.first;
  return AndroidNotificationChannel(
    sarAlarmChannelId,
    sarAlarmChannelName,
    description: 'SAR-häire kasutab telefoni alarmi helitugevust',
    importance: old?.importance ?? Importance.max,
    playSound: old?.playSound ?? true,
    sound: _migratedSound(old),
    enableVibration: old?.enableVibration ?? true,
    vibrationPattern: old?.vibrationPattern,
    bypassDnd: old?.bypassDnd ?? false,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
}

Future<void> ensureSarAlarmChannel(
  AndroidFlutterLocalNotificationsPlugin android,
) async {
  final channel = sarAlarmChannelToCreate(
    await android.getNotificationChannels() ?? [],
  );
  if (channel != null) await android.createNotificationChannel(channel);
}
