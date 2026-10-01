import '../widgets/app_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/center_access_service.dart';
import 'center_workspace_screen.dart';
import 'home_screen.dart';

class AppContextScreen extends StatefulWidget {
  const AppContextScreen({
    super.key,
    required this.userId,
    required this.path,
    required this.navigate,
    this.access,
    this.organizationHome,
  });
  final String userId, path;
  final ValueChanged<String> navigate;
  final CenterAccessService? access;
  final Widget? organizationHome;
  @override
  State<AppContextScreen> createState() => _AppContextScreenState();
}

class _AppContextScreenState extends State<AppContextScreen>
    with WidgetsBindingObserver {
  late final _access =
      widget.access ?? CenterAccessService.firebase(widget.userId);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _access.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _access.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _access.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _access,
    builder: (context, _) {
      final contexts = _access.contexts;
      final selected = contexts.where((c) => c.path == widget.path).firstOrNull;
      final centerPath = widget.path.startsWith('/keskus/');
      // Resolve the initial context list before showing an organization screen:
      // this avoids controls appearing later and remounting the whole home.
      if (!_access.initialized) {
        return const AppScaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Laadin sinu töökeskkondi…'),
              ],
            ),
          ),
        );
      }
      Widget content;
      if (centerPath) {
        content = selected != null
            ? CenterWorkspaceScreen(
                key: ValueKey(selected.centerId),
                center: selected,
              )
            : AppScaffold(
                appBar: AppBar(title: const Text('Keskuse vaade')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_access.loading)
                          const CircularProgressIndicator()
                        else ...[
                          Text(
                            _access.error ??
                                'Selle keskuse ligipääsuõigus puudub või on aegunud. Õiguse annab RespondCrew platvormihaldur.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _access.refresh,
                            child: const Text('Kontrolli uuesti'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
      } else if (widget.path == '/' && contexts.isNotEmpty) {
        content = AppScaffold(
          appBar: AppBar(title: const Text('Vali töökeskkond')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final c in contexts)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text(c.name),
                    subtitle: Text(
                      c.service == 'sar'
                          ? 'SAR-valmidus'
                          : 'Trossi mereabi valmidus',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.navigate(c.path),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Minu ühingud'),
                  onTap: () => widget.navigate('/uhingud'),
                ),
              ),
            ],
          ),
        );
      } else {
        content = widget.organizationHome ?? const HomeScreen();
      }
      if (!centerPath && contexts.isEmpty && _access.error == null) {
        return content;
      }
      // This is the application frame, not a bounded content page. In
      // particular the center map and the desktop navigation need its width.
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (!centerPath && _access.error != null)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Keskuste ühendus on häiritud. Proovin automaatselt uuesti.',
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => widget.navigate('/uhingud'),
                            child: const Text('Minu ühingud'),
                          ),
                          for (final c in contexts)
                            TextButton(
                              onPressed: () => widget.navigate(c.path),
                              child: Text(c.name),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Logi välja',
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    },
  );
}
