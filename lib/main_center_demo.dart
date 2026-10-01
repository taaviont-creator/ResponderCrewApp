// Separate entry point: no Firebase initialization, login bypass or production writes.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/center_context.dart';
import 'services/center_board_service.dart';
import 'screens/center_workspace_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixtures =
      jsonDecode(await rootBundle.loadString('assets/center-demo.json'))
          as Map<String, dynamic>;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RespondCrew · keskuste proovivaade',
      theme: AppTheme.maritime,
      home: CenterDemo(fixtures: fixtures),
    ),
  );
}

class CenterDemo extends StatefulWidget {
  const CenterDemo({
    super.key,
    required this.fixtures,
    this.tilesEnabled = true,
  });
  final Map<String, dynamic> fixtures;
  final bool tilesEnabled;
  @override
  State<CenterDemo> createState() => _CenterDemoState();
}

class _CenterDemoState extends State<CenterDemo> {
  String _service = 'sar', _scenario = 'normal';
  bool _offline = false;
  late CenterBoardService _board = _create();
  CenterBoardService _create() {
    final service = _service;
    return CenterBoardService(
      load: () async {
        if (_offline) throw Exception('Simulated offline');
        final at = DateTime.now().millisecondsSinceEpoch;
        final rows = (widget.fixtures[_scenario] as Map)[service] as List;
        return {
          'serverNowMs': at,
          'items': [
            for (final source in rows)
              {
                ...Map<String, dynamic>.from(source as Map),
                for (final key in [
                  'computedAtMs',
                  'confirmedAtMs',
                  'freshUntilMs',
                  'expectedReadyAtMs',
                ])
                  key: source[key] is num
                      ? at + (source[key] as num).toInt()
                      : null,
              },
          ],
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xffffe5bc),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROOVIREŽIIM · Väljamõeldud ühingud ja asukohad. Pärisandmeid ei muudeta.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 'sar',
                          label: Text('Merevalvekeskus'),
                        ),
                        ButtonSegment(
                          value: 'tross',
                          label: Text('Trossi keskus'),
                        ),
                      ],
                      selected: {_service},
                      onSelectionChanged: (value) => setState(() {
                        _service = value.first;
                        _board = _create();
                      }),
                    ),
                    SizedBox(
                      width: 280,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _scenario,
                        items:
                            const {
                                  'normal': 'Katse: tavapärane valmidus',
                                  'absence': 'Algab planeeritud mittevalve',
                                  'delay': 'Kinnitatud viivitus',
                                  'paused': 'Ühing valvest maas',
                                  'broken': 'Alus läheb rikki',
                                  'expired': 'Valmiduskinnitus aegub',
                                }.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() => _scenario = value!);
                          _board.refresh();
                        },
                      ),
                    ),
                    FilterChip(
                      label: const Text('Katkesta ühendus'),
                      selected: _offline,
                      onSelected: (value) {
                        setState(() => _offline = value);
                        _board.refresh();
                      },
                    ),
                  ],
                ),
                const Text(
                  'Ainult katsetamiseks: olukorra valik muudab „Näidis · Põhjarannik” näidisandmeid. Päris töövaates seda valikut ei ole.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: CenterWorkspaceScreen(
              key: ValueKey(_service),
              center: CenterContext.fromMap({
                'centerId': _service == 'sar' ? 'merevalvekeskus' : 'tross',
                'service': _service,
              })!,
              service: _board,
              demo: true,
              tilesEnabled: widget.tilesEnabled,
            ),
          ),
        ],
      ),
    ),
  );
}
