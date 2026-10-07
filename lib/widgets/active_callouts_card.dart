import 'package:flutter/material.dart';
import '../models/callout_model.dart';
import '../services/callout_service.dart';
import '../theme/app_theme.dart';
import 'app_section_card.dart';
import 'callout_response_controls.dart';

class ActiveCalloutsCard extends StatefulWidget {
  const ActiveCalloutsCard({
    super.key,
    required this.organizationId,
    required this.userId,
    required this.userName,
    required this.onOpen,
    this.calloutsStream,
    this.responseBuilder,
  });
  final String organizationId, userId, userName;
  final ValueChanged<String> onOpen;
  final Stream<List<CalloutModel>>? calloutsStream;
  final Widget Function(CalloutModel)? responseBuilder;
  @override
  State<ActiveCalloutsCard> createState() => _ActiveCalloutsCardState();
}

class _ActiveCalloutsCardState extends State<ActiveCalloutsCard> {
  late Stream<List<CalloutModel>> _stream;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _stream =
        widget.calloutsStream ??
        CalloutService().streamActiveCallouts(
          organizationId: widget.organizationId,
        );
  }

  @override
  void didUpdateWidget(covariant ActiveCalloutsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.calloutsStream != widget.calloutsStream) {
      _bind();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CalloutModel>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const AppSectionCard(
          child: Text('Väljakutse laadimine ebaõnnestus. Kontrolli ühendust.'),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final active = snapshot.data!.where(
        (c) =>
            c.status == CalloutStatus.active &&
            (c.organizationId.isNotEmpty ? c.organizationId : c.commandId) ==
                widget.organizationId,
      );
      if (active.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final callout in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSectionCard(
                accentColor: AppColors.activeCallout,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${callout.isTest ? 'PROOVIHÄIRE' : 'AKTIIVNE'} · ${CalloutType.label(callout.calloutType)}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.activeCallout,
                      ),
                    ),
                    InkWell(
                      onTap: () => widget.onOpen(callout.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                callout.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    if (callout.location.isNotEmpty)
                      Text(
                        callout.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (callout.effectiveStartedAt case final DateTime time)
                      Text(
                        'Algus ${time.day}.${time.month}.${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    widget.responseBuilder?.call(callout) ??
                        CalloutResponseControls(
                          key: ValueKey(
                            '${widget.organizationId}-${callout.id}-${widget.userId}',
                          ),
                          calloutId: callout.id,
                          organizationId: widget.organizationId,
                          userId: widget.userId,
                          userName: widget.userName,
                          active: true,
                        ),
                    TextButton(
                      onPressed: () => widget.onOpen(callout.id),
                      child: const Text('Ava väljakutse'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
