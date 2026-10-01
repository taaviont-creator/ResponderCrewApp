import '../widgets/app_layout.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/platform_application_notices.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/command_service.dart';
import '../widgets/center_access_dialog.dart';
import 'center_sharing_screen.dart';

class PlatformManagementScreen extends StatefulWidget {
  const PlatformManagementScreen({
    super.key,
    this.call,
    this.pendingUpdates,
    this.notices,
  });
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  call;
  final Stream<Object?>? pendingUpdates;
  final Widget? notices;
  @override
  State<PlatformManagementScreen> createState() =>
      _PlatformManagementScreenState();
}

class _PlatformManagementScreenState extends State<PlatformManagementScreen> {
  late final _functions = FirebaseFunctions.instanceFor(
    region: 'europe-north1',
  );
  String _section = 'home', _query = '';
  int _sharingRevision = 0;

  Future<void> _refreshCurrent() async {
    if (_loading || _saving) return;
    if (['accounts', 'centerAccounts'].contains(_section)) {
      await _loadAccounts(restart: true);
    } else {
      if (['requests', 'centers'].contains(_section)) {
        setState(() => _sharingRevision++);
      }
      await _load();
    }
  }

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (widget.call != null) return widget.call!(name, data);
    final result = await _functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  void _open(String section) {
    setState(() {
      _section = section;
      _query = '';
    });
    if (['accounts', 'centerAccounts'].contains(section) &&
        !_accountsLoaded &&
        !_saving) {
      unawaited(_loadAccounts());
    }
  }

