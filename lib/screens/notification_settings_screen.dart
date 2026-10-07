import '../widgets/app_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/device_alarm_settings_card.dart';
import '../models/notification_preferences.dart';
import '../services/callout_alarm_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.organizationId,
    required this.userId,
    required this.isAdmin,
  });
  final String organizationId, userId;
  final bool isAdmin;
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final _stream = FirebaseFirestore.instance
      .doc('notificationPreferences/${widget.userId}_${widget.organizationId}')
      .snapshots();
  String? _saving;
  Future<void> _save(String key, bool enabled) async {
    setState(() => _saving = key);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-north1',
      ).httpsCallable('setNotificationPreference').call({
        'organizationId': widget.organizationId,
        'key': key,
        'enabled': enabled,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eelistust ei saanud salvestada.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Teavituste seaded')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (kIsWeb)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'SAR-häire heli ja lukustuskuva teavitused seadista RespondCrew telefoniäpis.',
            ),
          ),
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS))
          DeviceAlarmSettingsCard(
            testNow: () => CalloutAlarmNotificationService.instance
                .showLocalTestAlarmNotification(),
            testAlarm: () => CalloutAlarmNotificationService.instance
                .scheduleLocalTestAlarm(),
            cancelTest: () =>
                CalloutAlarmNotificationService.instance.cancelLocalTestAlarm(),
          ),
        const Divider(height: 32),
        Text(
          'Selle ühingu teavitused',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Teavituste seadeid ei õnnestunud laadida.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final prefs = NotificationPreferences.resolve(
              admin: widget.isAdmin,
              stored: Map<String, dynamic>.from(
                snapshot.data!.data()?['preferences'] as Map? ?? {},
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Valikud kehtivad sinu jaoks selles ühingus. Adminile on kriitilised valmiduse teated vaikimisi sisse lülitatud. Ühe muutuse põhjused koondatakse ühte teatesse.',
                ),
                for (final entry in NotificationPreferences.labels.entries)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    value: prefs[entry.key]!,
                    onChanged: _saving != null
                        ? null
                        : (value) => _save(entry.key, value),
                  ),
                if (_saving != null) const LinearProgressIndicator(),
              ],
            );
          },
        ),
      ],
    ),
  );
}
