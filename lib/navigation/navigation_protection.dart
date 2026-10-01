import 'package:flutter/material.dart';

/// Guards intentional navigation; authentication/permission revocation still wins.
class NavigationProtection {
  static final Set<Future<bool> Function()> _guards = {};
  static bool _checking = false;
  static Future<bool> confirm() async {
    if (_checking) return false;
    _checking = true;
    try {
      for (final guard in _guards.toList().reversed) {
        if (_guards.contains(guard) && !await guard()) return false;
      }
      return true;
    } finally {
      _checking = false;
    }
  }
}

class NavigationLeaveGuard extends StatefulWidget {
  const NavigationLeaveGuard({
    super.key,
    required this.confirmLeave,
    required this.child,
  });
  final Future<bool> Function() confirmLeave;
  final Widget child;
  @override
  State<NavigationLeaveGuard> createState() => _NavigationLeaveGuardState();
}

class _NavigationLeaveGuardState extends State<NavigationLeaveGuard> {
  Future<bool> _guard() => mounted ? widget.confirmLeave() : Future.value(true);
  @override
  void initState() {
    super.initState();
    NavigationProtection._guards.add(_guard);
  }

  @override
  void dispose() {
    NavigationProtection._guards.remove(_guard);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
