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
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Keskuste kaart')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Kaart uueneb ühingu valveoleku, meeskonna ja aluse seisundi järgi. Siin saad seadistada nähtavuse ja vajadusel muuta ühingu staatust.',
        ),
        const SizedBox(height: 12),
        OrganizationCenterReadinessScreen(
          key: ValueKey('status-$_revision'),
          organizationId: widget.organizationId,
          embedded: true,
        ),
        Card(
          child: ExpansionTile(
            title: const Text('Kogu ühingu valve'),
            subtitle: const Text('Valvest maha võtmine muudab kaardi punaseks'),
            children: [
              OrganizationDutyControl(
                organizationId: widget.organizationId,
                onSaved: _refresh,
              ),
            ],
          ),
        ),
        OrganizationMapLocationControl(
          organizationId: widget.organizationId,
          onSaved: _refresh,
        ),
        Card(
          child: ExpansionTile(
            title: const Text('Teenused, alused ja kontakt'),
            subtitle: const Text('SAR ja Trossi mereabi tingimused'),
            children: [
              OrganizationResponseSettingsScreen(
                organizationId: widget.organizationId,
                embedded: true,
                onSaved: _refresh,
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: const Text('Aluste registriandmed'),
            subtitle: const Text('Teenuseks valitud aluste andmed'),
            children: [
              CenterResourcesScreen(
                organizationId: widget.organizationId,
                onSaved: _refresh,
                embedded: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Nähtavus keskustele',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        CenterSharingScreen(
          key: ValueKey('sharing-$_revision'),
          organizationId: widget.organizationId,
          embedded: true,
        ),
      ],
    ),
  );
}
