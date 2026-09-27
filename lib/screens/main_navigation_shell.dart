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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Semantics(
                      selected: currentIndex == i,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, 64),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
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
                            Text(labels[i]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
