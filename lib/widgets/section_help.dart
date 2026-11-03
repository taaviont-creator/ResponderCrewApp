import 'package:flutter/material.dart';
import 'workspace_guide.dart';

class SectionHelp extends StatelessWidget {
  const SectionHelp(this.title, this.explanation, {super.key});
  final String title, explanation;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Row(children: [
      Flexible(child: Text(title, style: style)),
      IconButton(
        tooltip: 'Selgitus: $title',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => showDialog<void>(context: context, builder: (dialog) => AlertDialog(
          title: Text(title), scrollable: true, content: Text(explanation),
          actions: [
            TextButton(onPressed: () => openWorkspaceGuide(dialog), child: const Text('Kasutusjuhend')),
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Sulge')),
          ],
        )),
        icon: DecoratedBox(decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4)),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('?', style: style))),
      ),
    ]);
  }
}
