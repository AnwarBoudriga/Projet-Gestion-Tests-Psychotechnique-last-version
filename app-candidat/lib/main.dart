import 'package:flutter/material.dart';

import 'candidat/core/candidat_api.dart';
import 'candidat/screens/candidat_flow.dart';
import 'core/theme.dart';
import 'login_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PsyTech Pro - Espace Candidat',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      );
}

/// Connecté -> test du candidat ; sinon -> écran de connexion (clé PSY-...).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _logged;

  @override
  void initState() {
    super.initState();
    CandidatApi.onUnauthorized = () {
      if (mounted) setState(() => _logged = false);
    };
    CandidatApi.hasToken().then((v) {
      if (mounted) setState(() => _logged = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_logged == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _logged!
        ? CandidatFlow(onLogout: () async {
            await CandidatApi.logout();
            if (mounted) setState(() => _logged = false);
          })
        : LoginScreen(onLoggedIn: () => setState(() => _logged = true));
  }
}
