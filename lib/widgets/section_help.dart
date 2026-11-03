import 'package:flutter/material.dart';

class SectionHelp extends StatelessWidget {
  const SectionHelp(this.title, this.explanation, {super.key});
  final String title;
  final String explanation;

  @override
  Widget build(BuildContext context) => Row(children: [
    Flexible(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
    IconButton(
      tooltip: 'Selgitus: $title',
      icon: const Icon(Icons.help_outline, size: 20),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          scrollable: true,
          content: Text(explanation),
          actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Sulge'))],
        ),
      ),
    ),
  ]);
}
