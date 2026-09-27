import 'package:flutter/material.dart';

class MinimumCrewDialog extends StatefulWidget {
  const MinimumCrewDialog({super.key, required this.initialValue});
  final int initialValue;
  @override
  State<MinimumCrewDialog> createState() => _MinimumCrewDialogState();
}

class _MinimumCrewDialogState extends State<MinimumCrewDialog> {
  late final _controller = TextEditingController(
    text: widget.initialValue.toString(),
  );
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Miinimumkoosseis'),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Miinimum valves liikmete arv',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Katkesta'),
      ),
      ElevatedButton(
        onPressed: () {
          final value = int.tryParse(_controller.text.trim());
          if (value == null || value < 0) {
            setState(() => _error = 'Sisesta korrektne arv.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Salvesta'),
      ),
    ],
  );
}