  Map<String, dynamic>? _data;
  StreamSubscription<Object?>? _pendingSubscription;
  bool _reloadQueued = false;
  final List<Map<String, dynamic>> _accounts = [];
  String? _pageToken, _error;
  bool _loading = true, _saving = false, _accountsLoaded = false;
  static List<Map<String, dynamic>> maps(dynamic value) =>
      (value as List? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
  @override
  void initState() {
    super.initState();
    _load();
    _pendingSubscription =
        (widget.pendingUpdates ??
                FirebaseFirestore.instance
                    .collection('commands')
                    .where('status', isEqualTo: 'pending')
                    .snapshots())
            .listen((_) {
              if (_loading || _saving) {
                _reloadQueued = true;
              } else {
                _load();
              }
            }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _call('getPlatformOverview');
      if (mounted) {
        setState(() {
          _data = result;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Platvormihalduse laadimine ebaõnnestus. Kontrolli ühendust ja õigust.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_reloadQueued && !_saving) {
          _reloadQueued = false;
          unawaited(_load());
        }
      }
    }
  }

  Future<void> _change(Map<String, dynamic> org, String action) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${org['name']}'),
        content: Text(switch (action) {
          'approve' =>
            'Kinnitan organisatsiooni taotluse. Looja saab esimeseks adminiks.',
          'reject' => 'Lükkan organisatsiooni taotluse tagasi.',
          'suspended' => 'Peatan organisatsiooni kasutusõiguse.',
          'approved' => 'Taastan organisatsiooni kasutusõiguse.',
          _ => '',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Katkesta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kinnita'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _saving = true);
    try {
      if (action == 'approve') {
        await CommandService().approveCommand(
          commandId: org['id'],
          creatorUserId: org['createdBy'],
        );
      } else if (action == 'reject') {
        await CommandService().rejectCommand(
          commandId: org['id'],
          creatorUserId: org['createdBy'],
        );
      } else {
        await _functions.httpsCallable('setPlatformOrganizationStatus').call({
          'organizationId': org['id'],
          'status': action,
        });
      }
      if (mounted) await _load();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Muudatus ebaõnnestus. Proovi uuesti.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadAccounts({bool restart = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final data = await _call('getPlatformAccounts', {
        'pageToken': restart ? null : _pageToken,
      });
      if (mounted) {
        setState(() {
          if (restart) _accounts.clear();
          for (final account in maps(data['users'])) {
            _accounts.removeWhere((old) => old['uid'] == account['uid']);
            _accounts.add(account);
          }
          _error = null;
          _pageToken = data['pageToken'];
          _accountsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kasutajakontode laadimine ebaõnnestus.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> account) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tühista konto sisselogimisseansid?'),
        content: Text(
          '${account['email']} peab järgmisel seansi uuendamisel uuesti sisse logima. Liikmesused ja rollid säilivad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Katkesta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tühista seansid'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _functions.httpsCallable('revokeAccountSessions').call({
        'userId': account['uid'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seansside uuendamise õigus tühistatud.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Seansside tühistamine ebaõnnestus.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> get _organizations =>
      maps(_data?['organizations']);
  Widget _organizationList(bool pendingOnly) {
    final organizations = _organizations
        .where(
          (o) =>
              pendingOnly ? o['status'] == 'pending' : o['status'] != 'pending',
        )
        .toList();
    final pending = organizations.where((o) => o['status'] == 'pending').length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          pendingOnly
              ? 'Ühingute taotlused ($pending)'
              : 'Ühingud (${organizations.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (organizations.isEmpty)
          Text(pendingOnly ? 'Ühingute taotlusi pole.' : 'Ühinguid pole.'),
        if (pendingOnly) widget.notices ?? const PlatformApplicationNotices(),
        for (final group in const {
          'pending': 'Kinnitamise ootel',
          'approved': 'Kinnitatud',
          'suspended': 'Peatatud',
          'rejected': 'Tagasi lükatud',
          'other': 'Muu olek',
        }.entries)
          if (organizations.any(
            (o) =>
                ([
                      'pending',
                      'approved',
                      'suspended',
                      'rejected',
                    ].contains(o['status'])
                    ? o['status']
                    : 'other') ==
                group.key,
          )) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                group.value,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final org in organizations.where(
              (o) =>
                  ([
                        'pending',
                        'approved',
                        'suspended',
                        'rejected',
                      ].contains(o['status'])
                      ? o['status']
                      : 'other') ==
                  group.key,
            ))
              Card(
                child: ExpansionTile(
                  title: Text(org['name']),
                  leading: Icon(
                    group.key == 'approved'
                        ? Icons.check_circle
                        : group.key == 'pending'
                        ? Icons.pending_actions
                        : Icons.pause_circle_outline,
                    color: group.key == 'approved'
                        ? Colors.green.shade700
                        : group.key == 'pending'
                        ? Colors.deepOrange.shade700
                        : Colors.grey.shade700,
                  ),
                  subtitle: Text(
                    '${group.value} · ${org['memberCount']} liiget · ${org['adminCount']} admini · ${org['calloutCount']} sündmust',
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Loodud: ${org['createdAt'] ?? 'Teadmata'}\nÜle vaadatud: ${org['reviewedAt'] ?? 'Veel mitte'}\nViimane teadaolev aktiivsus: ${org['lastActivity'] ?? 'Teadmata'}',
                    ),
                    for (final p in Map<String, dynamic>.from(
                      org['profile'] as Map? ?? {},
                    ).entries)
                      if (![
                            'organizationId',
                            'createdBy',
                            'createdAt',
                          ].contains(p.key) &&
                          p.value.toString().isNotEmpty)
                        ListTile(
                          title: Text(
                            const {
                                  'registrationCode': 'Registrikood',
                                  'organizationType': 'Tüüp',
                                  'region': 'Tegevuspiirkond',
                                  'address': 'Aadress',
                                  'contactName': 'Kontaktisik',
                                  'contactPhone': 'Telefon',
                                  'contactEmail': 'Kontaktisiku e-post',
                                  'organizationEmail': 'Ühingu e-post',
                                  'description': 'Kirjeldus',
                                  'logoUrl': 'Logo veebiaadress',
                                }[p.key] ??
                                p.key,
                          ),
                          subtitle: Text('${p.value}'),
                        ),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (org['status'] == 'pending') ...[
                          FilledButton(
                            onPressed: _saving
                                ? null
                                : () => _change(org, 'approve'),
                            child: const Text('Kinnita taotlus'),
                          ),
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _change(org, 'reject'),
                            child: const Text('Lükka tagasi'),
                          ),
                        ],
                        if (org['status'] == 'approved' ||
                            org['status'] == 'suspended')
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _change(
                                    org,
                                    org['status'] == 'approved'
                                        ? 'suspended'
                                        : 'approved',
                                  ),
                            child: Text(
                              org['status'] == 'approved'
                                  ? 'Peata kasutusõigus'
                                  : 'Taasta kasutusõigus',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        if (pendingOnly) ...[
          const Divider(),
          Text(
            'Kaardile lisamise taotlused',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          CenterSharingScreen(
            key: ValueKey('requests-$_sharingRevision'),
            embedded: true,
            pendingOnly: true,
            call: widget.call,
          ),
        ],
      ],
    );
  }

  Widget _accountList() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        _section == 'centerAccounts'
            ? 'Vali kasutaja ja määra Merevalvekeskuse või Trossi keskuse ligipääs. See ei anna ühingu admini õigusi.'
            : 'Kasutajakontode tehniline haldus.',
      ),
      TextField(
        decoration: const InputDecoration(
          labelText: 'Otsi nime või e-posti järgi',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),

      for (final account in _accounts.where(
        (a) => '${a['name']} ${a['email']}'.toLowerCase().contains(
          _query.toLowerCase(),
        ),
      ))
        Card(
          child: _section == 'centerAccounts'
              ? ListTile(
                  title: Text(
                    account['name'].toString().isEmpty
                        ? account['email']
                        : account['name'],
                  ),
                  subtitle: Text(account['email']),
                  trailing: const Icon(Icons.manage_accounts_outlined),
                  onTap: _saving
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => CenterAccessDialog(
                            userId: account['uid'] as String,
                            name: account['email'] as String,
                          ),
                        ),
                )
              : ExpansionTile(
                  title: Text(
                    account['name'].toString().isEmpty
                        ? account['email']
                        : account['name'],
                  ),
                  subtitle: Text(account['email']),
                  children: [
                    Text(
                      'E-post kinnitatud: ${account['emailVerified'] == true ? 'jah' : 'ei'}\nKonto peatatud: ${account['disabled'] == true ? 'jah' : 'ei'}\nViimane sisselogimine: ${account['lastSignInTime']}',
                    ),
                    SelectableText('ID: ${account['uid']}'),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Keskuste ligipääs'),
                      onPressed: _saving
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) => CenterAccessDialog(
                                userId: account['uid'] as String,
                                name: account['email'] as String,
                              ),
                            ),
                    ),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _revoke(account),
                      child: const Text('Tühista sisselogimisseansid'),
                    ),
                  ],
                ),
        ),
      if (_accountsLoaded &&
          !_saving &&
          !_accounts.any(
            (a) => '${a['name']} ${a['email']}'.toLowerCase().contains(
              _query.toLowerCase(),
            ),
          ))
        Text(
          _query.isEmpty
              ? 'Kasutajakontosid pole.'
              : 'Laaditud kontode hulgast vastet ei leitud.',
        ),
      if (_pageToken != null)
        const Text(
          'Otsing hõlmab laaditud kontosid. Vajadusel laadi järgmised kontod.',
        ),
      if (!_accountsLoaded || _pageToken != null)
        OutlinedButton(
          onPressed: _saving ? null : _loadAccounts,
          child: Text(
            _accountsLoaded ? 'Laadi järgmised kontod' : 'Laadi kasutajakontod',
          ),
        ),
    ],
  );
  Widget _auditList() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Viimased 100 olulist muudatust'),
      for (final event in maps(_data?['audit']))
        ListTile(
          title: Text('${event['action']} · ${event['targetId']}'),
          subtitle: Text(
            '${event['createdAt']}\nMuutja: ${event['createdBy']}\nÜhing: ${event['organizationId'] ?? 'Platvorm'}${event['changedFields'] == null ? '' : '\nVäljad: ${(event['changedFields'] as List).join(', ')}'}',
          ),
        ),
    ],
  );
  Widget _tile(
    String section,
    IconData icon,
    String title,
    String description,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(section),
    ),
  );
  Widget _home() {
    final pending = _organizations
        .where((o) => o['status'] == 'pending')
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Vali, mida soovid hallata.'),
        _tile(
          'requests',
          Icons.inbox_outlined,
          'Taotlused',
          '$pending uut ühingut · kaardile lisamise taotlused',
        ),
        _tile(
          'centers',
          Icons.map_outlined,
          'Kaardikeskused',
          'Ühingute nähtavus ja keskuste kasutajaõigused',
        ),
        _tile(
          'organizations',
          Icons.apartment_outlined,
          'Ühingud',
          'Kinnitatud, peatatud ja tagasi lükatud ühingud',
        ),
        _tile(
          'accounts',
          Icons.people_outline,
          'Kasutajakontod',
          'Kontode otsing ja tehniline haldus',
        ),
        _tile('audit', Icons.history, 'Auditlogi', 'Olulised haldustoimingud'),
      ],
    );
  }

  Widget _centers() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Merevalvekeskus näeb SAR-valmidust. Trossi keskus näeb mereabi valmidust.',
      ),
      _tile(
        'centerAccounts',
        Icons.manage_accounts_outlined,
        'Keskuste kasutajaõigused',
        'Anna või eemalda konkreetse kasutaja ligipääs',
      ),
      const SizedBox(height: 16),
      Text(
        'Ühingute nähtavus kaardil',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'Siin kinnitad ühingute jagamistaotlused ja saad jagamise peatada.',
      ),
      CenterSharingScreen(
        key: ValueKey('centers-$_sharingRevision'),
        embedded: true,
        call: widget.call,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _section == 'home',
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _open('home');
    },
    child: AppScaffold(
      appBar: AppBar(
        leading: _section == 'home'
            ? null
            : BackButton(
                onPressed: () =>
                    _open(_section == 'centerAccounts' ? 'centers' : 'home'),
              ),
        title: Text(
          const {
            'home': 'RespondCrew haldus',
            'requests': 'Taotlused',
            'centers': 'Kaardikeskused',
            'organizations': 'Ühingud',
            'accounts': 'Kasutajakontod',
            'centerAccounts': 'Keskuste kasutajaõigused',
            'audit': 'Auditlogi',
          }[_section]!,
        ),
        actions: [
          IconButton(
            tooltip: 'Värskenda',
            onPressed: _saving || _loading ? null : _refreshCurrent,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading || _saving) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          Expanded(
            child: switch (_section) {
              'requests' => _organizationList(true),
              'organizations' => _organizationList(false),
              'centers' => _centers(),
              'accounts' || 'centerAccounts' => _accountList(),
              'audit' => _auditList(),
              _ => _home(),
            },
          ),
        ],
      ),
    ),
  );
}
