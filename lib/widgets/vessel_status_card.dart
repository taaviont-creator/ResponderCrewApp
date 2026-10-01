import 'package:flutter/material.dart';
import '../models/equipment_model.dart';
import '../services/equipment_service.dart';
import 'app_section_card.dart';

class VesselStatusCard extends StatefulWidget {
  const VesselStatusCard({super.key, required this.organizationId});
  final String organizationId;
  @override
  State<VesselStatusCard> createState() => _VesselStatusCardState();
}

class _VesselStatusCardState extends State<VesselStatusCard> {
  late Stream<List<EquipmentModel>> _stream;
  void _subscribe() => _stream = EquipmentService().streamOrganizationEquipment(
    organizationId: widget.organizationId,
  );
  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(VesselStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) _subscribe();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<EquipmentModel>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const AppSectionCard(
          title: 'Alused',
          child: Text('Aluste seisundit ei õnnestunud laadida.'),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final vessels =
          snapshot.data!
              .where(
                (item) =>
                    !item.isPersonal &&
                    (item.category == EquipmentCategory.vessel ||
                        item.status != EquipmentStatus.ok),
              )
              .toList()
            ..sort(
              (a, b) => (a.status == EquipmentStatus.ok ? 1 : 0).compareTo(
                b.status == EquipmentStatus.ok ? 1 : 0,
              ),
            );
      if (vessels.isEmpty) return const SizedBox.shrink();
      const labels = {
        'ok': 'Korras',
        'needsMaintenance': 'Vajab hooldust',
        'broken': 'Rikkis',
        'outOfService': 'Kasutusest väljas',
      };
      return AppSectionCard(
        title: 'Aluste ja varustuse seisund',
        leading: const Icon(Icons.sailing_outlined),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vessels.length > 3)
              Text('${vessels.length} alust või hoiatust · kuvatakse 3'),
            for (final vessel in vessels.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${vessel.name}: ${labels[vessel.status] ?? 'Seisund teadmata'}',
                ),
              ),
          ],
        ),
      );
    },
  );
}
