import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../services/data_store.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_dropdown.dart';

/// Choix du test concerné directement depuis la page « Questions »
/// (même sélection que dans la page « Tests »).
class TestPickerCard extends StatelessWidget {
  const TestPickerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = DataStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tests = store.tests;
        final selected = store.selectedTest;
        return CustomCard(
          title: 'Test concerné',
          subtitle:
          'Les questions ajoutées (manuellement, avec l’IA ou depuis la banque) sont rattachées à ce test.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomDropdown<String>(
                label: 'Test',
                hint: tests.isEmpty ? 'Aucun test disponible' : 'Sélectionner un test',
                enabled: tests.isNotEmpty,
                value: selected?.id,
                items: [for (final t in tests) DropdownItem(t.id, t.title)],
                onChanged: (id) => runGuarded(context, () => store.selectTest(id)),
              ),
              if (tests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Créez d’abord un test dans la page « Tests ».',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
            ],
          ),
        );
      },
    );
  }
}
