import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../core/candidat_api.dart';
import '../core/proctoring_api.dart';
import '../widgets/candidat_scaffold.dart';

/// Test en cours : chronomètre, progression, une question à la fois,
/// enregistrement de chaque réponse sur le serveur, soumission finale.
class TestView extends StatefulWidget {
  const TestView({
    super.key,
    required this.content,
    required this.onSubmitted,
    required this.onReload,
  });

  final TestContent content;

  /// Appelé avec le résultat une fois le test soumis (manuellement ou automatiquement).
  final ValueChanged<TestResult> onSubmitted;

  /// Demande de rechargement de l'état depuis le serveur (temps écoulé, invitation expirée…).
  final VoidCallback onReload;

  @override
  State<TestView> createState() => _TestViewState();
}

class _TestViewState extends State<TestView> with WidgetsBindingObserver {
  late final Map<int, String> _answers;
  late final DateTime _deadline;
  Timer? _timer;
  int _index = 0;
  int _remaining = 0;
  bool _submitting = false;

  // Surveillance : temps passé sur chaque question et sorties de l'application.
  final Stopwatch _qWatch = Stopwatch();
  final Set<int> _answeredOnce = {};
  bool _inBackground = false;

  List<Question> get _questions => widget.content.questions;

  @override
  void initState() {
    super.initState();
    _answers = Map<int, String>.of(widget.content.reponses);
    _remaining = widget.content.resteSecondes;
    _deadline = DateTime.now().add(Duration(seconds: widget.content.resteSecondes));

    // Reprise : on se place sur la première question sans réponse.
    final first = _questions.indexWhere((q) => !_answers.containsKey(q.id));
    _index = first < 0 ? 0 : first;

    _answeredOnce.addAll(_answers.keys);
    _qWatch.start();
    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// Le candidat quitte l'écran du test (app en arrière-plan / onglet masqué) puis revient.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_inBackground) return;
      _inBackground = true;
      _qWatch.stop();
      ProctoringApi.evenement('APP_BACKGROUND');
    } else if (state == AppLifecycleState.resumed && _inBackground) {
      _inBackground = false;
      _qWatch.start();
      ProctoringApi.evenement('APP_RESUME');
    }
  }

  /// Changement de question : le chronomètre de temps de réponse repart de zéro.
  void _goTo(int i) {
    setState(() => _index = i);
    _qWatch
      ..reset()
      ..start();
  }

  void _tick() {
    if (!mounted) return;
    final left = _deadline.difference(DateTime.now()).inSeconds;
    final value = left < 0 ? 0 : left;
    setState(() => _remaining = value);
    if (value <= 0) {
      _timer?.cancel();
      _submit(auto: true);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _select(Question q, String choix) async {
    if (_submitting || _answers[q.id] == choix) return;
    final previous = _answers[q.id];
    setState(() => _answers[q.id] = choix);
    try {
      await CandidatApi.repondre(q.id, choix);
      // Surveillance : 1re réponse (avec le temps passé) ou modification
      if (_answeredOnce.add(q.id)) {
        ProctoringApi.evenement('ANSWER',
            questionId: q.id, choix: choix, tempsMs: _qWatch.elapsedMilliseconds);
      } else {
        ProctoringApi.evenement('ANSWER_CHANGED', questionId: q.id, choix: choix);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _answers.remove(q.id);
        } else {
          _answers[q.id] = previous;
        }
      });
      final s = CandidatApi.statusCode(e);
      if (s == 409 || s == 410) {
        widget.onReload();
      } else {
        _toast(CandidatApi.errorMessage(e));
      }
    }
  }

  Future<void> _confirmAndSubmit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _SubmitDialog(
        titre: widget.content.titre,
        answered: _answers.length,
        total: _questions.length,
      ),
    );
    if (ok == true) await _submit();
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final r = await CandidatApi.soumettre();
      if (!mounted) return;
      _timer?.cancel();
      widget.onSubmitted(r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final s = CandidatApi.statusCode(e);
      if (auto || s == 409 || s == 410) {
        widget.onReload();
      } else {
        _toast(CandidatApi.errorMessage(e));
      }
    }
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const CandidatCard(
        child: Text('Ce test ne contient aucune question.', style: TextStyle(color: C.muted)),
      );
    }

    final total = _questions.length;
    final q = _questions[_index];
    final answered = _answers.length;
    final pct = total == 0 ? 0 : (answered * 100 / total).round();
    final isLast = _index == total - 1;
    final urgent = _remaining <= 60;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── En-tête : titre + chrono ──
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const EyebrowText('Test en cours'),
            const SizedBox(height: 6),
            Text(widget.content.titre, style: const TextStyle(fontSize: 24, color: C.navy)),
          ]),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: urgent ? Colors.red.shade300 : C.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_outlined, size: 20, color: urgent ? Colors.red.shade600 : C.teal),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Temps restant', style: TextStyle(fontSize: 10.5, color: C.muted)),
              Text(
                _format(_remaining),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: urgent ? Colors.red.shade700 : C.navy,
                ),
              ),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 16),

      // ── Progression ──
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$answered question${answered > 1 ? 's' : ''} répondue${answered > 1 ? 's' : ''} sur $total',
            style: const TextStyle(fontSize: 11.5, color: C.muted)),
        Text('$pct %', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.teal)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : answered / total,
          minHeight: 4,
          backgroundColor: C.border,
          color: C.teal,
        ),
      ),
      const SizedBox(height: 16),

      // ── Question ──
      CandidatCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Question ${_index + 1} sur $total',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.teal)),
            const Text('Une seule réponse possible', style: TextStyle(fontSize: 11.5, color: C.muted)),
          ]),
          const SizedBox(height: 18),
          _QuestionStatement(enonce: q.enonce),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, box) {
            final twoCols = box.maxWidth >= 520;
            final w = twoCols ? (box.maxWidth - 12) / 2 : box.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: q.options.entries
                  .map((e) => SizedBox(
                        width: w,
                        child: _OptionTile(
                          letter: e.key,
                          text: e.value,
                          selected: _answers[q.id] == e.key,
                          onTap: () => _select(q, e.key),
                        ),
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 20),
          const Divider(height: 1, color: C.border),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            OutlinedButton(
              onPressed: _index > 0 && !_submitting ? () => _goTo(_index - 1) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: C.navy,
                side: const BorderSide(color: C.border),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Précédent', style: TextStyle(fontSize: 13)),
            ),
            FilledButton(
              onPressed: _submitting
                  ? null
                  : () {
                      if (isLast) {
                        _confirmAndSubmit();
                      } else {
                        _goTo(_index + 1);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: C.teal,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(isLast ? 'Terminer' : 'Suivant', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Icon(isLast ? Icons.check : Icons.arrow_forward, size: 16),
              ]),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _submitting ? null : _confirmAndSubmit,
          icon: _submitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_outlined, size: 16),
          label: const Text('Soumettre le test', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: C.navy,
            backgroundColor: Colors.white,
            side: const BorderSide(color: C.border),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    ]);
  }
}

