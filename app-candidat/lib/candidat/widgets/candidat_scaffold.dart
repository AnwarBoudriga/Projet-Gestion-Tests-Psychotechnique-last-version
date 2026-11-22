import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Cadre de l'espace candidat : barre du haut (logo, "Espace candidat",
/// déconnexion) + contenu centré.
class CandidatScaffold extends StatelessWidget {
  const CandidatScaffold({super.key, required this.child, required this.onLogout});

  final Widget child;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: Row(children: [
                    const Logo(),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 24, color: C.border),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Tests psychotechniques',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ),
                    const Text('Espace candidat', style: TextStyle(fontSize: 12, color: C.navy)),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Se déconnecter',
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, size: 18, color: C.muted),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: child,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Carte blanche arrondie utilisée dans toutes les vues candidat.
class CandidatCard extends StatelessWidget {
  const CandidatCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

/// Petit libellé en capitales teal ("TEST EN COURS", "AVANT DE COMMENCER"…).
class EyebrowText extends StatelessWidget {
  const EyebrowText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: C.teal,
        ),
      );
}
