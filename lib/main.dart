import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'navigation/app_router.dart';
import 'navigation/url_strategy.dart';
import 'services/callout_alarm_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _router = AppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RespondCrew',
      locale: const Locale('et'),
      supportedLocales: const [Locale('et')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.maritime,
      routerDelegate: _router,
      routeInformationParser: const AppRouteParser(),
    );
  }
}
