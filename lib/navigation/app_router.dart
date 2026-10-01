import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../auth/auth_gate.dart';
import '../screens/app_context_screen.dart';

class AppRouteParser extends RouteInformationParser<String> {
  const AppRouteParser();
  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(
        routeInformation.uri.path.isEmpty ? '/' : routeInformation.uri.path,
      );
  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri(path: configuration));
}

class AppRouter extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  String _path = '/';
  @override
  String get currentConfiguration => _path;
  void navigate(String path) {
    _path = path;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    _path = configuration;
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      MaterialPage<void>(
        key: const ValueKey('authenticated-app'),
        child: ['/', '/uhingud', '/keskus/sar', '/keskus/tross'].contains(_path)
            ? AuthGate(
                signedInBuilder: (context, user) => AppContextScreen(
                  key: ValueKey(user.uid),
                  userId: user.uid,
                  path: _path,
                  navigate: navigate,
                ),
              )
            : Scaffold(
                appBar: AppBar(title: const Text('Lehte ei leitud')),
                body: Center(
                  child: TextButton(
                    onPressed: () => navigate('/'),
                    child: const Text('Avalehele'),
                  ),
                ),
              ),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}
