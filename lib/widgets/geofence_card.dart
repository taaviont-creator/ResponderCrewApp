import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/geofence_service.dart';
import '../models/activity_schedule.dart';

class GeofenceCard extends StatefulWidget {
  const GeofenceCard({
    super.key,
    required this.organizationId,
    this.admin = false,
    this.service,
  });
  final GeofenceService? service;
  final String organizationId;
  final bool admin;
  @override
  State<GeofenceCard> createState() => _GeofenceCardState();
}

class _GeofenceCardState extends State<GeofenceCard>
    with WidgetsBindingObserver {
  late final service = widget.service ?? GeofenceService();
  Map<String, dynamic>? data;
  String? failure;
  bool busy = false;
  bool permissions = false;
  bool local = false;
  Timer? clock;
  String? deviceError;
  Map get config => data?['config'] as Map? ?? {};
  Map get state => data?['state'] as Map? ?? {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
    if (!widget.admin) {
      clock = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!busy) unawaited(load());
      });
    }
  }

  @override
  void didUpdateWidget(covariant GeofenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) {
      data = null;
      unawaited(load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) unawaited(load());
  }

  @override
  void dispose() {
    clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load() async {
    final org = widget.organizationId;
    try {
      final value = await service.call(org, 'get');
      final ready =
          GeofenceService.supported && await service.permissionsReady();
      final session = (value['state'] as Map?)?['sessionId'] as String?;
      final isLocal =
          GeofenceService.supported &&
          session != null &&
          await service.localSession(session) != null;
      final error = isLocal ? await service.error(session) : null;
      if (mounted && widget.organizationId == org) {
        setState(() {
          data = value;
          permissions = ready;
          local = isLocal;
          failure = null;
          deviceError = error;
        });
      }
    } catch (_) {
      if (mounted && widget.organizationId == org) {
        setState(
          () =>
              failure = 'Asukohapõhise valmisoleku andmeid ei saanud laadida.',
        );
      }
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FirebaseFunctionsException
                  ? e.message ?? 'Salvestamine ebaõnnestus.'
                  : e is StateError
                  ? e.message.toString()
                  : 'Toiming ebaõnnestus. Kontrolli asukohaluba ja ühendust.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get reason => switch (state['reason']) {
    'disabled' => 'Automaatika on välja lülitatud.',
    'waiting' => 'Valves. Ootab esimest asukohakontrolli.',
    'plannedAbsence' =>
      'Planeeritud mittevalve on aktiivne. Asukoht sinu staatust sel ajal ei muuda.',
    'manual' => 'Käsitsi valitud staatus peatas automaatika.',
    'callout' =>
      'Automaatika on väljakutsel osalemise ajaks peatatud. Pärast väljakutset lülita see uuesti sisse.',
    'configuration' =>
      'Ühingu piirkond muutus. Lülita automaatika uuesti sisse.',
    'membership' => 'Ühingu liikmelisus muutus.',
    'stale' => 'Asukohainfo aegus. Lülita automaatika uuesti sisse.',
    'locationUnavailable' =>
      'Asukoht pole piisavalt täpne või luba puudub. Automaatne staatus: mitte valves.',
    'returnCandidate' =>
      'Telefon tuvastas võimaliku naasmise valvesoleku piirkonda. Kinnitamisel kontrollitakse asukohta uuesti. Seni oled mitte valves.',
    _ => switch (state['zone']) {
      'inner' =>
        state['confirmationRequired'] == true
            ? 'Oled valvesoleku piirkonnas. Kas oled valmis valves olema?'
            : 'Valvesoleku raadiuses · valvesolek kinnitatud',
      'ring' => 'Hilinemisega valve raadiuses',
      'outside' => 'Valveraadiusest väljas · mitte valves',
      _ => 'Piirkonna kinnitus puudub.',
    },
  };
  @override
  Widget build(BuildContext context) {
    if (widget.admin) return _admin();
    final enabled = state['enabled'] == true;
    final last = state['lastObservedMs'] as num?;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asukohapõhine valmisolek',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (failure != null) ...[
              Text(failure!),
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Proovi uuesti'),
              ),
            ] else if (data == null)
              const LinearProgressIndicator()
            else if (config['enabled'] != true)
              const Text(
                'Ühingu admin pole asukohapõhist valmisolekut sisse lülitanud.',
              )
            else ...[
              Text(
                'Valvesoleku raadius: ${(config['innerMeters'] as num) / 1000} km. Hilinemisega valve kuni ${(config['outerMeters'] as num) / 1000} km, kaugemal mitte valves.',
              ),
              if (!GeofenceService.supported)
                const Text(
                  'Automaatika töötab Androidi või iPhone’i rakenduses. Brauser ei jälgi taustal piirkondi.',
                )
              else ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kasuta selles telefonis'),
                  value: enabled && local,
                  onChanged: busy || failure != null
                      ? null
                      : (value) => run(() async {
                          if (!value) {
                            await service.disable(
                              widget.organizationId,
                              state['sessionId'] as String?,
                            );
                            return;
                          }
                          final agreed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Asukohapõhine valmisolek'),
                              content: const Text(
                                'Telefon kontrollib ühingu piirkonda ka taustal. Täpset asukohta ega liikumisteekonda serverisse ei saadeta.\n\nMärgi end esmalt valvesse. Automaatika kohandab sinu alustatud valvet: valvesoleku raadiusest väljudes hilinemisega, kaugemast piirist väljudes mitte valves. Tagasi jõudes küsime valvesse naasmiseks kinnitust. Käsitsi valitud staatus peatab automaatika. Planeeritud mittevalve ajal asukoht sinu staatust ei muuda.\n\nKui 24 tunni jooksul uut asukohakinnitust ei tule, lõpeb automaatne valvesolek. Piirkonnateated võivad telefoni tõttu viibida.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Loobu'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Luba automaatika'),
                                ),
                              ],
                            ),
                          );
                          if (agreed != true) return;
                          if (!await service.permissionsReady()) {
                            await service.requestPermissions();
                            if (!await service.permissionsReady()) return;
                          }
                          await service.enable(widget.organizationId);
                        }),
                ),
                if (!permissions) ...[
                  const Text(
                    'Vajalik on täpne asukoht ja asukohaluba „Alati“. Telefoni energiasääst võib taustateateid viivitada.',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(service.requestPermissions),
                    child: const Text('Ava asukoha õigused'),
                  ),
                ],
              ],
              if (state.isNotEmpty) Text(reason),
              if (enabled && !local)
                const Text(
                  'Automaatika on sisse lülitatud teises telefonis. Siin sisselülitamine asendab varasema telefoni.',
                ),
              if (deviceError != null)
                Text(
                  deviceError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (last != null && last > 0)
                Text(
                  'Viimane asukohakinnitus: ${ActivitySchedule.format(DateTime.fromMillisecondsSinceEpoch(last.toInt()))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (enabled && local)
                Wrap(
                  spacing: 8,
                  children: [
                    if (state['confirmationRequired'] == true)
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => run(
                                () => service.confirm(
                                  widget.organizationId,
                                  state['sessionId'] as String,
                                ),
                              ),
                        icon: const Icon(Icons.check),
                        label: const Text('Kinnitan: olen valves'),
                      ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              await service.sample(
                                state['sessionId'] as String,
                              );
                            }),
                      child: const Text('Kontrolli asukohta'),
                    ),
                  ],
                ),
            ],
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _admin() => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.radar),
      title: const Text('Asukohapõhine valmisolek'),
      subtitle: const Text('Liikme vabatahtlik piirkonnaautomaatika'),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        if (failure != null)
          Text(failure!)
        else if (data == null)
          const LinearProgressIndicator()
        else ...[
          Text(
            config['latitude'] == null
                ? 'Määra kõigepealt ühingu asukoht keskuste kaardi seadetes.'
                : 'Kasutab ühingu olemasolevat baasiasukohta.',
          ),
          Text(
            'Valves kuni ${(config['innerMeters'] as num) / 1000} km · hilinemisega kuni ${(config['outerMeters'] as num) / 1000} km · hilinemine ${config['delayMinutes']} min',
          ),
          Text(
            config['enabled'] == true
                ? 'Ühingus lubatud. Iga liige lülitab automaatika ise sisse.'
                : 'Ühingus välja lülitatud.',
          ),
          TextButton.icon(
            onPressed: busy ? null : editSettings,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Muuda valveraadiusi'),
          ),
        ],
      ],
    ),
  );
  Future<void> editSettings() async {
    final inner = TextEditingController(
      text: ((config['innerMeters'] as num) / 1000).toString(),
    );
    final outer = TextEditingController(
      text: ((config['outerMeters'] as num) / 1000).toString(),
    );
    var allowed = config['enabled'] == true;
    var minutes = config['delayMinutes'] as int;
    String? validation;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Kaugus ühingu baasist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Luba liikmetele automaatika'),
                  value: allowed,
                  onChanged: (v) => set(() => allowed = v),
                ),
                TextField(
                  controller: inner,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valvesoleku raadius (km)',
                  ),
                ),
                TextField(
                  controller: outer,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Hilinemisega valve raadius (km)',
                  ),
                ),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: minutes,
                  decoration: const InputDecoration(
                    labelText: 'Hilinemine kahe raadiuse vahel',
                  ),
                  items: [15, 30, 60]
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('$v min')),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) minutes = v;
                  },
                ),
                const Text(
                  'Vali kaugused ühingu reageerimisaja ja kohalike teeolude järgi. Näiteks 20 ja 30 km: kuni 20 km valves, 20–30 km hilinemisega, üle 30 km mitte valves. Raadius on kaugus baasist linnulennul, mitte sõiduaeg. Tagasi valvesse märkimine vajab kinnitust. Raadiuste muutmise järel tuleb automaatika uuesti sisse lülitada.',
                ),
                if (validation != null)
                  Text(
                    validation!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Loobu'),
            ),
            FilledButton(
              onPressed: () {
                final a = double.tryParse(inner.text.replaceAll(',', '.'));
                final b = double.tryParse(outer.text.replaceAll(',', '.'));
                if (a == null ||
                    b == null ||
                    !a.isFinite ||
                    !b.isFinite ||
                    a < .3 ||
                    b < a + .3 ||
                    b > 50) {
                  set(
                    () => validation =
                        'Kontrolli kaugusi. Hilinemisega valve raadius peab olema valvesoleku raadiusest suurem ja kuni 50 km. Väldi liiga väikseid või peaaegu võrdseid raadiusi.',
                  );
                  return;
                }
                Navigator.pop(context, {
                  'enabled': allowed,
                  'innerMeters': (a * 1000).round(),
                  'outerMeters': (b * 1000).round(),
                  'delayMinutes': minutes,
                  'expectedRevision': config['revision'],
                });
              },
              child: const Text('Salvesta'),
            ),
          ],
        ),
      ),
    );
    // Dialog route animations can still reference controllers after pop.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    inner.dispose();
    outer.dispose();
    if (result != null && mounted) {
      await run(() async {
        await service.call(widget.organizationId, 'save', result);
      });
    }
  }
}
