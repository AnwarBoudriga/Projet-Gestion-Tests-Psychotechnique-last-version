import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../core/candidat_api.dart';
import '../widgets/candidat_scaffold.dart';

/// « Votre test est terminé » + score final (si l'entreprise l'autorise).
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.result, required this.onLogout});

  final TestResult result;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final showScore = result.scoreVisible && result.score != null && result.scoreMax != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(children: [
          const SizedBox(height: 12),
          _RoundIcon(icon: Icons.check),
          const SizedBox(height: 18),
          const Text('Votre test est terminé.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: C.navy)),
          const SizedBox(height: 8),
          Text(
            showScore
                ? 'Vos réponses ont bien été soumises. Vous pouvez maintenant consulter votre score final.'
                : 'Vos réponses ont bien été soumises. Merci pour votre participation.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: C.muted, height: 1.4),
          ),
          const SizedBox(height: 22),
          CandidatCard(
            child: Column(children: [
              const EyebrowText('Résultat de votre évaluation'),
              const SizedBox(height: 8),
              Text(result.titre,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: C.navy)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(color: C.tealLight, borderRadius: BorderRadius.circular(10)),
                child: showScore
                    ? Column(children: [
                        const Text('Votre score final', style: TextStyle(fontSize: 12, color: C.muted)),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text('${result.score}',
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: C.teal)),
                          const SizedBox(width: 6),
                          Text('/ ${result.scoreMax}', style: const TextStyle(fontSize: 22, color: C.teal)),
                        ]),
                        const SizedBox(height: 2),
                        const Text('points', style: TextStyle(fontSize: 12, color: C.muted)),
                      ])
                    : const Text(
                        'Votre résultat sera communiqué par l’entreprise.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: C.navy, height: 1.4),
                      ),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(showScore ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 14, color: C.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    showScore
                        ? 'La consultation de votre score est autorisée.'
                        : 'La consultation du score n’est pas autorisée.',
                    style: const TextStyle(fontSize: 11.5, color: C.muted),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onLogout,
            child: const Text('Quitter l’espace candidat', style: TextStyle(fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}

/// Invitation expirée.
class ExpiredView extends StatelessWidget {
  const ExpiredView({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(children: [
          const SizedBox(height: 12),
          _RoundIcon(icon: Icons.timer_off_outlined),
          const SizedBox(height: 18),
          const Text('Invitation expirée',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: C.navy)),
          const SizedBox(height: 8),
          const Text(
            'Cette invitation n’est plus valide. Contactez l’entreprise qui vous a invité pour recevoir une nouvelle clé.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextButton(onPressed: onLogout, child: const Text('Retour à la connexion')),
        ]),
      ),
    );
  }
}

/// Erreur de chargement (serveur injoignable, etc.) avec bouton « Réessayer ».
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({super.key, required this.message, required this.onRetry, required this.onLogout});

  final String message;
  final VoidCallback onRetry, onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(children: [
          const SizedBox(height: 12),
          _RoundIcon(icon: Icons.error_outline),
          const SizedBox(height: 18),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: C.navy, height: 1.4)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: C.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Réessayer'),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onLogout, child: const Text('Se déconnecter')),
          ]),
        ]),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(color: C.tealLight, shape: BoxShape.circle),
        child: Icon(icon, size: 24, color: C.teal),
      );
}
