import 'package:flutter/material.dart';
import 'status_badge.dart';

class EquipmentItemCard extends StatelessWidget {
  const EquipmentItemCard({
    super.key,
    required this.name,
    required this.description,
    required this.statusLabel,
    required this.statusType,
    required this.statusIcon,
    this.actions,
    this.onOpen,
    this.onCondition,
    this.itemIcon = Icons.inventory_2_outlined,
  });
  final String name;
  final String description;
  final String statusLabel;
  final StatusBadgeType statusType;
  final IconData statusIcon;
  final Widget? actions;
  final VoidCallback? onOpen, onCondition;
  final IconData itemIcon;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: Icon(itemIcon),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: onOpen == null ? null : 3,
                      overflow: onOpen == null ? null : TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ?actions,
            ],
          ),
          const SizedBox(height: 12),
          StatusBadge(label: statusLabel, type: statusType, icon: statusIcon),
          if (onOpen != null || onCondition != null)
            Wrap(
              spacing: 8,
              children: [
                if (onCondition != null)
                  TextButton.icon(
                    onPressed: onCondition,
                    icon: const Icon(Icons.build_outlined),
                    label: const Text('Muuda olekut'),
                  ),
                if (onOpen != null)
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.history),
                    label: const Text('Ülevaade ja ajalugu'),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
