import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.signedInBuilder, this.authChanges});
  final Widget Function(BuildContext context, User user)? signedInBuilder;
  final Stream<User?>? authChanges;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Keep the subscription stable when the router changes the selected context.
  late final _authChanges =
      widget.authChanges ?? FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        // Laadimine
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // Pole sisselogitud -> Login
        if (user == null) {
          return const LoginScreen();
        }

        // Sisselogitud -> Äpi sisu
        return widget.signedInBuilder?.call(context, user) ??
            const HomeScreen();
      },
    );
  }
}
