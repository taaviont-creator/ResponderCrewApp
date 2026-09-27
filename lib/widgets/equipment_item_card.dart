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
  });
  final String name;
  final String description;
  final String statusLabel;
  final StatusBadgeType statusType;
  final IconData statusIcon;
  final Widget? actions;

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
              const Padding(
                padding: EdgeInsets.only(right: 12, top: 4),
                child: Icon(Icons.inventory_2_outlined),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ),
              ),
              ?actions,
            ],
          ),
          const SizedBox(height: 12),
          StatusBadge(label: statusLabel, type: statusType, icon: statusIcon),
        ],
      ),
    ),
  );
}
