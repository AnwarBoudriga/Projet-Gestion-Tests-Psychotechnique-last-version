import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../core/candidat_api.dart';
import '../widgets/candidat_scaffold.dart';

/// Écran « Votre évaluation » : présentation du test avant le démarrage.
class IntroView extends StatelessWidget {
  const IntroView({super.key, required this.info, required this.onStart, required this.starting});

  final TestInfo info;
  final VoidCallback onStart;
  final bool starting;

  @override
  Widget build(BuildContext context) {
    final desc = info.description?.trim() ?? '';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const EyebrowText('Avant de commencer'),
          const SizedBox(height: 8),
          const Text('Votre évaluation', style: TextStyle(fontSize: 26, color: C.navy)),
          const SizedBox(height: 6),
          const Text('Prenez un instant pour découvrir le test avant de le démarrer.',
              style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 20),
          CandidatCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const EyebrowText('Test psychotechnique'),
              const SizedBox(height: 8),
              Text(info.titre, style: const TextStyle(fontSize: 20, color: C.navy)),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(desc, style: const TextStyle(fontSize: 13, color: C.muted, height: 1.4)),
              ],
              const SizedBox(height: 18),
              const Divider(height: 1, color: C.border),
              const SizedBox(height: 18),
              Wrap(spacing: 32, runSpacing: 16, children: [
                _Stat(icon: Icons.schedule, label: 'Durée du test', value: '${info.dureeMinutes} minutes'),
                _Stat(
                  icon: Icons.checklist,
                  label: 'Nombre de questions',
                  value: '${info.nbQuestions} question${info.nbQuestions > 1 ? 's' : ''}',
                ),
              ]),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('À savoir avant de démarrer',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.navy)),
                  SizedBox(height: 6),
                  Text(
                    'Une seule réponse est possible par question. Vous pouvez revenir aux questions '
                    'précédentes avant de soumettre le test. Le chronomètre démarre dès que vous commencez.',
                    style: TextStyle(fontSize: 12, color: C.muted, height: 1.45),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                spacing: 12,
                children: [
                  const Text('Installez-vous au calme, puis lancez-vous.',
                      style: TextStyle(fontSize: 12, color: C.muted)),
                  FilledButton(
                    onPressed: starting ? null : onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: C.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: starting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Démarrer le test', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16),
                          ]),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: C.tealLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: C.teal),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: C.muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.navy)),
      ]),
    ]);
  }
}
