import '../widgets/app_layout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class CenterSharingScreen extends StatefulWidget {
  const CenterSharingScreen({
    super.key,
    this.organizationId,
    this.call,
    this.embedded = false,
    this.pendingOnly = false,
  });
  final String? organizationId;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  call;
  final bool embedded, pendingOnly;
  @override
  State<CenterSharingScreen> createState() => _CenterSharingScreenState();
}

class _CenterSharingScreenState extends State<CenterSharingScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _busy = true;
  bool? _positionReady;
  String? _error;
  bool get _platform => widget.organizationId == null;
  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, dynamic> data,
  ) async {
    if (widget.call != null) return widget.call!(method, data);
    final result = await FirebaseFunctions.instanceFor(
      region: 'europe-north1',
    ).httpsCallable(method).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _call(
        _platform ? 'getCenterSharingRequests' : 'getOrganizationCenterSharing',
        {if (!_platform) 'organizationId': widget.organizationId},
      );
      if (mounted) {
        _positionReady = data['positionReady'] as bool?;
        _entries = (data['entries'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      if (mounted) {
        _error =
            'Jagamise seadete laadimine ebaõnnestus. Kontrolli ühendust ja õigust.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(Map<String, dynamic> row, bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _call(
        _platform
            ? 'reviewOrganizationCenterSharing'
            : 'setOrganizationCenterSharing',
        {
          'organizationId': widget.organizationId ?? row['organizationId'],
          'centerId': row['centerId'],
          'enabled': enabled,
          'expectedRevision': row['revision'],
        },
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        _error = e is FirebaseFunctionsException
            ? e.message ?? 'Salvestamine ebaõnnestus.'
            : 'Salvestamine ebaõnnestus.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_platform && _positionReady == false)
          const Text(
            'Kaardipunkt puudub: salvesta ühingu asukoht ülal. Ühing võib seni olla keskuse nimekirjas.',
          ),
        Text(
          _platform
              ? 'Kinnita ühingu taotlus pärast keskusega kokkuleppe kontrollimist. See ei anna keskuse kasutajatele adminiõigusi.'
              : 'Jaga ühingu nime, kinnitatud baasi asukohta, valmiduse koondinfot, aluseid ja eraldi sisestatud valvekontakti. Liikmete nimesid ega isiklikke planeeringuid ei jagata. Taotluse kinnitab platvormihaldur.',
        ),
        if (!_platform)
          const Text(
            'Salvesta esmalt teenuste ja asukoha seaded. Jagamise peatamine lõpetab ligipääsu järgmisel serveripäringul.',
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final row in _entries.where(
          (e) => !widget.pendingOnly || e['approved'] != true,
        ))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['name'] as String? ?? 'Ühing',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_platform)
                    Text(
                      row['centerId'] == 'tross'
                          ? 'Trossi keskus'
                          : 'Merevalvekeskus',
                    ),
                  Text(
                    row['approved'] == true
                        ? 'Jagamine kinnitatud'
                        : row['requested'] == false
                        ? 'Jagamine välja lülitatud'
                        : 'Platvormihalduri kinnituse ootel',
                  ),
                  if (_platform)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _change(row, row['approved'] != true),
                      child: Text(
                        row['approved'] == true
                            ? 'Peata jagamine'
                            : 'Kinnita jagamine',
                      ),
                    )
                  else
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Luban koondinfo jagamise'),
                      value: row['requested'] == true,
                      onChanged: _busy ? null : (value) => _change(row, value),
                    ),
                ],
              ),
            ),
          ),
        if (!_busy &&
            _entries
                .where((e) => !widget.pendingOnly || e['approved'] != true)
                .isEmpty &&
            _error == null)
          Text(
            widget.pendingOnly
                ? 'Ootel jagamistaotlusi pole.'
                : _platform
                ? 'Ühingud pole veel keskustega jagamist taotlenud.'
                : 'Keskuste seadeid ei leitud.',
          ),
      ],
    );
    if (widget.embedded) return content;
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Keskustega jagamine'),
        actions: [
          IconButton(
            tooltip: 'Värskenda',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }
}