/// Énoncé : la première ligne est la question ; les lignes suivantes (suite
/// de nombres, schéma texte…) sont affichées dans un encadré.
class _QuestionStatement extends StatelessWidget {
  const _QuestionStatement({required this.enonce});

  final String enonce;

  @override
  Widget build(BuildContext context) {
    final lines = enonce.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final title = lines.isEmpty ? '' : lines.first;
    final detail = lines.length > 1 ? lines.sublist(1).join('\n') : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.navy, height: 1.35)),
      if (detail != null) ...[
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
          child: Text(detail,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, color: C.navy, letterSpacing: 1.5, height: 1.4)),
        ),
      ],
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter, text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.tealLight : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? C.teal : C.border, width: selected ? 1.4 : 1),
          ),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? C.teal : C.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(letter,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : C.muted,
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: C.navy))),
            const SizedBox(width: 8),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20, color: selected ? C.teal : C.border),
          ]),
        ),
      ),
    );
  }
}

class _SubmitDialog extends StatelessWidget {
  const _SubmitDialog({required this.titre, required this.answered, required this.total});

  final String titre;
  final int answered, total;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.tealLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.send_outlined, size: 20, color: C.teal),
            ),
            const SizedBox(height: 16),
            const Text('Soumettre votre test ?', style: TextStyle(fontSize: 20, color: C.navy)),
            const SizedBox(height: 8),
            Text(
              'Après confirmation, vous ne pourrez plus modifier vos réponses au test « $titre ».',
              style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.border),
              ),
              child: Column(children: [
                _row('Questions répondues', '$answered sur $total', bold: true),
                const SizedBox(height: 8),
                _row('Questions sans réponse', '${total - answered}'),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.navy,
                    side: const BorderSide(color: C.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Revenir au test', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: C.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirmer la soumission', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted)),
      Text(value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: C.navy,
          )),
    ]);
  }
}
