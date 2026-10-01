import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
    this.navigatorKey,
  });
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final _routeObserver = _ShellRouteObserver();
  bool _switching = false;

  Future<void> _select(int index) async {
    if (_switching) return;
    _switching = true;
    try {
      final navigator = _navigatorKey.currentState;
      while (navigator != null && navigator.canPop()) {
        final revision = _routeObserver.revision;
        await navigator.maybePop();
        // A form may veto the pop and show its own unsaved-changes dialog.
        // Never force-remove that route (and its unsaved edits).
        if (!mounted || revision == _routeObserver.revision) return;
      }
      if (mounted) widget.onDestinationSelected(index);
    } finally {
      _switching = false;
    }
  }

  final _localNavigatorKey = GlobalKey<NavigatorState>();
  GlobalKey<NavigatorState> get _navigatorKey =>
      widget.navigatorKey ?? _localNavigatorKey;

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Töölaud',
      'Väljakutsed',
      'Valmisolek',
      'Ühingu valmidus',
      'Menüü',
    ];
    const icons = [
      Icons.dashboard_outlined,
      Icons.campaign_outlined,
      Icons.health_and_safety_outlined,
      Icons.groups_outlined,
      Icons.menu,
    ];
    final wide =
        MediaQuery.sizeOf(context).width >= 1000 &&
        MediaQuery.textScalerOf(context).scale(16) < 24;
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            SafeArea(
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 220,
                selectedIndex: widget.currentIndex,
                onDestinationSelected: _select,
                leading: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'RespondCrew',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                ],
              ),
            ),
          Expanded(
            key: const ValueKey('page'),
            child: NavigatorPopHandler<Object?>(
              onPopWithResult: (result) =>
                  _navigatorKey.currentState!.maybePop(result),
              child: Navigator(
                key: _navigatorKey,
                observers: [_routeObserver],
                pages: [
                  MaterialPage<void>(
                    key: ValueKey(widget.currentIndex),
                    child: widget.child,
                  ),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : Material(
              color: AppColors.surface,
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: widget.currentIndex == i,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 64),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 10,
                              ),
                              backgroundColor: widget.currentIndex == i
                                  ? AppColors.surfaceBlueStrong
                                  : null,
                            ),
                            onPressed: () => _select(i),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icons[i]),
                                const SizedBox(height: 4),
                                Text(
                                  labels[i],
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ShellRouteObserver extends NavigatorObserver {
  int revision = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    revision++;
  }
}
