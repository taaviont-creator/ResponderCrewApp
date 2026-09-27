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
      if (snapshot.hasError)
        return const AppSectionCard(
          title: 'Alused',
          child: Text('Aluste seisundit ei õnnestunud laadida.'),
        );
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final vessels = snapshot.data!
          .where(
            (item) =>
                !item.isPersonal && item.category == EquipmentCategory.vessel,
          )
          .toList();
      if (vessels.isEmpty) return const SizedBox.shrink();
      const labels = {
        'ok': 'Korras',
        'needsMaintenance': 'Vajab hooldust',
        'broken': 'Rikkis',
        'outOfService': 'Kasutusest väljas',
      };
      return AppSectionCard(
        title: 'Aluste seisund',
        leading: const Icon(Icons.sailing_outlined),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final vessel in vessels)
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
