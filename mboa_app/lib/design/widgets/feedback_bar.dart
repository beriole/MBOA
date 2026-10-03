import 'package:flutter/material.dart';

import '../tokens.dart';

/// Barre de feedback après une réponse (SS17).
///
/// Correct : ✓ + libellé + XP. Incorrect : ✗ + « Pas encore » + bonne réponse.
/// L'information n'est jamais portée par la seule couleur (K9) : icône et texte
/// l'accompagnent toujours. Le ton n'humilie jamais.
class FeedbackBar extends StatelessWidget {
  const FeedbackBar({
    super.key,
    required this.isCorrect,
    required this.onContinue,
    this.xpDelta = 0,
    this.correctAnswerLabel,
    this.explanation,
    this.trailing,
  });

  final bool isCorrect;
  final VoidCallback onContinue;
  final int xpDelta;
  final String? correctAnswerLabel;
  final String? explanation;

  /// Contenu additionnel, par exemple un bouton pour réécouter la bonne réponse.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? MboaColors.succes : MboaColors.erreur;
    final background = isCorrect
        ? const Color(0xFFE3F2E9)
        : const Color(0xFFFBE4E2);
    final title = isCorrect ? 'Correct' : 'Pas encore';
    final text = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      label: isCorrect
          ? 'Correct${xpDelta > 0 ? ', plus $xpDelta XP' : ''}'
          : 'Pas encore. ${correctAnswerLabel != null ? 'Bonne réponse : $correctAnswerLabel' : ''}',
      child: Container(
        width: double.infinity,
        color: background,
        padding: const EdgeInsets.fromLTRB(
          MboaSpace.lg,
          MboaSpace.lg,
          MboaSpace.lg,
          MboaSpace.xl,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: color,
                    size: 28,
                  ),
                  const SizedBox(width: MboaSpace.sm),
                  Text(title, style: text.titleLarge?.copyWith(color: color)),
                  const Spacer(),
                  if (xpDelta > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MboaColors.ocre400,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+$xpDelta XP',
                        style: text.labelLarge?.copyWith(
                          color: MboaColors.encre900,
                        ),
                      ),
                    ),
                ],
              ),
              if (!isCorrect && correctAnswerLabel != null) ...[
                const SizedBox(height: MboaSpace.sm),
                Text(
                  'Bonne réponse',
                  style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
                ),
                Text(
                  correctAnswerLabel!,
                  style: text.titleLarge?.copyWith(color: MboaColors.forest900),
                ),
              ],
              if (explanation != null) ...[
                const SizedBox(height: MboaSpace.xs),
                Text(explanation!, style: text.bodyMedium),
              ],
              if (trailing != null) ...[
                const SizedBox(height: MboaSpace.md),
                trailing!,
              ],
              const SizedBox(height: MboaSpace.lg),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: onContinue,
                child: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
