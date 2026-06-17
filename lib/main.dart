import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth/auth_gate.dart';
import 'services/callout_alarm_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CalloutAlarmNotificationService.registerBackgroundHandler();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CalloutAlarmNotificationService.instance.initialize();
  runApp(const MyApp());
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
