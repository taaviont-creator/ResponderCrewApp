import 'package:flutter/material.dart';
import '../models/availability_model.dart';
import '../theme/app_theme.dart';
import 'home_header.dart';

/// A normal layout surface: status choices use LayoutBuilder and cannot be
/// measured by an IntrinsicHeight parent.
class PersonalAvailabilityCard extends StatelessWidget {
  const PersonalAvailabilityCard({
    super.key,
    required this.status,
    required this.minutes,
    required this.plannedUnavailable,
    required this.saving,
    required this.onSelect,
    required this.onDelayChanged,
    this.loading = false,
    this.error = false,
    this.onRetry,
  });
  final String status;
  final int minutes;
  final bool plannedUnavailable, saving, loading, error;
  final ValueChanged<String> onSelect;
  final ValueChanged<int> onDelayChanged;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Minu staatus', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (error) ...[
            const Text('Staatust või planeeringuid ei saanud laadida.'),
            TextButton(onPressed: onRetry, child: const Text('Proovi uuesti')),
          ] else if (loading)
            const LinearProgressIndicator(semanticsLabel: 'Staatuse laadimine')
          else ...[
            PersonalStatusChoices(
              status: status,
              minutes: minutes,
              saving: saving,
              plannedUnavailable: plannedUnavailable,
              onSelect: onSelect,
            ),
            if (plannedUnavailable) ...[
              const SizedBox(height: 10),
              Text(
                'Planeeritud mittevalve on praegu aktiivne. '
                'Valvesse märkimiseks muuda või tühista see allpool. '
                'Mittevalve lõppedes kehtib taas sinu valitud staatus.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (status == AvailabilityStatus.delayed) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(minutes),
                initialValue: minutes,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(
                  labelText: 'Reageerimisviivitus',
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: [
                  for (final value in const [15, 30, 60])
                    DropdownMenuItem(value: value, child: Text('+ $value min')),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) onDelayChanged(value);
                      },
              ),
            ],
            if (saving) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(color: AppColors.navy),
            ],
          ],
        ],
      ),
    ),
  );
}
