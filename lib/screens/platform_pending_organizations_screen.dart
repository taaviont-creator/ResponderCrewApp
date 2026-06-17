import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/command_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';

class PlatformPendingOrganizationsScreen extends StatefulWidget {
  const PlatformPendingOrganizationsScreen({
    super.key,
    required this.isPlatformAdmin,
  });

  final bool isPlatformAdmin;

  @override
  State<PlatformPendingOrganizationsScreen> createState() =>
      _PlatformPendingOrganizationsScreenState();
}

class _PlatformPendingOrganizationsScreenState
    extends State<PlatformPendingOrganizationsScreen> {
  final _commandService = CommandService();
  String? _savingCommandId;

  Future<void> _reviewOrganization({
    required String commandId,
    required String creatorUserId,
    required bool approve,
  }) async {
    if (!widget.isPlatformAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sul puudub õigus ühinguid kinnitada.')),
      );
      return;
    }

    setState(() => _savingCommandId = commandId);

    try {
      if (approve) {
        await _commandService.approveCommand(
          commandId: commandId,
          creatorUserId: creatorUserId,
        );
      } else {
        await _commandService.rejectCommand(
          commandId: commandId,
          creatorUserId: creatorUserId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Ühing kinnitatud.' : 'Ühing tagasi lükatud.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ühingu ülevaatamine ebaõnnestus.')),
      );
    } finally {
      if (mounted) setState(() => _savingCommandId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlatformAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ootel ühingud')),
        body: const Center(
          child: Text('Sul puudub õigus ühinguid kinnitada.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ootel ühingud')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _commandService.streamPendingCommands(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Ootel ühingute laadimine ebaõnnestus.'),
            );
          }

          final organizations = snapshot.data?.docs ?? [];
          if (organizations.isEmpty) {
            return const Center(child: Text('Ootel ühinguid ei ole.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            itemCount: organizations.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTheme.itemSpacing),
            itemBuilder: (context, index) {
              final doc = organizations[index];
              final data = doc.data();
              final name = _stringValue(data['name'], fallback: 'Nimetu ühing');
              final createdBy = _stringValue(data['createdBy']);
              final createdAt = _formatTimestamp(data['createdAt']);
              final isSaving = _savingCommandId == doc.id;

              return AppSectionCard(
                title: name,
                subtitle: 'Staatus: pending',
                leading: const Icon(Icons.apartment_outlined),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Looja: ${createdBy.isEmpty ? 'teadmata' : createdBy}'),
                    const SizedBox(height: 4),
                    Text('Loodud: ${createdAt ?? 'teadmata'}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving || createdBy.isEmpty
                                ? null
                                : () => _reviewOrganization(
                                      commandId: doc.id,
                                      creatorUserId: createdBy,
                                      approve: false,
                                    ),
                            icon: const Icon(Icons.close),
                            label: const Text('Lükka tagasi'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSaving || createdBy.isEmpty
                                ? null
                                : () => _reviewOrganization(
                                      commandId: doc.id,
                                      creatorUserId: createdBy,
                                      approve: true,
                                    ),
                            icon: const Icon(Icons.check),
                            label: const Text('Kinnita'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String? _formatTimestamp(Object? value) {
    if (value is! Timestamp) return null;
    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute';
  }
}
