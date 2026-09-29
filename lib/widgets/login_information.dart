import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public help only; never place user, organization or secret data in this doc.
class LoginInformation extends StatelessWidget {
  const LoginInformation({super.key});

  Future<void> _open(BuildContext context, String key, String title) async {
    Map<String, dynamic> data = {};
    try {
      data =
          (await FirebaseFirestore.instance.doc('publicAppInfo/login').get())
              .data() ??
          {};
    } catch (_) {
      // Help must not prevent signing in, including when offline.
    }
    if (!context.mounted) return;
    final url = Uri.tryParse(
      data['${key}Url'] is String ? data['${key}Url'] : '',
    );
    if (url != null &&
        url.scheme == 'https' &&
        url.host.isNotEmpty &&
        url.userInfo.isEmpty) {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (!context.mounted) return;
    final body = data['${key}Text'];
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            body is String && body.trim().isNotEmpty
                ? body
                : key == 'info'
                ? 'RespondCrew on mõeldud vabatahtlikele merepäästeühingutele. Küsimuste korral kirjuta taavi@purtsesar.ee.'
                : 'Kasutusjuhend pole veel avaldatud. Abi saamiseks kirjuta taavi@purtsesar.ee.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sulge'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => _open(context, 'guide', 'Kasutusjuhend'),
            child: const Text('Kasutusjuhend'),
          ),
          TextButton(
            onPressed: () => _open(context, 'info', 'Üldinfo'),
            child: const Text('Üldinfo'),
          ),
        ],
      ),
      TextButton(
        onPressed: () async {
          try {
            if (await launchUrl(
              Uri(scheme: 'mailto', path: 'taavi@purtsesar.ee'),
            )) {
              return;
            }
          } catch (_) {}
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kirjuta aadressile taavi@purtsesar.ee.'),
              ),
            );
          }
        },
        child: const Text('Kontakt: taavi@purtsesar.ee'),
      ),
    ],
  );
}
