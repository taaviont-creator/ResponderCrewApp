import '../widgets/app_layout.dart';
import '../widgets/app_logo.dart';
import 'package:flutter/material.dart';
import '../widgets/login_information.dart';

import 'package:respondcrew_app/services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // =========================
  // 1) Formi controllerid / state
  // =========================
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false; // kas login käib (nupp disabled + tekst muutub)

  // =========================
  // 2) Lifecycle: puhastus (vältimaks memory leak'e)
  // =========================
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =========================
  // 3) Auth: sisselogimine
  // =========================
  Future<void> _login() async {
    // 3.1 Lülita UI "loading" olekusse
    setState(() => _loading = true);

    try {
      // 3.2 Tee päris sisselogimine AuthService kaudu
      await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // 3.4 UI tagasiside (SnackBar)
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sisselogimine õnnestus')));
    } on Exception catch (_) {
      // 3.5 Vea korral näita kasutajale
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sisselogimine ebaõnnestus. Kontrolli e-posti ja parooli.',
          ),
        ),
      );
    } finally {
      // 3.6 Lülita loading välja (kui ekraan on alles elus)
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // 4) Navigation: mine registreerimise ekraanile
  // =========================
  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // =========================
  // 5) UI: email input
  // =========================
  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'E-post'),
    );
  }

  // =========================
  // 6) UI: parooli input
  // =========================
  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Parool'),
    );
  }

  // =========================
  // 7) UI: login nupp (loading state + disabled)
  // =========================
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        child: Text(_loading ? 'Sisselogimine...' : 'Logi sisse'),
      ),
    );
  }

  // =========================
  // 8) UI: "Loo konto" link/nupp
  // =========================
  Widget _buildCreateAccountButton() {
    return TextButton(
      onPressed: _goToRegister,
      child: const Text('Pole veel kontot? Loo konto'),
    );
  }

  // =========================
  // 9) build(): ekraani kokkupanek
  // =========================
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      contentMaxWidth: 560,
      // 9.1 AppBar (ekraani pealkiri)
      appBar: AppBar(title: const Text('RespondCrew')),

      // 9.2 Body (form)
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const AppLogo(),
            const SizedBox(height: 16),
            const Text('Mõeldud vabatahtlikele merepäästeühingutele.'),
            const SizedBox(height: 24),
            // Ülemine osa: sisestused
            _buildEmailField(),
            const SizedBox(height: 12),
            _buildPasswordField(),

            // Keskmine osa: login nupp
            const SizedBox(height: 20),
            _buildLoginButton(),

            // Alumine osa: register link
            _buildCreateAccountButton(),
            const SizedBox(height: 24),
            const LoginInformation(),
          ],
        ),
      ),
    );
  }
}
