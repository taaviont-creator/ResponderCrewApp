import 'package:flutter/material.dart';
import '../models/tru_session.dart';
import '../services/tru_access_service.dart';

/// The public host knows only the module interface. The private assembly injects
/// TRU views, keeping their implementation in the private repository.
class OperationalWorkspaceScreen extends StatefulWidget {
  const OperationalWorkspaceScreen({super.key, required this.userId,
    required this.displayName, required this.path, required this.navigate,
    required this.marineHome, required this.truBuilder, this.access});
  final String userId, displayName, path;
  final ValueChanged<String> navigate;
  final Widget marineHome;
  final TruWorkspaceBuilder? truBuilder;
  final TruAccessService? access;
  @override
  State<OperationalWorkspaceScreen> createState() => _OperationalWorkspaceState();
}

class _OperationalWorkspaceState extends State<OperationalWorkspaceScreen>
    with WidgetsBindingObserver {
  TruAccessService? _access;
  bool? _initialChoice;
  @override
  void initState() {
    super.initState();
    if (widget.truBuilder != null) {
      _access = widget.access ?? TruAccessService.firebase();
    }
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _access?.resume();
    } else if ([AppLifecycleState.paused, AppLifecycleState.hidden,
        AppLifecycleState.detached].contains(state)) {
      _access?.pause();
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _access?.dispose();
    super.dispose();
  }
  Widget denied() => Scaffold(
    appBar: AppBar(title: const Text('TRU töökeskkond')),
    body: Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_access?.error ?? 'TRU ligipääs puudub või liikmesus ei ole aktiivne.'),
        if (_access?.loading == true) const CircularProgressIndicator(),
        if (_access != null) TextButton(onPressed: () => _access!.refresh(),
          child: const Text('Kontrolli uuesti')),
        TextButton(onPressed: () => widget.navigate('/uhingud'), child: const Text('Ava merepääste')),
      ]))),
  );
  @override
  Widget build(BuildContext context) {
    if (_access == null) {
      return widget.path == '/tru' ? denied() : widget.marineHome;
    }
    return ListenableBuilder(listenable: _access!, builder: (context, _) {
      final access = _access!;
      final selecting = ['/', '/tru', '/tookeskkonnad'].contains(widget.path);
      if (!access.initialized && selecting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final member = access.membership;
      if (access.initialized) _initialChoice ??= member != null;
      final picker = widget.path == '/tookeskkonnad' ||
        (widget.path == '/' && (_initialChoice ?? false));
      Widget content;
      if (widget.path == '/tru') {
        content = member == null ? denied() : KeyedSubtree(
          key: ValueKey('${widget.userId}:${member.revision}'),
          child: widget.truBuilder!(context, TruSession(userId: widget.userId,
            displayName: widget.displayName, role: member.role,
            regions: member.regions, revision: member.revision),
            () => widget.navigate('/tookeskkonnad')));
      } else if (picker) {
        content = Scaffold(appBar: AppBar(title: const Text('Vali töökeskkond')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: ListTile(leading: const Icon(Icons.sailing_outlined),
              title: const Text('Merepääste'), subtitle: const Text('Minu ühingud ja keskused'),
              onTap: () => widget.navigate('/uhingud'))),
            if (member != null) Card(child: ListTile(leading: const Icon(Icons.construction_outlined),
              title: const Text('TRU'), subtitle: Text(member.regions.join(' · ')),
              onTap: () => widget.navigate('/tru'))),
            if (access.error != null) Padding(padding: const EdgeInsets.all(16), child: Text(access.error!)),
            TextButton(onPressed: () => access.refresh(), child: const Text('Värskenda liikmesust')),
          ]));
      } else {
        content = widget.marineHome;
      }
      // Keep a stable frame so a membership refresh does not remount a marine
      // form or discard its unsaved input.
      return Scaffold(body: SafeArea(child: Column(children: [
        if (!picker && widget.path != '/tru' && member != null)
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: () => widget.navigate('/tookeskkonnad'),
            icon: const Icon(Icons.swap_horiz), label: const Text('Vaheta töökeskkonda'))),
        Expanded(key: const ValueKey('operational-content'), child: content),
      ])));
    });
  }
}
