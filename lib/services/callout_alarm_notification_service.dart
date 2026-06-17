import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

const _calloutAlarmChannel = AndroidNotificationChannel(
  'callout_alarm',
  'Väljakutse alarm',
  description: 'Heliline alarm väljakutsete jaoks',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

@pragma('vm:entry-point')
Future<void> calloutAlarmMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class CalloutAlarmNotificationService {
  CalloutAlarmNotificationService._();

  static final CalloutAlarmNotificationService instance =
      CalloutAlarmNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get _supportsClientNotifications {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(
      calloutAlarmMessagingBackgroundHandler,
    );
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsClientNotifications) return;
    _initialized = true;

    await _initializeLocalNotifications();
    await _requestNotificationPermissions();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundCalloutNotification);
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(settings: initializationSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_calloutAlarmChannel);
  }

  Future<void> _requestNotificationPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> _showForegroundCalloutNotification(
    RemoteMessage message,
  ) async {
    if (!_isCalloutMessage(message)) return;

    final notification = message.notification;
    final title = notification?.title ?? 'Väljakutse';
    final body = notification?.body ?? 'Uus väljakutse';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'callout_alarm',
        'Väljakutse alarm',
        channelDescription: 'Heliline alarm väljakutsete jaoks',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: message.data['calloutId'] ?? message.data['relatedId'],
    );
  }

  bool _isCalloutMessage(RemoteMessage message) {
    final data = message.data;
    return data['type'] == 'callout' ||
        data['relatedType'] == 'callout' ||
        data['channelId'] == _calloutAlarmChannel.id;
  }
}
