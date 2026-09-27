import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/operation_log_model.dart';
import '../models/operation_log_report.dart';
import '../services/operation_log_service.dart';

class OperationLogReportScreen extends StatefulWidget {
  const OperationLogReportScreen({
    super.key,
    required this.log,
    required this.organizationId,
    this.eventStream,
  });
  final OperationLogModel log;
  final String organizationId;
  final Stream<List<OperationLogEventModel>>? eventStream;

  @override
  State<OperationLogReportScreen> createState() => _ReportState();
}

class _ReportState extends State<OperationLogReportScreen> {
  late final _events =
      widget.eventStream ??
      OperationLogService().streamLogEvents(
        operationLogId: widget.log.id,
        organizationId: widget.organizationId,
      );
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<OperationLogEventModel>>(
    stream: _events,
    builder: (context, snapshot) {
      final ready = snapshot.hasData && !snapshot.hasError;
      final report = ready
          ? buildOperationLogReport(widget.log, snapshot.data!)
          : '';
      return Scaffold(
        appBar: AppBar(
          title: const Text('Logi väljavõte'),
          actions: [
            IconButton(
              tooltip: 'Kopeeri väljavõte',
              icon: const Icon(Icons.copy),
              onPressed: ready
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: report));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logi väljavõte kopeeritud.'),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
        body: snapshot.hasError
            ? const Center(
                child: Text(
                  'Logi ajaloo laadimine ebaõnnestus. Proovi vaade uuesti avada.',
                ),
              )
            : !ready
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(report),
              ),
      );
    },
  );
}
