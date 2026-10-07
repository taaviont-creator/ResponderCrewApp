import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/device_alarm_settings.dart';

/// Read the installed package, not a manually maintained label that can drift.
class AppBuildLabel extends StatefulWidget {
  const AppBuildLabel({super.key});

  @override
  State<AppBuildLabel> createState() => _AppBuildLabelState();
}

class _AppBuildLabelState extends State<AppBuildLabel> {
  late final _info = const DeviceAlarmSettings().buildInfo();

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const Text('RespondCrew · veebiversioon');
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _info,
      builder: (context, snapshot) {
        final version = snapshot.data?['version'];
        final build = snapshot.data?['build'];
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            version == null || build == null
                ? 'RespondCrew · Android'
                : 'RespondCrew $version ($build) · Android',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
