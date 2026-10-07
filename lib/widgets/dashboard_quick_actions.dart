import 'primary_action_button.dart';
import 'package:flutter/material.dart';
import 'app_layout.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
    this.onCreateCallout,
    this.onCreateActivity,
  });
  final VoidCallback? onCreateCallout, onCreateActivity;
  @override
  Widget build(BuildContext context) {
    if (onCreateCallout == null && onCreateActivity == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(title: 'Kiirtegevused'),
        const SizedBox(height: 8),
        if (onCreateCallout != null)
          PrimaryActionButton(
            onPressed: onCreateCallout,
            icon: Icons.campaign_outlined,
            label: 'Loo väljakutse',
          ),
        if (onCreateActivity != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCreateActivity,
            icon: const Icon(Icons.event_available),
            label: const Text('Lisa tegevus / koolitus'),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
