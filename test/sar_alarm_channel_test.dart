import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/services/sar_alarm_channel.dart';

void main() {
  test('fresh SAR installation uses alarm audio and explicit DND consent', () {
    final channel = sarAlarmChannelToCreate([])!;
    expect(channel.id, sarAlarmChannelId);
    expect(channel.audioAttributesUsage, AudioAttributesUsage.alarm);
    expect(channel.sound, sarAlarmSound);
    expect(channel.importance, Importance.max);
    expect(channel.playSound, isTrue);
    expect(channel.bypassDnd, isFalse);
  });

  test(
    'migration replaces stale app resource IDs with a stable named sound URI',
    () {
      final channel = sarAlarmChannelToCreate([
        const AndroidNotificationChannel(
          'sar_alarm_v2',
          'Old SAR',
          sound: UriAndroidNotificationSound(
            'android.resource://com.example.respondcrew_app/2131755008',
          ),
        ),
      ])!;
      expect(channel.sound, sarAlarmSound);
      expect(
        (channel.sound as UriAndroidNotificationSound).sound,
        endsWith('/raw/sar_alarm'),
      );
    },
  );

  test(
    'migration changes immutable audio usage and preserves custom choices',
    () {
      const sound = UriAndroidNotificationSound('content://user/sound');
      final channel = sarAlarmChannelToCreate([
        const AndroidNotificationChannel(
          'sar_alarm_v2',
          'Old SAR',
          sound: sound,
          importance: Importance.high,
          bypassDnd: true,
          enableVibration: false,
        ),
        const AndroidNotificationChannel('tross_callouts', 'Tross'),
      ])!;
      expect(channel.id, isNot('sar_alarm_v2'));
      expect(channel.audioAttributesUsage, AudioAttributesUsage.alarm);
      expect(channel.sound, sound);
      expect(channel.importance, Importance.high);
      expect(channel.bypassDnd, isTrue);
      expect(channel.enableVibration, isFalse);
    },
  );

  test('migration never re-enables blocked, silent or low-priority SAR', () {
    for (final importance in [
      Importance.none,
      Importance.low,
      Importance.high,
    ]) {
      final channel = sarAlarmChannelToCreate([
        AndroidNotificationChannel(
          'sar_alarm_v2',
          'Old SAR',
          importance: importance,
          playSound: false,
          enableVibration: false,
        ),
      ])!;
      expect(channel.importance, importance);
      expect(channel.playSound, isFalse);
      expect(channel.sound, isNull);
      expect(channel.enableVibration, isFalse);
    }
  });

  test(
    'an existing v3 channel is never recreated or reset on resume/background delivery',
    () {
      expect(
        sarAlarmChannelToCreate([
          const AndroidNotificationChannel(
            sarAlarmChannelId,
            'SAR',
            importance: Importance.none,
            playSound: false,
          ),
          const AndroidNotificationChannel('sar_alarm_v2', 'Old SAR'),
        ]),
        isNull,
      );
    },
  );
}
