import '../widgets/app_layout.dart';
import 'package:flutter/material.dart';
import '../widgets/organization_map_location_control.dart';
import '../widgets/organization_duty_control.dart';
import 'center_resources_screen.dart';
import 'center_sharing_screen.dart';
import 'organization_center_readiness_screen.dart';
import 'organization_response_settings_screen.dart';

/// One organization-admin entry point; all sections reuse existing endpoints.
class OrganizationCenterSettingsScreen extends StatefulWidget {
  const OrganizationCenterSettingsScreen({
    super.key,
    required this.organizationId,
  });
  final String organizationId;
  @override
  State<OrganizationCenterSettingsScreen> createState() =>
      _OrganizationCenterSettingsScreenState();
}

class _OrganizationCenterSettingsScreenState
    extends State<OrganizationCenterSettingsScreen> {
  int _revision = 0;
  void _refresh() => setState(() => _revision++);
  int _tab = 0;
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
  @override
  Widget build(BuildContext context) => AppScaffold(
    contentMaxWidth: 850,
    appBar: AppBar(title: const Text('Keskuste kaart')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.settings_outlined),
                label: Text('Seadistus'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.radar),
                label: Text('Hetkeseis'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              ListView(
                key: const PageStorageKey('center-setup'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _heading('1. Asukoht'),
                  OrganizationMapLocationControl(
                    organizationId: widget.organizationId,
                    onSaved: _refresh,
                  ),
                  _heading('2. Teenused, alused ja kontakt'),
                  OrganizationResponseSettingsScreen(
                    organizationId: widget.organizationId,
                    embedded: true,
                    onSaved: _refresh,
                  ),
                  ExpansionTile(
                    title: const Text('Aluste registriandmed'),
                    subtitle: const Text(
                      'Vajadusel täienda juba valitud aluste andmeid',
                    ),
                    children: [
                      CenterResourcesScreen(
                        organizationId: widget.organizationId,
                        embedded: true,
                        onSaved: _refresh,
                      ),
                    ],
                  ),
                  _heading('3. Nähtavus keskustele'),
                  CenterSharingScreen(
                    key: ValueKey('sharing-$_revision'),
                    organizationId: widget.organizationId,
                    embedded: true,
                  ),
                ],
              ),
              ListView(
                key: const PageStorageKey('center-status'),
                padding: const EdgeInsets.all(16),
                children: [
                  OrganizationCenterReadinessScreen(
                    key: ValueKey('status-$_revision'),
                    organizationId: widget.organizationId,
                    embedded: true,
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _heading('Ühingu valve juhtimine'),
                          const Text(
                            'Valvest maha võtmine muudab kaardil mõlemad teenused punaseks.',
                          ),
                          OrganizationDutyControl(
                            organizationId: widget.organizationId,
                            onSaved: _refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
