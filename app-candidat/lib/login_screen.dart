import 'package:flutter/material.dart';

import 'candidat/core/candidat_api.dart';
import 'core/theme.dart';
import 'core/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});
  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _key = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_key.text.trim().isEmpty) {
      setState(() => _error = 'La clé candidat est obligatoire.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CandidatApi.login(_key.text);
      widget.onLoggedIn();
    } catch (e) {
      if (mounted) setState(() => _error = CandidatApi.errorMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 800;
        return Row(children: [
          if (wide)
            Expanded(
              flex: 4,
              child: Container(
                color: C.navy,
                padding: const EdgeInsets.all(40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Logo(dark: true),
                  const Spacer(),
                  Container(width: 40, height: 2, color: Colors.white54),
                  const SizedBox(height: 16),
                  const Text('Votre évaluation\npsychotechnique',
                      style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w300, height: 1.3)),
                  const Spacer(),
                  const Row(children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.white54),
                    SizedBox(width: 8),
                    Text('Espace Candidat', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Logo(),
                    const SizedBox(height: 28),
                    const Text('Connexion', style: TextStyle(fontSize: 26, color: C.navy)),
                    const SizedBox(height: 6),
                    const Text('Saisissez la clé reçue par email (PSY-XXXXXXXX) pour accéder à votre test.',
                        style: TextStyle(fontSize: 13, color: C.muted)),
                    const SizedBox(height: 24),
                    LabeledField(
                      label: 'Clé candidat',
                      controller: _key,
                      hint: 'PSY-XXXXXXXX',
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(label: 'Accéder au test', loading: _loading, onPressed: _submit),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
