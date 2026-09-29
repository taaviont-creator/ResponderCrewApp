import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/platform_pending_badge.dart';
import '../widgets/platform_application_notices.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/command_service.dart';

class PlatformManagementScreen extends StatefulWidget {
  const PlatformManagementScreen({super.key});
  @override
  State<PlatformManagementScreen> createState() =>
      _PlatformManagementScreenState();
}

class _PlatformManagementScreenState extends State<PlatformManagementScreen> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-north1');
  Map<String, dynamic>? _data;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _pendingSubscription;
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
    _pendingSubscription = FirebaseFirestore.instance.collection('commands').where('status',isEqualTo:'pending').snapshots().listen((_) {
      if (_loading || _saving) { _reloadQueued = true; } else { _load(); }
    },onError:(Object _) {});
  }

  @override
  void dispose() { _pendingSubscription?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _functions
          .httpsCallable('getPlatformOverview')
          .call();
      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(result.data as Map);
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
      if (mounted) { setState(() => _loading = false); if (_reloadQueued && !_saving) { _reloadQueued = false; unawaited(_load()); } }
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

  Future<void> _loadAccounts() async {
    setState(() => _saving = true);
    try {
      final result = await _functions.httpsCallable('getPlatformAccounts').call(
        {'pageToken': _pageToken},
      );
      final data = Map<String, dynamic>.from(result.data as Map);
      if (mounted) {
        setState(() {
          _accounts.addAll(maps(data['users']));
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

  @override
  Widget build(BuildContext context) {
    final organizations = maps(_data?['organizations'])
      ..sort(
        (a, b) => (a['status'] == 'pending' ? 0 : 1).compareTo(
          b['status'] == 'pending' ? 0 : 1,
        ),
      );
    final pending = organizations.where((o) => o['status'] == 'pending').length;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RespondCrew haldus'),
          actions: [
            IconButton(
              tooltip: 'Värskenda',
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(child: PlatformPendingBadge(child: Text('Ühingud'))),
              Tab(text: 'Kasutajakontod'),
              Tab(text: 'Auditlogi'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
            if (_saving || _loading) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Kinnitust ootab $pending ühingut',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Platvormihaldus on eraldi organisatsiooni liikmelisusest ja sündmuste juhtimisest.',
                      ),
                      const PlatformApplicationNotices(),
                      for (final group in const {'pending':'Kinnitamise ootel','approved':'Kinnitatud','suspended':'Peatatud','rejected':'Tagasi lükatud','other':'Muu olek'}.entries)
                        if (organizations.any((o) => (['pending','approved','suspended','rejected'].contains(o['status']) ? o['status'] : 'other') == group.key)) ...[
                          Padding(padding: const EdgeInsets.only(top:16,bottom:8),child:Text(group.value,style:Theme.of(context).textTheme.titleMedium)),
                          for (final org in organizations.where((o) => (['pending','approved','suspended','rejected'].contains(o['status']) ? o['status'] : 'other') == group.key)) Card(
                          child: ExpansionTile(
                            title: Text(org['name']),
                            leading: Icon(group.key == 'approved' ? Icons.check_circle : group.key == 'pending' ? Icons.pending_actions : Icons.pause_circle_outline,
                              color: group.key == 'approved' ? Colors.green.shade700 : group.key == 'pending' ? Colors.deepOrange.shade700 : Colors.grey.shade700),
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
                                            'contactEmail':
                                                'Kontaktisiku e-post',
                                            'organizationEmail':
                                                'Ühingu e-post',
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
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final account in _accounts)
                        Card(
                          child: ExpansionTile(
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
                              OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _revoke(account),
                                child: const Text(
                                  'Tühista sisselogimisseansid',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_accountsLoaded || _pageToken != null)
                        OutlinedButton(
                          onPressed: _saving ? null : _loadAccounts,
                          child: Text(
                            _accountsLoaded
                                ? 'Laadi järgmised kontod'
                                : 'Laadi kasutajakontod',
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Viimased 100 olulist muudatust'),
                      for (final event in maps(_data?['audit']))
                        ListTile(
                          title: Text(
                            '${event['action']} · ${event['targetId']}',
                          ),
                          subtitle: Text(
                            '${event['createdAt']}\nMuutja: ${event['createdBy']}\nÜhing: ${event['organizationId'] ?? 'Platvorm'}${event['changedFields'] == null ? '' : '\nVäljad: ${(event['changedFields'] as List).join(', ')}'}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
