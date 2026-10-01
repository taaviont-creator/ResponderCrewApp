import '../widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/operation_log_model.dart';
import '../models/operation_log_report.dart';
import '../services/operation_log_service.dart';
import '../services/callout_attendance_service.dart';

class OperationLogReportScreen extends StatefulWidget {
  const OperationLogReportScreen({
    super.key,
    required this.log,
    required this.organizationId,
    this.eventStream,
    this.logStream,
    this.participantStream,
    this.attendanceHistoryStream,
  });
  final OperationLogModel log;
  final Stream<OperationLogModel?>? logStream;
  final String organizationId;
  final Stream<List<OperationLogEventModel>>? eventStream;
  final Stream<List<Map<String, dynamic>>>? participantStream,
      attendanceHistoryStream;

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
  late final _participants =
      widget.participantStream ??
      (widget.log.calloutId == null
          ? Stream.value(<Map<String, dynamic>>[])
          : CalloutAttendanceService().participants(
              widget.organizationId,
              widget.log.calloutId!,
            ));
  late final _attendanceHistory =
      widget.attendanceHistoryStream ??
      (widget.log.calloutId == null
          ? Stream.value(<Map<String, dynamic>>[])
          : CalloutAttendanceService().history(
              widget.organizationId,
              widget.log.calloutId!,
            ));
  late final _logStream = widget.logStream ?? Stream.value(widget.log);
  @override
  Widget build(BuildContext context) => StreamBuilder<OperationLogModel?>(
    stream: _logStream,
    builder: (context, currentLog) => StreamBuilder<List<OperationLogEventModel>>(
      stream: _events,
      builder: (context, snapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _participants,
          builder: (context, people) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: _attendanceHistory,
            builder: (context, history) {
              final failed =
                  currentLog.hasError ||
                  (currentLog.connectionState == ConnectionState.done &&
                      currentLog.data == null) ||
                  snapshot.hasError ||
                  people.hasError ||
                  history.hasError;
              final ready =
                  currentLog.hasData &&
                  snapshot.hasData &&
                  people.hasData &&
                  history.hasData &&
                  !failed;
              final report = ready
                  ? buildOperationLogReport(
                      currentLog.data!,
                      snapshot.data!,
                      participants: people.data!,
                      attendanceHistory: history.data!,
                    )
                  : '';
              return AppScaffold(
                appBar: AppBar(
                  title: const Text('Logi väljavõte'),
                  actions: [
                    IconButton(
                      tooltip: 'Kopeeri väljavõte',
                      icon: const Icon(Icons.copy),
                      onPressed: ready
                          ? () async {
                              await Clipboard.setData(
                                ClipboardData(text: report),
                              );
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
                body: failed
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
          ),
        );
      },
    ),
  );
}
