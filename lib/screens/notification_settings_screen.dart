import '../widgets/app_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _deviceSettings(String method) async {
    try {
      await const MethodChannel(
        'respondcrew/notifications',
      ).invokeMethod<void>(method);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ava telefoni seadetes RespondCrew teavitused.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Teavituste seaded')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        return ListView(
          padding: const EdgeInsets.all(16),
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
            const Divider(),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'SAR-häire heli ja lukustuskuva teavitused seadista RespondCrew telefoniäpis.',
                ),
              ),
            if (!kIsWeb) ...[
              const Text(
                'SAR-häire telefonis',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Luba RespondCrew teavitused ja SAR-häire kanali heli, vibratsioon ning lukustuskuva teavitus. Trossi mereabi ja valmiduse muutused kasutavad eraldi tavalisemaid teavitusi.',
              ),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await CalloutAlarmNotificationService.instance
                        .requestPermissionAndRefreshRegistration();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Kontrolli telefoni teavitusluba ja ühendust.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Kontrolli / luba teavitused'),
              ),
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android) ...[
                OutlinedButton(
                  onPressed: () => _deviceSettings('openSarChannel'),
                  child: const Text('Ava SAR-häire telefoni seaded'),
                ),
                const Text(
                  '„Mitte segada“ režiimis sõltub heli sinu telefoni lubatud eranditest. Soovi korral luba Androidi seadetes RespondCrew SAR-kanalile erand. Rakendus ise režiimi ega sinu helivalikuid ei muuda.',
                ),
                TextButton(
                  onPressed: () => _deviceSettings('openDndSettings'),
                  child: const Text('Ava „Mitte segada“ seaded'),
                ),
              ],
              OutlinedButton(
                onPressed: () async {
                  try {
                    final shown = await CalloutAlarmNotificationService.instance
                        .showLocalTestAlarmNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            shown
                                ? 'Seadme testteavitus saadetud.'
                                : 'Teavitusluba puudub.',
                          ),
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Testteavitust ei saanud näidata. Kontrolli telefoni teavituste seadeid.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Proovi selles telefonis SAR-heli'),
              ),
              const Text(
                'Seadme proov kontrollib kohalikku heli. Push-teate saabumist proovi eraldi väljakutsega ka taustal ja lukustatud ekraaniga.',
              ),
            ],
          ],
        );
      },
    ),
  );
}
