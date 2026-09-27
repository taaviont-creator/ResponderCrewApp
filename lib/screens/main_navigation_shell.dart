import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    const labels = ['Töölaud', 'Väljakutsed', 'Liikmed', 'Varustus', 'Veel'];
    const icons = [
      Icons.dashboard_outlined,
      Icons.campaign_outlined,
      Icons.groups_outlined,
      Icons.inventory_2_outlined,
      Icons.menu,
    ];
    return Scaffold(
      body: child,
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
                    selected: currentIndex == i,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 64),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 10,
                        ),
                        backgroundColor: currentIndex == i
                            ? AppColors.surfaceBlueStrong
                            : null,
                      ),
                      onPressed: () => onDestinationSelected(i),
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
