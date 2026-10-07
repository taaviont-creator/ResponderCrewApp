import '../widgets/app_layout.dart';
import '../widgets/callout_link_opener.dart';
import '../widgets/callout_list_view.dart';
import 'package:flutter/material.dart';

import '../models/callout_model.dart';
import '../widgets/create_callout_dialog.dart';
import '../services/callout_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/status_badge.dart';
import 'callout_detail_screen.dart';

class CalloutsScreen extends StatefulWidget {
  const CalloutsScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.currentUserName,
    required this.canManageCallouts,
    required this.canCloseCallouts,
    required this.canStartOperationLog,
    this.openCreateOnLoad = false,
    this.initialCalloutId,
    this.onInitialCalloutOpened,
  });

  final String organizationId;
  final String currentUid;
  final String currentUserName;
  final bool canManageCallouts;
  final bool canCloseCallouts;
  final bool canStartOperationLog;
  final bool openCreateOnLoad;
  final String? initialCalloutId;
  final VoidCallback? onInitialCalloutOpened;

  @override
  State<CalloutsScreen> createState() => _CalloutsScreenState();
}

class _CalloutsScreenState extends State<CalloutsScreen> {
  final _calloutService = CalloutService();
  late var _stream = _calloutService.streamOrganizationCallouts(
    organizationId: widget.organizationId,
  );
  @override
  void initState() {
    super.initState();
    if (widget.canManageCallouts && widget.openCreateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddCalloutDialog();
      });
    }
  }

  @override
  void didUpdateWidget(CalloutsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) {
      _stream = _calloutService.streamOrganizationCallouts(
        organizationId: widget.organizationId,
      );
    }
  }

  Future<void> _showAddCalloutDialog() async {
    if (widget.organizationId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Väljakutse loomiseks vali aktiivne ühing'),
        ),
      );
      return;
    }

    String? createdId;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateCalloutDialog(
        onSave: (draft) async {
          createdId = await _calloutService.addCallout(
            organizationId: widget.organizationId,
            isTest: draft.isTest,
            title: draft.title,
            description: draft.description,
            location: draft.location,
            priority: draft.priority,
            calloutType: draft.type,
            phoneCenterId: draft.phoneCenterId,
            responseTargetMinutes: draft.responseTargetMinutes,
            createdBy: widget.currentUid,
            createdByName: widget.currentUserName,
          );
        },
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Väljakutse loodud. Meeskonna teavitamine käivitati.'),
        ),
      );
      if (createdId != null) {
        try {
          final callout = await _calloutService.getCallout(
            organizationId: widget.organizationId,
            calloutId: createdId!,
          );
          if (mounted && callout != null) _openCallout(callout);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Väljakutse on loodud. Ava see aktiivsete väljakutsete nimekirjast.',
                ),
              ),
            );
          }
        }
      }
    }
  }

  void _openCallout(CalloutModel callout) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CalloutDetailScreen(
          callout: callout,
          organizationId: widget.organizationId,
          currentUid: widget.currentUid,
          currentUserName: widget.currentUserName,
          canManageCallouts: widget.canManageCallouts,
          canCloseCallouts: widget.canCloseCallouts,
          canStartOperationLog: widget.canStartOperationLog,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CalloutLinkOpener(
      organizationId: widget.organizationId,
      calloutId: widget.initialCalloutId,
      load: (org, id) =>
          _calloutService.getCallout(organizationId: org, calloutId: id),
      onOpened: widget.onInitialCalloutOpened,
      detailBuilder: (callout) => CalloutDetailScreen(
        callout: callout,
        organizationId: widget.organizationId,
        currentUid: widget.currentUid,
        currentUserName: widget.currentUserName,
        canManageCallouts: widget.canManageCallouts,
        canCloseCallouts: widget.canCloseCallouts,
        canStartOperationLog: widget.canStartOperationLog,
      ),
      child: AppScaffold(
        appBar: AppBar(title: const Text('Väljakutsed')),
        floatingActionButton: widget.canManageCallouts
            ? FloatingActionButton.extended(
                onPressed: _showAddCalloutDialog,
                icon: const Icon(Icons.add),
                label: const Text('Loo väljakutse'),
              )
            : null,
        body: StreamBuilder<List<CalloutModel>>(
          stream: _stream,
          builder: (context, snapshot) {
            return CalloutListView(
              key: ValueKey(widget.organizationId),
              loading: snapshot.connectionState == ConnectionState.waiting,
              error: snapshot.hasError
                  ? 'Väljakutsete laadimine ebaõnnestus.'
                  : null,
              onRetry: () => setState(() {
                _stream = _calloutService.streamOrganizationCallouts(
                  organizationId: widget.organizationId,
                );
              }),
              callouts: snapshot.data ?? const <CalloutModel>[],
              itemBuilder: (callout) => _CalloutCard(
                callout: callout,
                organizationId: widget.organizationId,
                currentUid: widget.currentUid,
                calloutService: _calloutService,
                canViewResponseSummary: widget.canManageCallouts,
                onTap: () => _openCallout(callout),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CalloutCard extends StatelessWidget {
  const _CalloutCard({
    required this.callout,
    required this.organizationId,
    required this.currentUid,
    required this.calloutService,
    required this.canViewResponseSummary,
    required this.onTap,
  });

  final CalloutModel callout;
  final String organizationId;
  final String currentUid;
  final CalloutService calloutService;
  final bool canViewResponseSummary;
  final VoidCallback onTap;

  bool get _isActive => callout.status == CalloutStatus.active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ava väljakutse ${callout.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: AppSectionCard(
          accentColor: _calloutAccentColor(callout),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (callout.isTest)
                    const StatusBadge(
                      label: 'PROOVIHÄIRE',
                      type: StatusBadgeType.neutral,
                      icon: Icons.science_outlined,
                    ),
                  StatusBadge(
                    label: _priorityLabel(callout.priority),
                    type: _calloutPriorityBadgeType(callout),
                    icon: _calloutPriorityIcon(callout),
                  ),
                  StatusBadge(
                    label: _statusLabel(callout.status),
                    type: _statusBadgeType(callout.status),
                  ),
                  if (callout.effectiveStartedAt != null)
                    Text(
                      _shortDateTime(callout.effectiveStartedAt!),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                callout.title == CalloutType.label(callout.calloutType)
                    ? callout.title
                    : '${CalloutType.label(callout.calloutType)} · ${callout.title}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (callout.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        callout.location,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildMyResponse(context)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (canViewResponseSummary) ...[
                const SizedBox(height: 10),
                _buildResponseSummary(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyResponse(BuildContext context) {
    return StreamBuilder<CalloutResponseModel?>(
      stream: calloutService.streamMyResponse(
        calloutId: callout.id,
        userId: currentUid,
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        final response = snapshot.data;
        if (!_isActive && response == null) {
          return Text(
            'Vastus puudub',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          );
        }

        return StatusBadge(
          label: _responseLabel(response),
          type: _responseBadgeType(response?.response),
          icon: _responseIcon(response?.response),
        );
      },
    );
  }

  Widget _buildResponseSummary(BuildContext context) {
    return StreamBuilder<List<CalloutResponseModel>>(
      stream: calloutService.streamCalloutResponses(
        calloutId: callout.id,
        organizationId: organizationId,
      ),
      builder: (context, snapshot) {
        final responses = snapshot.data;
        if (responses == null) {
          return Text(
            'Vastuseid: -',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          );
        }

        final responding = responses
            .where(
              (response) =>
                  response.response == CalloutResponseValue.responding,
            )
            .length;
        final delayed = responses
            .where(
              (response) => response.response == CalloutResponseValue.delayed,
            )
            .length;
        final unavailable = responses
            .where(
              (response) =>
                  response.response == CalloutResponseValue.unavailable,
            )
            .length;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusBadge(
              label: 'Tuleb: $responding',
              type: StatusBadgeType.ready,
              icon: Icons.check_circle_outline,
            ),
            StatusBadge(
              label: 'Hilineb: $delayed',
              type: StatusBadgeType.delayed,
              icon: Icons.schedule,
            ),
            StatusBadge(
              label: 'Ei tule: $unavailable',
              type: StatusBadgeType.offDuty,
              icon: Icons.cancel_outlined,
            ),
          ],
        );
      },
    );
  }

  String _responseLabel(CalloutResponseModel? response) {
    switch (response?.response) {
      case CalloutResponseValue.responding:
        return 'Sinu vastus: Tulen';
      case CalloutResponseValue.delayed:
        return response?.responseMinutes == null
            ? 'Sinu vastus: Hilinen'
            : 'Sinu vastus: Hilinen · ${response!.responseMinutes} min';
      case CalloutResponseValue.unavailable:
        return 'Sinu vastus: Ei tule';
      default:
        return _isActive ? 'Vasta' : 'Vastus puudub';
    }
  }

  StatusBadgeType _responseBadgeType(String? response) {
    switch (response) {
      case CalloutResponseValue.responding:
        return StatusBadgeType.ready;
      case CalloutResponseValue.delayed:
        return StatusBadgeType.delayed;
      case CalloutResponseValue.unavailable:
        return StatusBadgeType.offDuty;
      default:
        return _isActive
            ? StatusBadgeType.activeCallout
            : StatusBadgeType.neutral;
    }
  }

  IconData _responseIcon(String? response) {
    switch (response) {
      case CalloutResponseValue.responding:
        return Icons.check_circle_outline;
      case CalloutResponseValue.delayed:
        return Icons.schedule;
      case CalloutResponseValue.unavailable:
        return Icons.cancel_outlined;
      default:
        return _isActive ? Icons.touch_app_outlined : Icons.info_outline;
    }
  }
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

StatusBadgeType _priorityBadgeType(String priority) {
  switch (priority) {
    case CalloutPriority.critical:
      return StatusBadgeType.critical;
    case CalloutPriority.high:
      return StatusBadgeType.activeCallout;
    default:
      return StatusBadgeType.neutral;
  }
}

StatusBadgeType _calloutPriorityBadgeType(CalloutModel callout) {
  if (callout.status != CalloutStatus.active) {
    return StatusBadgeType.neutral;
  }
  return _priorityBadgeType(callout.priority);
}

IconData _calloutPriorityIcon(CalloutModel callout) {
  if (callout.status != CalloutStatus.active) {
    return Icons.flag_outlined;
  }
  return Icons.warning_amber_rounded;
}

StatusBadgeType _statusBadgeType(String status) {
  switch (status) {
    case CalloutStatus.closed:
      return StatusBadgeType.ready;
    case CalloutStatus.cancelled:
      return StatusBadgeType.offDuty;
    default:
      return StatusBadgeType.activeCallout;
  }
}

Color? _calloutAccentColor(CalloutModel callout) {
  if (callout.status != CalloutStatus.active) {
    return null;
  }
  return _priorityColor(callout.priority);
}

Color _priorityColor(String priority) {
  switch (priority) {
    case CalloutPriority.critical:
    case CalloutPriority.high:
      return AppColors.activeCallout;
    case CalloutPriority.normal:
      return AppColors.delayed;
    default:
      return AppColors.actionBlue;
  }
}

String _shortDateTime(DateTime value) {
  final date =
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.';
  final time =
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
