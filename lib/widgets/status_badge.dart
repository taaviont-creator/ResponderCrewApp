import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusBadgeType {
  ready,
  offDuty,
  delayed,
  activeCallout,
  equipmentWarning,
  critical,
  neutral,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
  });

  final String label;
  final StatusBadgeType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(type);
    final badgeIcon = icon ?? _iconFor(type);

    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.foreground.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badgeIcon,
              size: 16,
              color: colors.foreground,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusColors _colorsFor(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.ready:
        return const _StatusColors(
          foreground: AppColors.ready,
          background: AppColors.readySurface,
        );
      case StatusBadgeType.offDuty:
        return const _StatusColors(
          foreground: AppColors.offDuty,
          background: AppColors.offDutySurface,
        );
      case StatusBadgeType.delayed:
        return const _StatusColors(
          foreground: AppColors.delayed,
          background: AppColors.delayedSurface,
        );
      case StatusBadgeType.activeCallout:
        return const _StatusColors(
          foreground: AppColors.activeCallout,
          background: AppColors.activeCalloutSurface,
        );
      case StatusBadgeType.equipmentWarning:
        return const _StatusColors(
          foreground: AppColors.equipmentWarning,
          background: AppColors.equipmentWarningSurface,
        );
      case StatusBadgeType.critical:
        return const _StatusColors(
          foreground: AppColors.critical,
          background: AppColors.criticalSurface,
        );
      case StatusBadgeType.neutral:
        return const _StatusColors(
          foreground: AppColors.textSecondary,
          background: AppColors.surfaceBlueStrong,
        );
    }
  }

  IconData _iconFor(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.ready:
        return Icons.check_circle_outline;
      case StatusBadgeType.offDuty:
        return Icons.cancel_outlined;
      case StatusBadgeType.delayed:
        return Icons.schedule;
      case StatusBadgeType.activeCallout:
        return Icons.campaign_outlined;
      case StatusBadgeType.equipmentWarning:
        return Icons.build_circle_outlined;
      case StatusBadgeType.critical:
        return Icons.warning_amber_rounded;
      case StatusBadgeType.neutral:
        return Icons.info_outline;
    }
  }
}

class _StatusColors {
  const _StatusColors({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;
}
