import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'device_token_service.dart';

const _calloutAlarmChannel = AndroidNotificationChannel(
  'callout_alarm',
  'Väljakutse alarm',
  description: 'Heliline alarm väljakutsete jaoks',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

class CalloutAlarmNotificationReadiness {
  const CalloutAlarmNotificationReadiness({
    required this.supportsClientNotifications,
    required this.notificationsAllowed,
    required this.canRequestPermission,
    required this.permissionStatus,
    required this.tokenRegistrationAttempted,
    required this.tokenRegistrationSucceeded,
  });

  final bool supportsClientNotifications;
  final bool notificationsAllowed;
  final bool canRequestPermission;
  final String permissionStatus;
  final bool tokenRegistrationAttempted;
  final bool tokenRegistrationSucceeded;
}

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceTokenService _deviceTokenService = DeviceTokenService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

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

    _startDeviceTokenStorage();
    FirebaseMessaging.onMessage.listen(_showForegroundCalloutNotification);
  }

  Future<CalloutAlarmNotificationReadiness> getNotificationReadiness() async {
    if (!_supportsClientNotifications) {
      return const CalloutAlarmNotificationReadiness(
        supportsClientNotifications: false,
        notificationsAllowed: false,
        canRequestPermission: false,
        permissionStatus: 'unsupported',
        tokenRegistrationAttempted: false,
        tokenRegistrationSucceeded: false,
      );
    }

    final settings = await _messaging.getNotificationSettings();
    return _readinessFromSettings(settings);
  }

  Future<CalloutAlarmNotificationReadiness>
      requestPermissionAndRefreshRegistration() async {
    if (!_supportsClientNotifications) {
      return getNotificationReadiness();
    }

    if (!_initialized) {
      await initialize();
    } else {
      await _requestNotificationPermissions();
    }

    final tokenRegistered = await _saveCurrentDeviceToken();
    final settings = await _messaging.getNotificationSettings();
    return _readinessFromSettings(
      settings,
      tokenRegistrationAttempted: true,
      tokenRegistrationSucceeded: tokenRegistered,
    );
  }

  void _startDeviceTokenStorage() {
    _authSubscription ??= _auth.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(_saveCurrentDeviceToken());
    });

    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      unawaited(_saveDeviceToken(token));
    });

    if (_auth.currentUser != null) {
      unawaited(_saveCurrentDeviceToken());
    }
  }

  Future<bool> _saveCurrentDeviceToken() async {
    try {
      return _deviceTokenService.saveCurrentToken(_messaging);
    } catch (_) {}
    return false;
  }

  Future<bool> _saveDeviceToken(String token) async {
    try {
      return _deviceTokenService.saveTokenForCurrentUser(token);
    } catch (_) {}
    return false;
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

  CalloutAlarmNotificationReadiness _readinessFromSettings(
    NotificationSettings settings, {
    bool tokenRegistrationAttempted = false,
    bool tokenRegistrationSucceeded = false,
  }) {
    final status = settings.authorizationStatus;
    final notificationsAllowed = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    return CalloutAlarmNotificationReadiness(
      supportsClientNotifications: true,
      notificationsAllowed: notificationsAllowed,
      canRequestPermission: status == AuthorizationStatus.notDetermined,
      permissionStatus: _permissionStatusCode(status),
      tokenRegistrationAttempted: tokenRegistrationAttempted,
      tokenRegistrationSucceeded: tokenRegistrationSucceeded,
    );
  }

  String _permissionStatusCode(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'authorized';
      case AuthorizationStatus.denied:
        return 'denied';
      case AuthorizationStatus.notDetermined:
        return 'notDetermined';
      case AuthorizationStatus.provisional:
        return 'provisional';
    }
  }
}
