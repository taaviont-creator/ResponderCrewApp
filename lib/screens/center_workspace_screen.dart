import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/center_context.dart';
import '../models/center_board.dart';
import '../services/center_board_service.dart';

class CenterWorkspaceScreen extends StatefulWidget {
  const CenterWorkspaceScreen({
    super.key,
    required this.center,
    this.service,
    this.demo = false,
    this.tilesEnabled = true,
  });
  final CenterContext center;
  final CenterBoardService? service;
  final bool demo, tilesEnabled;
  @override
  State<CenterWorkspaceScreen> createState() => _CenterWorkspaceScreenState();
}

class _CenterWorkspaceScreenState extends State<CenterWorkspaceScreen>
    with WidgetsBindingObserver {
  late final _service =
      widget.service ?? CenterBoardService.firebase(widget.center.centerId);
  final _map = MapController();
  final _search = TextEditingController();
  CenterReadinessStatus? _filter;
  String? _selectedId;
  bool _mapReady = false, _tileError = false;
  int _tileRevision = 0;
  String? _fittedPositions;
  static const _tileUrl = String.fromEnvironment(
    'CENTER_MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const _attribution = String.fromEnvironment(
    'CENTER_MAP_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );
  static const _attributionUrl = String.fromEnvironment(
    'CENTER_MAP_ATTRIBUTION_URL',
    defaultValue: 'https://www.openstreetmap.org/copyright',
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _service.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  CenterReadinessStatus _status(CenterBoardItem row) =>
      row.effectiveStatus(_service.now, connected: _service.freshConnection);
  Color _color(CenterReadinessStatus s) => switch (s) {
    CenterReadinessStatus.ready => const Color(0xff08784f),
    CenterReadinessStatus.delayed => const Color(0xffa36500),
    CenterReadinessStatus.unavailable => const Color(0xffb42318),
    CenterReadinessStatus.unknown => const Color(0xff64748b),
  };
  IconData _icon(CenterReadinessStatus s) => switch (s) {
    CenterReadinessStatus.ready => Icons.check_circle,
    CenterReadinessStatus.delayed => Icons.schedule,
    CenterReadinessStatus.unavailable => Icons.cancel,
    CenterReadinessStatus.unknown => Icons.help,
  };
  String _time(DateTime? at) {
    if (at == null) return 'Puudub';
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  void _select(CenterBoardItem item, {bool move = true}) {
    setState(() => _selectedId = item.id);
    if (move && item.hasPosition && _mapReady) {
      _map.move(LatLng(item.latitude!, item.longitude!), 9);
    }
  }

  Widget _badge(CenterReadinessStatus status) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(_icon(status), size: 18, color: _color(status)),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          status.label,
          style: TextStyle(color: _color(status), fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
  Widget _row(CenterBoardItem item) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: _selectedId == item.id
            ? Theme.of(context).colorScheme.primary
            : const Color(0xffdce3e9),
        width: _selectedId == item.id ? 2 : 1,
      ),
    ),
    child: InkWell(
      key: ValueKey('unit-${item.id}'),
      onTap: () => _select(item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 7),
            _badge(_status(item)),
            const SizedBox(height: 5),
            Text(
              'Valves ${item.onDutyCount ?? '?'}/${item.minimum ?? '?'}${widget.center.service == 'sar' ? ' · II aste ${item.secondLevelCount ?? '?'}' : ''}',
            ),
            if (!item.hasPosition)
              const Text(
                'Asukoha koordinaadid puuduvad',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _details(CenterBoardItem? item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: item == null
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.touch_app_outlined, size: 28),
                SizedBox(height: 12),
                Text(
                  'Vali ühing',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Vajuta kaardipunktil või ühingul nimekirjas, et näha valmiduse põhjuseid, aluseid ja valvekontakti.',
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _badge(_status(item)),
                const SizedBox(height: 12),
                if (!_service.freshConnection ||
                    item.freshUntil == null ||
                    !item.freshUntil!.isAfter(_service.now))
                  const Text(
                    'Viimati laaditud andmed on aegunud või ühendus puudub. Hetkevalmidus ei ole kinnitatud.',
                  ),
                for (final reason in item.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(reason),
                  ),
                if (item.restrictionReason.isNotEmpty)
                  Text(item.restrictionReason),
                const Divider(),
                Text(
                  'Valves: ${item.onDutyCount ?? '?'} / ${item.minimum ?? '?'}',
                ),
                if (widget.center.service == 'sar')
                  Text('II astmega valves: ${item.secondLevelCount ?? '?'}'),
                Text(
                  'Väljasõidu sihtaeg: ${item.departureMinutes == null ? 'seadistamata' : '${item.departureMinutes} min'}',
                ),
                if (item.expectedReadyAt != null)
                  Text(
                    'Kinnitatud väljasõiduvalmidus: ${_time(item.expectedReadyAt)}',
                  ),
                const Text(
                  'Näidatakse väljasõiduvalmidust, mitte sündmuskohale saabumise aega.',
                  style: TextStyle(fontSize: 12),
                ),
                const Divider(),
                Text('Alused', style: Theme.of(context).textTheme.titleMedium),
                if (item.vessels.isEmpty) const Text('Alused pole määratud.'),
                for (final vessel in item.vessels)
                  Text(
                    '${vessel['name'] ?? 'Alus'} · ${switch (vessel['status']) {
                      'ok' => 'korras',
                      'broken' => 'rikkis',
                      'outOfService' => 'kasutusest väljas',
                      'needsMaintenance' => 'vajab hooldust',
                      _ => 'seisund teadmata',
                    }}',
                  ),
                const Divider(),
                Text(
                  item.contactName.isEmpty ? 'Valvekontakt' : item.contactName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (item.contactPhone.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        launchUrl(Uri(scheme: 'tel', path: item.contactPhone)),
                    icon: const Icon(Icons.phone_outlined),
                    label: Text(item.contactPhone),
                  )
                else
                  const Text('Telefon pole lisatud.'),
                if (item.hasPosition)
                  Text(
                    'Baasi asukoht: ${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
                  )
                else
                  const Text(
                    'Korrektsed koordinaadid puuduvad. Ühingu admin saab need lisada ühingu seadetes.',
                  ),
                const Divider(),
                Text('Arvutatud: ${_time(item.computedAt)}'),
                Text(
                  item.automatic
                      ? 'Staatus ühingu andmete järgi'
                      : 'Admin muutis staatust: ${_time(item.confirmedAt)}',
                ),
                const Text(
                  'Ajad sinu seadme ajavööndis.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    ),
  );
  void _fitMarkers(List<CenterBoardItem> rows, {bool force = false}) {
    final points = rows.where((r) => r.hasPosition).toList();
    final signature = points
        .map((p) => '${p.id}:${p.latitude}:${p.longitude}')
        .join('|');
    if (!_mapReady ||
        points.isEmpty ||
        (!force && _fittedPositions == signature)) {
      return;
    }
    _fittedPositions = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      if (points.length == 1) {
        _map.move(LatLng(points.single.latitude!, points.single.longitude!), 9);
      } else {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(
              points.map((p) => LatLng(p.latitude!, p.longitude!)).toList(),
            ),
            padding: const EdgeInsets.all(56),
            maxZoom: 10,
          ),
        );
      }
    });
  }

  Widget _mapWidget(List<CenterBoardItem> rows) {
    _fitMarkers(rows);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: const LatLng(58.8, 25.1),
              initialZoom: 7,
              minZoom: 5,
              maxZoom: 16,
              onMapReady: () {
                _mapReady = true;
                _fitMarkers(rows);
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              if (widget.tilesEnabled)
                TileLayer(
                  key: ValueKey(_tileRevision),
                  urlTemplate: _tileUrl,
                  userAgentPackageName: 'ee.respondcrew.app',
                  errorTileCallback: (_, _, _) {
                    if (!_tileError && mounted) {
                      Future.microtask(() {
                        if (mounted) setState(() => _tileError = true);
                      });
                    }
                  },
                ),
              MarkerLayer(
                markers: [
                  for (final item in rows.where((r) => r.hasPosition))
                    Marker(
                      point: LatLng(item.latitude!, item.longitude!),
                      width: 48,
                      height: 48,
                      key: ValueKey('marker-${item.id}'),
                      child: Tooltip(
                        message: '${item.name}: ${_status(item).label}',
                        child: Semantics(
                          button: true,
                          label: 'Kaardil ${item.name}',
                          child: InkWell(
                            onTap: () => _select(item, move: false),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _color(_status(item)),
                                  width: _selectedId == item.id ? 4 : 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _icon(_status(item)),
                                color: _color(_status(item)),
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () => launchUrl(Uri.parse(_attributionUrl)),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        '© $_attribution',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(10),
              child: Column(
                children: [
                  IconButton(
                    tooltip: 'Suurenda kaarti',
                    onPressed: () {
                      if (_mapReady) {
                        _map.move(
                          _map.camera.center,
                          (_map.camera.zoom + 1).clamp(5, 16),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Vähenda kaarti',
                    onPressed: () {
                      if (_mapReady) {
                        _map.move(
                          _map.camera.center,
                          (_map.camera.zoom - 1).clamp(5, 16),
                        );
                      }
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: 'Näita kõiki ühinguid',
                    onPressed: () {
                      if (_mapReady) {
                        if (rows.any((r) => r.hasPosition)) {
                          _fitMarkers(rows, force: true);
                        } else {
                          _map.move(const LatLng(58.8, 25.1), 7);
                        }
                      }
                    },
                    icon: const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),
          ),
          if (_tileError)
            Positioned(
              left: 8,
              right: 68,
              top: 8,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Aluskaardi laadimine on häiritud. Ühingute nimekiri ja punktid töötavad edasi.',
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _tileError = false;
                          _tileRevision++;
                        }),
                        child: const Text('Proovi kaarti uuesti'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _service,
    builder: (context, _) {
      final query = _search.text.trim().toLowerCase();
      final rows = _service.items
          .where(
            (r) =>
                r.name.toLowerCase().contains(query) &&
                (_filter == null || _status(r) == _filter),
          )
          .toList();
      final selected = rows.where((r) => r.id == _selectedId).firstOrNull;
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.center.name),
          actions: [
            IconButton(
              tooltip: 'Uuenda andmeid',
              onPressed: _service.loading ? null : _service.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final header = <Widget>[
                if (!widget.demo)
                  const Text(
                    'Väljasõiduvalmidus · Andmed uuenevad automaatselt. Värv ei näita sündmuskohale saabumise aega.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      _service.freshConnection
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      size: 18,
                    ),
                    Text(
                      _service.loading
                          ? 'Uuendan andmeid…'
                          : _service.freshConnection
                          ? 'Ühendus olemas'
                          : 'Ühendus puudub või kontrollimata',
                    ),
                    Text('Viimati laaditud: ${_time(_service.checkedAt)}'),
                  ],
                ),
                if (_service.error != null)
                  Text(
                    _service.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Otsi ühingut',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: Text('Kõik (${_service.items.length})'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    for (final status in CenterReadinessStatus.values)
                      FilterChip(
                        avatar: Icon(
                          _icon(status),
                          size: 17,
                          color: _color(status),
                        ),
                        label: Text(
                          '${status.label} (${_service.items.where((r) => _status(r) == status).length})',
                        ),
                        selected: _filter == status,
                        onSelected: (_) => setState(
                          () => _filter = _filter == status ? null : status,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ];
              final empty = Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _service.loading
                      ? 'Laadin ühinguid…'
                      : _service.items.isEmpty
                      ? 'Jagamiseks lubatud ühinguid pole. Ühingu admin lubab jagamise: Ühingu seaded → Keskuste kaart ja platvormihaldur kinnitab selle.'
                      : 'Filtrile vastavaid ühinguid ei ole.',
                ),
              );
              if (constraints.maxWidth < 1050 || constraints.maxHeight < 450) {
                return ListView(
                  children: [
                    ...header,
                    SizedBox(height: 340, child: _mapWidget(rows)),
                    const SizedBox(height: 8),
                    if (selected != null) _details(selected),
                    if (rows.isEmpty) empty else ...rows.map(_row),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...header,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 285,
                          child: rows.isEmpty
                              ? empty
                              : ListView(children: rows.map(_row).toList()),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _mapWidget(rows)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 300,
                          child: SingleChildScrollView(
                            child: _details(selected),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
