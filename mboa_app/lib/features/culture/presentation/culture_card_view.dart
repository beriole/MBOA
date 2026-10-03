import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens.dart';
import '../domain/models.dart';

/// Carte « Le savais-tu ? » affichée à la fin d'une leçon (SS21).
///
/// C'est ce qui évite deux menus séparés : la culture apparaît là où l'on
/// apprend, au moment où elle éclaire ce qu'on vient de travailler.
class CultureCardView extends StatelessWidget {
  const CultureCardView({
    super.key,
    required this.card,
    required this.onContinue,
  });

  final CultureCard card;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(MboaSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(MboaSpace.xl),
            decoration: BoxDecoration(
              color: MboaColors.terre100,
              borderRadius: BorderRadius.circular(MboaRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      color: MboaColors.terre700,
                      size: 28,
                    ),
                    const SizedBox(width: MboaSpace.sm),
                    Text(
                      'LE SAVAIS-TU ?',
                      style: text.labelLarge?.copyWith(
                        color: MboaColors.terre700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MboaSpace.lg),
                Text(card.title, style: text.headlineMedium),
                const SizedBox(height: MboaSpace.sm),
                Text(card.summary, style: text.bodyLarge),
                const SizedBox(height: MboaSpace.lg),
                if (card.sourceTitle != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.fact_check_outlined,
                        size: 16,
                        color: MboaColors.encre500,
                      ),
                      const SizedBox(width: MboaSpace.xs),
                      Expanded(
                        child: Text(
                          'Source : ${card.sourceTitle}',
                          style: text.bodySmall?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: MboaSpace.lg),
          OutlinedButton.icon(
            onPressed: () => context.push('/culture/${card.id}'),
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            label: const Text('Découvrir davantage'),
          ),
          const Spacer(),
          FilledButton(onPressed: onContinue, child: const Text('Continuer')),
        ],
      ),
    );
  }
}
