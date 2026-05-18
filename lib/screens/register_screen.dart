import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:respondcrew_app/services/auth_service.dart';
import 'package:respondcrew_app/services/user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _loading = true);

    try {
      await AuthService().registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viga: kasutaja loomine ebaõnnestus')),
        );
        return;
      }

      await UserService().createUserDocument(
        uid: user.uid,
        email: user.email ?? _emailController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konto loodud')),
      );
      Navigator.pop(context);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viga: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RespondCrew – Registreeru')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nimi'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Parool'),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: Text(_loading ? 'Loon...' : 'Loo konto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}