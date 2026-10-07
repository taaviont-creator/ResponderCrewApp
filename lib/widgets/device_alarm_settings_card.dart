import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/device_alarm_settings.dart';

class DeviceAlarmSettingsCard extends StatefulWidget {
  const DeviceAlarmSettingsCard({
    super.key,
    this.settings = const DeviceAlarmSettings(),
    required this.testAlarm,
    required this.cancelTest,
    this.testNow,
  });
  final DeviceAlarmSettings settings;
  final Future<bool> Function() testAlarm;
  final Future<void> Function() cancelTest;
  final Future<bool> Function()? testNow;

  @override
  State<DeviceAlarmSettingsCard> createState() =>
      _DeviceAlarmSettingsCardState();
}

class _DeviceAlarmSettingsCardState extends State<DeviceAlarmSettingsCard>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _settings;
  bool _failed = false, _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final result = await widget.settings.read();
      if (mounted) {
        setState(() {
          _settings = result;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _settings = null;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open(String method) async {
    try {
      final destination = await widget.settings.open(method);
      if (destination == 'dndList') {
        _message(
          'Vali „Mitte segada” ligipääsu loendist RespondCrew ja luba ligipääs.',
        );
      } else if (destination == 'fullScreenList') {
        _message('Vali loendist RespondCrew ja luba täisekraaniteavitused.');
      } else if (destination == 'appDetails' ||
          (destination == 'appNotifications' &&
              method != 'openAppNotifications')) {
        _message(
          'Telefon ei avanud otseteed. Vali RespondCrew teavituste alt „SAR-väljakutse häire”; eriligipääsu leia telefoni seadete „Erirakenduse juurdepääs” alt.',
        );
      }
    } catch (_) {
      _message(
        'Seadet ei saanud avada. Ava telefoni seadetes RespondCrew teavitused.',
      );
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _enableSarDnd() async {
    setState(() => _busy = true);
    try {
      final enabled = await widget.settings.enableSarDnd();
      await _refresh();
      if (enabled) {
        _message(
          'SAR-häire „Mitte segada“ erand on lubatud. Kontrolli seda proovihäirega.',
        );
      } else {
        _message(
          'Telefon ei lubanud erandit rakendusest muuta. Luba see SAR-kanali seadetes.',
        );
        await _open('openSarChannel');
      }
    } catch (_) {
      _message('Erandit ei saanud lubada. Ava SAR-kanali seaded.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _flag(String key, {String yes = 'Lubatud', String no = 'Keelatud'}) =>
      _settings?[key] == true
      ? yes
      : _settings?[key] == false
      ? no
      : 'Pole teada';
  Widget _row(
    IconData icon,
    String title,
    String subtitle,
    String destination,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _open(destination),
  );

  @override
  Widget build(BuildContext context) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final volume = _settings?['soundVolume'];
    final maximum = _settings?['soundVolumeMax'];
    final sound = _settings?['channelExists'] == false
        ? 'Kanal pole veel loodud'
        : _settings?['channelEnabled'] == false
        ? 'SAR-kanal on keelatud'
        : _settings?['channelSound'] == false
        ? 'Heli on välja lülitatud'
        : volume is int && maximum is int
        ? 'Helitugevus $volume / $maximum'
        : 'Pole teada';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAR-häire selles telefonis',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Need on RespondCrew õigused selles telefonis. Trossi mereabi kasutab eraldi tavateavitust.',
        ),
        if (_settings == null && !_failed) const LinearProgressIndicator(),
        if (_failed)
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Lubade olekut ei saanud lugeda. Proovi uuesti'),
          ),
        _row(
          Icons.notifications_outlined,
          'Teavitused',
          _flag('notificationsEnabled'),
          'openAppNotifications',
        ),
        if (android) ...[
          _row(
            Icons.volume_up_outlined,
            'SAR-häire heli ja vibratsioon',
            sound,
            'openSarChannel',
          ),
          _row(
            Icons.tune,
            'Alarmi helitugevus',
            volume is int && maximum is int
                ? 'Praegu $volume / $maximum · ava telefoni heliseaded'
                : 'Ava telefoni heliseaded ja tõsta alarmi helitugevust',
            'openSoundSettings',
          ),
          const Text(
            'SAR kasutab alarmi heli, mitte kõne- ega tavateavituse helitugevust. Vaikne režiim üksi ei peaks seda vaigistama. Alarmi helitugevus peab olema üle nulli ja SAR-kanali heli lubatud.',
          ),
          if (volume == 0)
            const Text(
              'Alarmi helitugevus on nullis — helilist häiret ei saa kuulda.',
            ),
          if (_settings?['alarmAudio'] == false &&
              _settings?['channelSound'] == true)
            const Text(
              'Telefon ei kasuta selle kanali jaoks alarmi heli. Kontrolli SAR-kanali seadeid ja tee proovihäire.',
            ),
          _row(
            Icons.do_not_disturb_on_outlined,
            '„Mitte segada“ ligipääs',
            _flag(
              'notificationPolicyAccess',
              yes: 'RespondCrew eriligipääs lubatud',
              no: 'Anna RespondCrew’le eriligipääs',
            ),
            'openDndSettings',
          ),
          _row(
            Icons.notification_important_outlined,
            'SAR-häire „Mitte segada“ erand',
            _flag(
              'bypassDnd',
              yes: 'SAR-kanali erand lubatud',
              no: 'SAR-kanali erand puudub',
            ),
            'openSarChannel',
          ),
          if (_settings?['notificationPolicyAccess'] == true &&
              _settings?['bypassDnd'] == false)
            FilledButton.icon(
              onPressed: _busy ? null : _enableSarDnd,
              icon: const Icon(Icons.notification_important_outlined),
              label: const Text('Luba SAR-häire „Mitte segada“ ajal'),
            ),
          const Text(
            '1. Luba RespondCrew „Mitte segada“ ligipääs ja tule tagasi. 2. Vajuta „Luba SAR-häire „Mitte segada“ ajal“. Kui telefon seda ei luba, ava SAR-häire erand ja muuda seda kanali seadetes. Rakendus ei lülita telefoni „Mitte segada“ režiimi välja.',
          ),
          if (_settings?['interruptionFilter'] == 3)
            const Text(
              'Telefonis on täielik vaikus. See võib blokeerida ka alarmid; muuda telefoni „Mitte segada“ reegleid.',
            ),
          _row(
            Icons.fullscreen,
            'Täisekraanihäire',
            _flag(
              'fullScreenAllowed',
              yes: 'Süsteemi luba olemas',
              no: 'Süsteemi luba puudub',
            ),
            'openFullScreenSettings',
          ),
          const Text(
            'Telefon otsustab, kas kuvada täisekraanihäire või teavitusriba. Lubade olemasolu ei taga heli, kui kanal või telefoni helitugevus on vaigistatud.',
          ),
          const Text(
            'Kõne ajal võib Android või telefoni tootja häireheli piirata. Kontrolli proovihäiret ka kõne ajal. Teavitus ja lubatud vibratsioon jäävad oluliseks lisamärguandeks.',
          ),
        ] else ...[
          _row(
            Icons.volume_up_outlined,
            'Teavituse heli',
            _flag('channelSound', yes: 'Lubatud', no: 'Vaigistatud'),
            'openAppNotifications',
          ),
          const Text(
            'iPhone’i kriitilised häired vajavad Apple’i eraldi heakskiitu. See versioon ei ületa vaikset ega „Mitte segada“ režiimi.',
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.testNow != null)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final sent = await widget.testNow!();
                          _message(
                            sent
                                ? 'Proovihäire saadeti. Kontrolli, kas kuuled heli.'
                                : 'Teavitusluba puudub. Luba teavitused telefoni seadetes.',
                          );
                        } catch (_) {
                          _message(
                            'Proovihäiret ei saanud käivitada. Kontrolli telefoni teavitusseadeid.',
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                          await _refresh();
                        }
                      },
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Kuula SAR-proovihäiret'),
              ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final scheduled = await widget.testAlarm();
                        _message(
                          scheduled
                              ? 'Proovihäire on ajastatud. Lukusta nüüd ekraan. Telefon võib häiret viivitada.'
                              : 'Teavitusluba puudub. Luba teavitused telefoni seadetes.',
                        );
                      } catch (_) {
                        _message(
                          'Proovihäiret ei saanud ajastada. Kontrolli telefoni teavitusseadeid.',
                        );
                      } finally {
                        if (mounted) setState(() => _busy = false);
                        await _refresh();
                      }
                    },
              icon: const Icon(Icons.notification_add_outlined),
              label: const Text('Proovihäire umbes 10 s pärast'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      try {
                        await widget.cancelTest();
                        _message('Proovihäire tühistatud.');
                      } catch (_) {
                        _message('Proovihäiret ei saanud tühistada.');
                      }
                    },
              child: const Text('Tühista proovihäire'),
            ),
          ],
        ),
        const Text(
          'Proov kontrollib ainult selle telefoni häiret. Serverist saabuva teate kontrollimiseks kasuta eraldi prooviväljakutset.',
        ),
      ],
    );
  }
}
