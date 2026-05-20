import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/availability_model.dart';
import '../models/availability_reminder_settings_model.dart';
import '../services/availability_reminder_settings_service.dart';
import '../services/availability_service.dart';
import '../services/membership_service.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
  });

  final String organizationId;
  final String currentUid;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  final _availabilityService = AvailabilityService();
  final _availabilityReminderSettingsService =
      AvailabilityReminderSettingsService();
  final _membershipService = MembershipService();

  Widget _buildAvailabilityControl() {
    return StreamBuilder<AvailabilityModel?>(
      stream: _availabilityService.streamMyAvailability(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final availability = snapshot.data;
        final status = availability?.status ?? AvailabilityStatus.offDuty;
        final responseMinutes = availability?.responseMinutes ?? 15;

        Future<void> updateAvailability(
          String newStatus, {
          int? minutes,
        }) async {
          try {
            await _availabilityService.setMyAvailability(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
              status: newStatus,
              responseMinutes: minutes,
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Valmiduse muutmine ebaonnestus: $e')),
            );
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Minu valmisolek'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Off duty'),
                      selected: status == AvailabilityStatus.offDuty,
                      onSelected: (_) => updateAvailability(
                        AvailabilityStatus.offDuty,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('On duty'),
                      selected: status == AvailabilityStatus.onDuty,
                      onSelected: (_) => updateAvailability(
                        AvailabilityStatus.onDuty,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Delayed'),
                      selected: status == AvailabilityStatus.delayed,
                      onSelected: (_) => updateAvailability(
                        AvailabilityStatus.delayed,
                        minutes: responseMinutes,
                      ),
                    ),
                  ],
                ),
                if (status == AvailabilityStatus.delayed) ...[
                  const SizedBox(height: 8),
                  DropdownButton<int>(
                    value: responseMinutes,
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      updateAvailability(
                        AvailabilityStatus.delayed,
                        minutes: value,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityReminderSettings() {
    return StreamBuilder<AvailabilityReminderSettingsModel>(
      stream: _availabilityReminderSettingsService.streamMySettings(
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final settings = snapshot.data ??
            AvailabilityReminderSettingsModel.defaults(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
            );
        final timeOptions = _reminderTimeOptions(settings.reminderTime);

        Future<void> updateReminderSettings({
          bool? enabled,
          int? intervalHours,
          String? reminderTime,
        }) async {
          try {
            await _availabilityReminderSettingsService.setMySettings(
              userId: widget.currentUid,
              organizationId: widget.organizationId,
              enabled: enabled ?? settings.enabled,
              intervalHours: intervalHours ?? settings.intervalHours,
              reminderTime: reminderTime ?? settings.reminderTime,
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Meeldetuletuse muutmine ebaonnestus: $e'),
              ),
            );
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Valmisoleku meeldetuletused'),
                  value: settings.enabled,
                  onChanged: (value) => updateReminderSettings(
                    enabled: value,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: settings.intervalHours,
                  decoration: const InputDecoration(labelText: 'Intervall'),
                  items: AvailabilityReminderSettingsModel.allowedIntervalHours
                      .map((hours) {
                    return DropdownMenuItem<int>(
                      value: hours,
                      child: Text(_reminderIntervalLabel(hours)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    updateReminderSettings(intervalHours: value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: settings.reminderTime,
                  decoration: const InputDecoration(labelText: 'Kellaaeg'),
                  items: timeOptions.map((time) {
                    return DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    updateReminderSettings(reminderTime: value);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityOverview() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _membershipService.streamActiveMembershipsForOrganization(
        widget.organizationId,
      ),
      builder: (context, membershipsSnapshot) {
        final activeMemberships = membershipsSnapshot.data ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return StreamBuilder<List<AvailabilityModel>>(
          stream: _availabilityService.streamOrganizationAvailability(
            organizationId: widget.organizationId,
          ),
          builder: (context, availabilitySnapshot) {
            final availabilityByUserId = <String, AvailabilityModel>{};
            for (final availability
                in availabilitySnapshot.data ?? const <AvailabilityModel>[]) {
              if (availability.userId.isNotEmpty) {
                availabilityByUserId[availability.userId] = availability;
              }
            }

            int onDutyCount = 0;
            int delayedCount = 0;
            int offDutyCount = 0;

            for (final membershipDoc in activeMemberships) {
              final userId = (membershipDoc.data()['userId'] ?? '').toString();
              final availability = availabilityByUserId[userId];
              final status = availability?.status ?? AvailabilityStatus.offDuty;

              if (status == AvailabilityStatus.onDuty) {
                onDutyCount++;
              } else if (status == AvailabilityStatus.delayed) {
                delayedCount++;
              } else {
                offDutyCount++;
              }
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Organisatsiooni valmisolek'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text('On duty: $onDutyCount'),
                        Text('Delayed: $delayedCount'),
                        Text('Off duty: $offDutyCount'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (activeMemberships.isEmpty)
                      const Text('Liikmeid ei leitud')
                    else
                      ...activeMemberships.map((membershipDoc) {
                        final membership = membershipDoc.data();
                        final userId = (membership['userId'] ?? '').toString();
                        final availability = availabilityByUserId[userId];
                        final status =
                            availability?.status ?? AvailabilityStatus.offDuty;
                        final responseMinutes = availability?.responseMinutes;

                        return FutureBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          builder: (context, userSnapshot) {
                            final userData = userSnapshot.data?.data() ?? {};
                            final name = (userData['name'] ?? '').toString();
                            final email = (userData['email'] ?? '').toString();
                            final title = name.isNotEmpty
                                ? name
                                : (email.isNotEmpty ? email : userId);
                            final subtitle =
                                status == AvailabilityStatus.delayed &&
                                        responseMinutes != null
                                    ? '$status - $responseMinutes min'
                                    : status;

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(title),
                              subtitle: Text(subtitle),
                            );
                          },
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valmisolek'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAvailabilityControl(),
          const SizedBox(height: 16),
          _buildAvailabilityReminderSettings(),
          const SizedBox(height: 16),
          _buildAvailabilityOverview(),
        ],
      ),
    );
  }

  List<String> _reminderTimeOptions(String selectedTime) {
    final times = <String>{
      for (var hour = 0; hour < 24; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
      selectedTime,
    }.toList();

    times.sort();
    return times;
  }

  String _reminderIntervalLabel(int intervalHours) {
    if (intervalHours == 168) return '7 days';
    return '$intervalHours hours';
  }
}
