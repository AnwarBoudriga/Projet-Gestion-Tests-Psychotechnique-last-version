import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/app_colors.dart';
import '../../../models/question_model.dart';
import '../../../services/data_store.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_dropdown.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/responsive_row.dart';

/// Génération de questions par des agents IA (rédacteur + vérificateur).
/// L'utilisateur donne un sujet, relit les propositions, coche celles à garder
/// puis les ajoute au test sélectionné.
class AiGenerateCard extends StatefulWidget {
  const AiGenerateCard({super.key});

  @override
  State<AiGenerateCard> createState() => _AiGenerateCardState();
}

class _AiGenerateCardState extends State<AiGenerateCard> {
  final _subject = TextEditingController();
  final _count = TextEditingController(text: '5');
  final _points = TextEditingController(text: '1');
  String _difficulty = 'moyen';

  bool _generating = false;
  bool _saving = false;
  List<QuestionModel> _results = [];
  final Set<int> _selected = {};

  @override
  void dispose() {
    _subject.dispose();
    _count.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final subject = _subject.text.trim();
    final count = int.tryParse(_count.text.trim()) ?? 0;
    final points = int.tryParse(_points.text.trim()) ?? 0;
    if (subject.length < 3) {
      AppSnackbar.error(context, 'Saisissez le sujet des questions.');
      return;
    }
    if (count < 1 || count > 20) {
      AppSnackbar.error(context, 'Le nombre de questions doit être entre 1 et 20.');
      return;
    }
    if (points < 1) {
      AppSnackbar.error(context, 'Les points doivent être au moins 1.');
      return;
    }

    setState(() => _generating = true);
    List<QuestionModel> generated = [];
    final ok = await runGuarded(context, () async {
      generated = await DataStore.instance.generateQuestions(
        subject: subject,
        count: count,
        difficulty: _difficulty,
        points: points,
      );
    });
    if (!mounted) return;
    setState(() {
      _generating = false;
      if (ok) {
        _results = generated;
        _selected
          ..clear()
          ..addAll(List.generate(generated.length, (i) => i));
      }
    });
  }

  Future<void> _addSelected() async {
    final store = DataStore.instance;
    final test = store.selectedTest;
    if (test == null) {
      AppSnackbar.error(context,
          'Créez ou sélectionnez d’abord un test dans la page « Tests ».');
      return;
    }
    final chosen = [
      for (var i = 0; i < _results.length; i++)
        if (_selected.contains(i)) _results[i],
    ];
    if (chosen.isEmpty) {
      AppSnackbar.error(context, 'Cochez au moins une question.');
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(
        context, () => store.addQuestionsBatch(test.id, chosen));
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    AppSnackbar.success(context,
        '${chosen.length} question(s) ajoutée(s) au test « ${test.title} ».');
    setState(() {
      _results = [];
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      title: 'Générer avec l’IA',
      subtitle:
          'Donnez un sujet : des agents IA rédigent puis vérifient les questions. Vous relisez avant d’ajouter.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            label: 'Sujet',
            hint: 'Ex. : raisonnement logique, bases de la comptabilité, Excel…',
            controller: _subject,
            minLines: 2,
            maxLines: 3,
            enabled: !_generating,
          ),
          const SizedBox(height: 16),
          ResponsiveRow(
            breakpoint: 520,
            gap: 16,
            children: [
              CustomTextField(
                label: 'Nombre (1 à 20)',
                hint: '5',
                controller: _count,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_generating,
              ),
              CustomDropdown<String>(
                label: 'Difficulté',
                hint: 'Choisir',
                value: _difficulty,
                enabled: !_generating,
                items: const [
                  DropdownItem('facile', 'Facile'),
                  DropdownItem('moyen', 'Moyenne'),
                  DropdownItem('difficile', 'Difficile'),
                ],
                onChanged: (v) => setState(() => _difficulty = v),
              ),
              CustomTextField(
                label: 'Points / question',
                hint: '1',
                controller: _points,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_generating,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: CustomButton(
              label: _generating ? 'Génération en cours…' : 'Générer les questions',
              icon: Icons.auto_awesome,
              compact: true,
              isLoading: _generating,
              onPressed: _generate,
            ),
          ),
          if (_generating)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Les agents rédigent puis vérifient les questions (10 à 40 secondes)…',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          if (_results.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              '${_results.length} question(s) proposée(s) — décochez celles à ignorer',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _results.length; i++) _resultTile(i),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CustomButton(
                    label: 'Ignorer',
                    compact: true,
                    variant: ButtonVariant.secondary,
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _results = [];
                              _selected.clear();
                            }),
                  ),
                  CustomButton(
                    label: 'Ajouter la sélection (${_selected.length})',
                    icon: Icons.add,
                    compact: true,
                    isLoading: _saving,
                    onPressed: _addSelected,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultTile(int i) {
    final q = _results[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: _selected.contains(i),
        onChanged: _saving
            ? null
            : (v) => setState(() => v == true ? _selected.add(i) : _selected.remove(i)),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(q.text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var k = 0; k < 4; k++)
                Text(
                  q.optionLabel(k) + (k == q.correctIndex ? '  ✓' : ''),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: k == q.correctIndex
                        ? AppColors.turquoise
                        : AppColors.textSecondary,
                    fontWeight:
                        k == q.correctIndex ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
