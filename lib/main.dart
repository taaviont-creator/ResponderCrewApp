import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/auth_gate.dart';
import 'firebase_options.dart';
import 'services/callout_alarm_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CalloutAlarmNotificationService.registerBackgroundHandler();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
  unawaited(_initializeCalloutAlarmNotifications());
}

Future<void> _initializeCalloutAlarmNotifications() async {
  try {
    await CalloutAlarmNotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Callout notification initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RespondCrew',
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
