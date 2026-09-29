import '../models/information_notification_open.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../models/member_request_notification.dart';
import '../models/certificate_reminder_open.dart';
import 'device_token_service.dart';

const _calloutAlarmChannel = AndroidNotificationChannel(
  'sar_alarm_v2',
  'SAR-väljakutse häire',
  description: 'Kiire reageerimist vajav SAR-väljakutse',
  sound: RawResourceAndroidNotificationSound('sar_alarm'),
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const _memberRequestChannel = AndroidNotificationChannel(
  'member_requests', 'Liitumistaotlused',
  description: 'Admini kinnitust ootavad liikmed',
  importance: Importance.defaultImportance,
);

class CalloutNotificationOpenEvent {
  const CalloutNotificationOpenEvent({
    required this.organizationId,
    required this.calloutId,
  });

  final String organizationId;
  final String calloutId;

  bool get isValid => organizationId.isNotEmpty && calloutId.isNotEmpty;

  String toPayload() {
    return jsonEncode({
      'organizationId': organizationId,
      'calloutId': calloutId,
    });
  }

  static CalloutNotificationOpenEvent? fromData(
    Map<String, dynamic> data,
  ) {
    if (data['type'] != null && !{'callout', 'callout_alarm', 'tross_callout'}.contains(data['type'])) return null;
    final organizationId =
        (data['organizationId'] ?? data['commandId'] ?? '').toString().trim();
    final calloutId =
        (data['calloutId'] ?? data['relatedId'] ?? '').toString().trim();

    final event = CalloutNotificationOpenEvent(
      organizationId: organizationId,
      calloutId: calloutId,
    );
    return event.isValid ? event : null;
  }

  static CalloutNotificationOpenEvent? fromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return fromData(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

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

class CalloutAlarmNotificationService with WidgetsBindingObserver {
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
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  final _calloutOpenController =
      StreamController<CalloutNotificationOpenEvent>.broadcast();
  CalloutNotificationOpenEvent? _pendingCalloutOpenEvent;

  final _informationController = StreamController<InformationNotificationOpen>.broadcast();
  InformationNotificationOpen? _pendingInformation;
  Stream<InformationNotificationOpen> get informationOpenEvents => _informationController.stream;
  InformationNotificationOpen? takePendingInformation() { final event = _pendingInformation; _pendingInformation = null; return event; }
  void _emitInformation(InformationNotificationOpen event) {
    if (_informationController.hasListener) { _informationController.add(event); } else { _pendingInformation = event; }
  }

  final _memberRequestController = StreamController<MemberRequestNotification>.broadcast();
  MemberRequestNotification? _pendingMemberRequest;
  Stream<MemberRequestNotification> get memberRequestOpenEvents => _memberRequestController.stream;
  MemberRequestNotification? takePendingMemberRequest() {
    final event = _pendingMemberRequest;
    _pendingMemberRequest = null;
    return event;
  }

  final _certificateController = StreamController<CertificateReminderOpen>.broadcast();
  CertificateReminderOpen? _pendingCertificate;
  Stream<CertificateReminderOpen> get certificateOpenEvents => _certificateController.stream;
  CertificateReminderOpen? takePendingCertificate() {
    final event = _pendingCertificate; _pendingCertificate = null; return event;
  }
  void _emitCertificate(CertificateReminderOpen event) {
    if (_certificateController.hasListener) { _certificateController.add(event); } else { _pendingCertificate = event; }
  }
  bool _initialized = false;
  Future<void>? _initialization;

  Stream<CalloutNotificationOpenEvent> get calloutOpenEvents =>
      _calloutOpenController.stream;

  CalloutNotificationOpenEvent? takePendingCalloutOpenEvent() {
    final event = _pendingCalloutOpenEvent;
    _pendingCalloutOpenEvent = null;
    return event;
  }

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

  Future<void> initialize() {
    if (_initialized || !_supportsClientNotifications) {
      return Future<void>.value();
    }

    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _initializeLocalNotifications();
      await _requestNotificationPermissions();
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      _startDeviceTokenStorage();
      FirebaseMessaging.onMessage.listen(_showForegroundCalloutNotification);
      _messageOpenedSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedRemoteMessage);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedRemoteMessage(initialMessage);
      }

      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      _initialization = null;
      rethrow;
    }
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

  Future<bool> showLocalTestAlarmNotification() async {
    if (!_supportsClientNotifications) return false;

    if (!_initialized) {
      await initialize();
    }

    final settings = await _messaging.getNotificationSettings();
    final readiness = _readinessFromSettings(settings);
    if (!readiness.notificationsAllowed) return false;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sar_alarm_v2',
        'V\u00e4ljakutse alarm',
        channelDescription: 'Heliline alarm v\u00e4ljakutsete jaoks',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('sar_alarm'),
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
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Testteavitus',
      body: 'See on v\u00e4ljakutse alarmi test selles seadmes.',
      notificationDetails: details,
      payload: 'local_callout_alarm_test',
    );
    return true;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _auth.currentUser != null) {
      unawaited(_saveCurrentDeviceToken());
    }
  }

  Future<bool> _saveCurrentDeviceToken() async {
    try {
      return await _deviceTokenService.saveCurrentToken(_messaging);
    } catch (_) {}
    return false;
  }

  Future<bool> _saveDeviceToken(String token) async {
    try {
      return await _deviceTokenService.saveTokenForCurrentUser(token);
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

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_calloutAlarmChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_memberRequestChannel);
    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel('certificate_reminders', 'Tunnistuste aegumine', importance: Importance.defaultImportance));
    final android = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in const [
      AndroidNotificationChannel('tross_callouts','Trossi mereabi',importance:Importance.defaultImportance),
      AndroidNotificationChannel('readiness_changes','Ühingu reageerimisvalmiduse muutused',importance:Importance.defaultImportance),
      AndroidNotificationChannel('respondcrew_info','RespondCrew teated',importance:Importance.defaultImportance),
    ]) { await android?.createNotificationChannel(channel); }
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true && launch?.notificationResponse != null) {
      _handleLocalNotificationResponse(launch!.notificationResponse!);
    }
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
    if (InformationNotificationOpen.fromData(message.data) != null) {
      final readiness = message.data['type'] != 'platformApplication';
      await _localNotifications.show(id:message.hashCode,title:message.notification?.title,body:message.notification?.body,
        notificationDetails:NotificationDetails(android:AndroidNotificationDetails(readiness ? 'readiness_changes' : 'respondcrew_info',readiness ? 'Ühingu reageerimisvalmiduse muutused' : 'RespondCrew teated'),
          iOS:const DarwinNotificationDetails(presentAlert:true,presentSound:true)),payload:jsonEncode(message.data));
      return;
    }
    if (message.data['type'] == 'certificate_reminder') {
      await _localNotifications.show(id: message.hashCode, title: message.notification?.title, body: message.notification?.body,
        notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('certificate_reminders', 'Tunnistuste aegumine'),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)), payload: jsonEncode(message.data));
      return;
    }
    final memberRequest = MemberRequestNotification.fromData(message.data);
    if (memberRequest != null) {
      await _localNotifications.show(
        id: message.hashCode,
        title: 'Liitumistaotlus',
        body: message.notification?.body ?? 'Liige ootab sinu ühingus kinnitamist.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('member_requests', 'Liitumistaotlused'),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: memberRequest.toPayload(),
      );
      return;
    }
    if (!_isCalloutMessage(message)) return;

    final notification = message.notification;
    final title = notification?.title ?? 'Väljakutse';
    final body = notification?.body ?? 'Uus väljakutse';

    final tross = message.data['calloutType'] == 'tross';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        tross ? 'tross_callouts' : 'sar_alarm_v2',
        tross ? 'Trossi mereabi' : 'SAR-väljakutse häire',
        channelDescription: 'Heliline alarm väljakutsete jaoks',
        importance: tross ? Importance.defaultImportance : Importance.max,
        priority: tross ? Priority.defaultPriority : Priority.high,
        playSound: true,
        sound: tross ? null : const RawResourceAndroidNotificationSound('sar_alarm'),
        enableVibration: true,
        category: tross ? AndroidNotificationCategory.event : AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final openEvent =
        CalloutNotificationOpenEvent.fromData(message.data);

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: openEvent?.toPayload(),
    );
  }

  void _handleOpenedRemoteMessage(RemoteMessage message) {
    final information = InformationNotificationOpen.fromData(message.data);
    if (information != null) { _emitInformation(information); return; }
    final certificate = CertificateReminderOpen.fromData(message.data);
    if (certificate != null) { _emitCertificate(certificate); return; }
    final memberRequest = MemberRequestNotification.fromData(message.data);
    if (memberRequest != null) {
      _emitMemberRequest(memberRequest);
      return;
    }
    if (!_isCalloutMessage(message)) return;
    final event = CalloutNotificationOpenEvent.fromData(message.data);
    if (event != null) {
      _emitCalloutOpenEvent(event);
    }
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final information = InformationNotificationOpen.fromPayload(response.payload);
    if (information != null) { _emitInformation(information); return; }
    final certificate = CertificateReminderOpen.fromPayload(response.payload);
    if (certificate != null) { _emitCertificate(certificate); return; }
    final memberRequest = MemberRequestNotification.fromPayload(response.payload);
    if (memberRequest != null) {
      _emitMemberRequest(memberRequest);
      return;
    }
    final event =
        CalloutNotificationOpenEvent.fromPayload(response.payload);
    if (event != null) {
      _emitCalloutOpenEvent(event);
    }
  }

  void _emitCalloutOpenEvent(CalloutNotificationOpenEvent event) {
    if (_calloutOpenController.hasListener) {
      _calloutOpenController.add(event);
    } else {
      _pendingCalloutOpenEvent = event;
    }
  }

  void _emitMemberRequest(MemberRequestNotification event) {
    if (_memberRequestController.hasListener) {
      _memberRequestController.add(event);
    } else {
      _pendingMemberRequest = event;
    }
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
