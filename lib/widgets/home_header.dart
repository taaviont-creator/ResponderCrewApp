import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/availability_model.dart';

class HomeOrganizationTitle extends StatelessWidget {
  const HomeOrganizationTitle({super.key, required this.name, this.onSwitch});
  final String name;
  final VoidCallback? onSwitch;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onSwitch,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      foregroundColor: AppColors.deepSeaBlue,
      disabledForegroundColor: AppColors.deepSeaBlue,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sailing_outlined),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.deepSeaBlue),
          ),
        ),
        if (onSwitch != null) const Icon(Icons.expand_more),
      ],
    ),
  );
}

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({
    super.key,
    required this.displayName,
    required this.role,
  });
  final String displayName, role;
  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? 'Tere!' : 'Tere, $name',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 2),
        Text(
          role,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class PersonalStatusChoices extends StatelessWidget {
  const PersonalStatusChoices({
    super.key,
    required this.status,
    required this.minutes,
    required this.saving,
    required this.plannedUnavailable,
    required this.onSelect,
  });
  final String status;
  final int minutes;
  final bool saving, plannedUnavailable;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      Widget button(String value, String label, IconData icon) {
        final selected =
            !saving &&
            (plannedUnavailable
                ? value == AvailabilityStatus.offDuty
                : status == value);
        final (foreground, background) = switch (value) {
          AvailabilityStatus.onDuty => (
            AppColors.ready,
            AppColors.readySurface,
          ),
          AvailabilityStatus.delayed => (
            AppColors.delayed,
            AppColors.delayedSurface,
          ),
          _ => (AppColors.offDuty, AppColors.offDutySurface),
        };
        return SizedBox(
          width: columns
              ? (constraints.maxWidth - 16) / 3
              : constraints.maxWidth,
          child: OutlinedButton(
            onPressed:
                saving ||
                    (plannedUnavailable && value != AvailabilityStatus.offDuty)
                ? null
                : () => onSelect(value),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 76),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              backgroundColor: selected ? background : AppColors.surface,
              foregroundColor: selected ? foreground : AppColors.textPrimary,
              side: BorderSide(color: selected ? foreground : AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          button(AvailabilityStatus.onDuty, 'Valves', Icons.verified_outlined),
          button(
            AvailabilityStatus.delayed,
            'Hilinemisega\n+$minutes min',
            Icons.schedule,
          ),
          button(
            AvailabilityStatus.offDuty,
            'Mitte valves',
            Icons.nights_stay_outlined,
          ),
        ],
      );
    },
  );
}
