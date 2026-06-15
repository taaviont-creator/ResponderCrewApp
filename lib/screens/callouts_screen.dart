import 'package:flutter/material.dart';

import '../models/callout_model.dart';
import '../services/callout_service.dart';

class CalloutsScreen extends StatefulWidget {
  const CalloutsScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canManageCallouts,
    this.openCreateOnLoad = false,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final bool canManageCallouts;
  final bool openCreateOnLoad;

  @override
  State<CalloutsScreen> createState() => _CalloutsScreenState();
}

class _CalloutsScreenState extends State<CalloutsScreen> {
  final _calloutService = CalloutService();

  @override
  void initState() {
    super.initState();
    if (widget.canManageCallouts && widget.openCreateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddCalloutDialog();
      });
    }
  }

  Future<void> _showAddCalloutDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    var selectedPriority = CalloutPriority.normal;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Lisa valjakutse'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Pealkiri'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Kirjeldus'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Asukoht'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPriority,
                    decoration: const InputDecoration(labelText: 'Prioriteet'),
                    items: CalloutPriority.values.map((priority) {
                      return DropdownMenuItem<String>(
                        value: priority,
                        child: Text(_priorityLabel(priority)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedPriority = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Katkesta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lisa'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true) return;

    try {
      await _calloutService.addCallout(
        organizationId: widget.organizationId,
        title: titleController.text,
        description: descriptionController.text,
        location: locationController.text,
        priority: selectedPriority,
        createdBy: widget.currentUid,
        createdByName: widget.currentUserName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valjakutse lisatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Valjakutse lisamine ebaonnestus: $e')),
      );
    }
  }

  Future<void> _showDelayedResponseDialog(CalloutModel callout) async {
    var selectedMinutes = 15;
    final noteController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Hilinen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedMinutes,
                  decoration: const InputDecoration(labelText: 'Aeg'),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 min')),
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                    DropdownMenuItem(value: 60, child: Text('60 min')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedMinutes = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Markus'),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Katkesta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvesta'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldSave != true) return;

    await _setResponse(
      callout: callout,
      response: CalloutResponseValue.delayed,
      responseMinutes: selectedMinutes,
      note: noteController.text,
    );
  }

  Future<void> _setResponse({
    required CalloutModel callout,
    required String response,
    int? responseMinutes,
    String note = '',
  }) async {
    try {
      await _calloutService.setMyResponse(
        calloutId: callout.id,
        userId: widget.currentUid,
        userName: widget.currentUserName,
        organizationId: widget.organizationId,
        response: response,
        responseMinutes: responseMinutes,
        note: note,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vastus salvestatud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vastuse salvestamine ebaonnestus: $e')),
      );
    }
  }

  Future<void> _updateCalloutStatus({
    required CalloutModel callout,
    required String status,
  }) async {
    if (!widget.canManageCallouts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sul puudub õigus väljakutset lõpetada'),
        ),
      );
      return;
    }

    final isClosing = status == CalloutStatus.closed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isClosing ? 'Lõpeta väljakutse' : 'Tühista väljakutse',
        ),
        content: Text(
          isClosing
              ? 'Kas soovid väljakutse "${callout.title}" lõpetada?'
              : 'Kas soovid väljakutse "${callout.title}" tühistada?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Katkesta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isClosing ? 'Lõpeta' : 'Tühista'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _calloutService.updateCalloutStatus(
        calloutId: callout.id,
        organizationId: widget.organizationId,
        status: status,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClosing
                ? 'Väljakutse lõpetatud'
                : 'Väljakutse tühistatud',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Väljakutse uuendamine ebaõnnestus: $e')),
      );
    }
  }

  Widget _buildResponseControls(CalloutModel callout) {
    return StreamBuilder<CalloutResponseModel?>(
      stream: _calloutService.streamMyResponse(
        calloutId: callout.id,
        userId: widget.currentUid,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final response = snapshot.data?.response;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tulen'),
              selected: response == CalloutResponseValue.responding,
              onSelected: (_) => _setResponse(
                callout: callout,
                response: CalloutResponseValue.responding,
              ),
            ),
            ChoiceChip(
              label: const Text('Hilinen'),
              selected: response == CalloutResponseValue.delayed,
              onSelected: (_) => _showDelayedResponseDialog(callout),
            ),
            ChoiceChip(
              label: const Text('Ei saa tulla'),
              selected: response == CalloutResponseValue.unavailable,
              onSelected: (_) => _setResponse(
                callout: callout,
                response: CalloutResponseValue.unavailable,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminResponseCounts(CalloutModel callout) {
    return StreamBuilder<CalloutResponseDetails>(
      stream: _calloutService.streamCalloutResponseDetails(
        calloutId: callout.id,
        organizationId: widget.organizationId,
      ),
      builder: (context, snapshot) {
        final details = snapshot.data;
        if (details == null) return const SizedBox.shrink();
        final summary = details.summary;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vastajad',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('Tuleb: ${summary.responding}'),
                  Text('Hilineb: ${summary.delayed}'),
                  Text('Ei saa tulla: ${summary.unavailable}'),
                  Text('Vastamata: ${summary.noResponse}'),
                  Text('Kokku vastanud: ${summary.totalResponded}'),
                ],
              ),
              if (summary.totalResponded == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Vastuseid pole veel'),
                ),
              _buildResponseGroup('Tuleb', details.responding),
              _buildResponseGroup(
                'Hilineb',
                details.delayed,
                showDelay: true,
              ),
              _buildResponseGroup('Ei saa tulla', details.unavailable),
              _buildResponseGroup('Vastamata', details.noResponse),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResponseGroup(
    String label,
    List<CalloutResponseMember> members, {
    bool showDelay = false,
  }) {
    final memberLabels = members.map((member) {
      if (showDelay && member.responseMinutes != null) {
        return '${member.displayName} (${member.responseMinutes} min)';
      }
      return member.displayName;
    }).join(', ');

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$label: ${memberLabels.isEmpty ? '-' : memberLabels}'),
    );
  }

  Widget _buildCalloutTile(CalloutModel callout) {
    final isActive = callout.status == CalloutStatus.active;
    final subtitleParts = [
      _statusLabel(callout.status),
      _priorityLabel(callout.priority),
      if (callout.location.isNotEmpty) callout.location,
      if (callout.createdByName.isNotEmpty) callout.createdByName,
      if (callout.createdAt != null) _shortDateTime(callout.createdAt!),
      if (!isActive && callout.closedAt != null)
        'Lõpetatud ${_shortDateTime(callout.closedAt!)}',
    ];

    return Opacity(
      opacity: isActive ? 1 : 0.7,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _statusIcon(callout.status),
              ),
              title: Text(callout.title),
              subtitle: Text(
                callout.description.isEmpty
                    ? subtitleParts.join(' - ')
                    : '${subtitleParts.join(' - ')}\n${callout.description}',
              ),
              trailing: widget.canManageCallouts && isActive
                  ? PopupMenuButton<String>(
                      onSelected: (value) => _updateCalloutStatus(
                        callout: callout,
                        status: value,
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: CalloutStatus.closed,
                          child: Text('Lõpeta väljakutse'),
                        ),
                        PopupMenuItem(
                          value: CalloutStatus.cancelled,
                          child: Text('Tühista väljakutse'),
                        ),
                      ],
                    )
                  : null,
            ),
            if (isActive) _buildResponseControls(callout),
            if (widget.canManageCallouts) _buildAdminResponseCounts(callout),
          ],
        ),
      ),
    );
  }

  Widget _buildCalloutSection({
    required String title,
    required List<CalloutModel> callouts,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (callouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyText),
          )
        else
          ...callouts.map((callout) => Column(
                children: [
                  _buildCalloutTile(callout),
                  const Divider(height: 1),
                ],
              )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valjakutsed'),
      ),
      floatingActionButton: widget.canManageCallouts
          ? FloatingActionButton(
              onPressed: _showAddCalloutDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<CalloutModel>>(
        stream: _calloutService.streamOrganizationCallouts(
          organizationId: widget.organizationId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Valjakutsete laadimine ebaonnestus: ${snapshot.error}',
              ),
            );
          }

          final callouts = snapshot.data ?? const <CalloutModel>[];
          final activeCallouts = callouts
              .where((callout) => callout.status == CalloutStatus.active)
              .toList(growable: false);
          final completedCallouts = callouts
              .where((callout) => callout.status != CalloutStatus.active)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCalloutSection(
                title: 'Aktiivsed väljakutsed',
                callouts: activeCallouts,
                emptyText: 'Aktiivseid väljakutseid ei ole',
              ),
              const SizedBox(height: 24),
              _buildCalloutSection(
                title: 'Lõpetatud väljakutsed',
                callouts: completedCallouts,
                emptyText: 'Lõpetatud väljakutseid ei ole',
              ),
            ],
          );
        },
      ),
    );
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case CalloutPriority.low:
        return 'Madal';
      case CalloutPriority.high:
        return 'Kõrge';
      case CalloutPriority.critical:
        return 'Kriitiline';
      default:
        return 'Tavaline';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case CalloutStatus.closed:
        return 'Lõpetatud';
      case CalloutStatus.cancelled:
        return 'Tühistatud';
      default:
        return 'Aktiivne';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case CalloutStatus.closed:
        return Icons.check_circle_outline;
      case CalloutStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.campaign;
    }
  }

  String _shortDateTime(DateTime value) {
    final date = '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final time = '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
