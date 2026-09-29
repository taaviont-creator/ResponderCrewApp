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
    return Scaffold(
      body: NavigatorPopHandler<Object?>(
        onPopWithResult: (result) => _navigatorKey.currentState!.pop(result),
        child: Navigator(
          key: _navigatorKey,
          pages: [
            MaterialPage<void>(
              key: ValueKey(widget.currentIndex),
              child: widget.child,
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
      bottomNavigationBar: Material(
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
                      onPressed: () {
                        _navigatorKey.currentState?.popUntil(
                          (route) => route.isFirst,
                        );
                        widget.onDestinationSelected(i);
                      },
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
