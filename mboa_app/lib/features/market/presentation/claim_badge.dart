import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../domain/models.dart';

/// Étiquette d'une affirmation culturelle portée par un objet (SS3).
///
/// C'est le point où la règle du projet entre dans la boutique : « masque
/// traditionnel » est une affirmation. Ou bien elle s'appuie sur une fiche
/// publiée et sourcée, ou bien c'est le vendeur qui le dit — et l'acheteur doit
/// voir la différence sans avoir à la deviner.
class ClaimBadge extends StatelessWidget {
  const ClaimBadge({
    super.key,
    required this.claim,
    this.expanded = false,
    this.compact = false,
  });

  final CulturalClaim claim;

  /// En version longue, l'explication est affichée sous l'étiquette.
  final bool expanded;

  /// Sur une vignette de grille, la place manque. L'étiquette se réduit à son
  /// icône et à un mot — mais elle ne disparaît jamais : c'est elle qui dit si
  /// l'affirmation vient d'une fiche sourcée ou du vendeur.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (claim == CulturalClaim.none) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final sourced = claim == CulturalClaim.linkedToSource;
    final color = sourced ? MboaColors.forest700 : MboaColors.terre700;
    final background = sourced ? MboaColors.forest100 : MboaColors.terre100;

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sourced ? Icons.menu_book_rounded : Icons.person_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              compact ? claim.shortLabel : claim.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: MboaColors.encre900),
            ),
          ),
        ],
      ),
    );

    if (!expanded) return badge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge,
        const SizedBox(height: MboaSpace.xs),
        Text(
          claim.explanation,
          style: text.bodySmall?.copyWith(color: MboaColors.encre500),
        ),
      ],
    );
  }
}

/// Rappel du mode de règlement, servi par l'API et affiché tel quel.
class PaymentNotice extends StatelessWidget {
  const PaymentNotice({super.key, required this.notice});

  final String notice;

  @override
  Widget build(BuildContext context) {
    if (notice.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.md),
      decoration: BoxDecoration(
        color: MboaColors.sable100,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 18,
            color: MboaColors.encre500,
          ),
          const SizedBox(width: MboaSpace.sm),
          Expanded(
            child: Text(
              notice,
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ),
        ],
      ),
    );
  }
}
