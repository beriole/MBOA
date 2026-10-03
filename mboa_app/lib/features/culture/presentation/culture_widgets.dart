import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_tiles.dart';

/// Titre de section, avec un filet de couleur à gauche.
///
/// Les écrans du Culture Hub empilent des blocs de même poids : sans repère
/// visuel, on ne sait plus où commence une rubrique. Le filet reprend le
/// dégradé de la section, et le sous-titre rappelle la règle qui s'y applique.
class CultureSectionTitle extends StatelessWidget {
  const CultureSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: subtitle == null ? 22 : 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: MboaSection.culture.gradient),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: MboaSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Carte d'entrée : une pastille, un titre, un sous-titre, une flèche.
///
/// Remplacée la tuile large empilée cinq fois sur la page Culture. En grille de
/// deux colonnes, la page se lit d'un coup d'œil au lieu de défiler.
class CultureEntryCard extends StatelessWidget {
  const CultureEntryCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final MboaTileTone tone;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(MboaRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(MboaSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MboaRadius.lg),
            border: Border.all(color: MboaColors.contour),
            boxShadow: kMboaCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MboaIconTile(icon: icon, tone: tone, size: 44),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: MboaColors.encre400,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille de filtre, défilant horizontalement avec son compte.
///
/// Un `Wrap` de `ChoiceChip` cassait la liste en paragraphes qui repoussaient
/// les fiches vers le bas : la moitié de l'écran servait au filtre. La bande
/// horizontale garde les fiches accessibles et fait voir d'un coup d'œil
/// combien de rubriques existent.
class CultureFilterPill extends StatelessWidget {
  const CultureFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.tone = MboaTileTone.rose,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final MboaTileTone tone;

  /// Une rubrique vide reste sélectionnable : on assume le vide.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final foreground = muted && !selected
        ? MboaColors.encre400
        : selected
        ? Colors.white
        : MboaColors.encre900;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? tone.icon
            : muted
            ? Colors.white
            : tone.background,
        borderRadius: BorderRadius.circular(MboaRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(MboaRadius.xl),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: MboaSpace.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MboaRadius.xl),
              border: Border.all(
                color: selected ? tone.icon : MboaColors.contour,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: text.labelLarge?.copyWith(color: foreground),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: text.labelLarge?.copyWith(
                      color: selected
                          ? Colors.white70
                          : muted
                          ? MboaColors.encre400
                          : tone.icon,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Petite étiquette d'information : rubrique, région, langue, durée.
class CultureMetaChip extends StatelessWidget {
  const CultureMetaChip({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = foreground ?? MboaColors.encre900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? MboaColors.sable100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: text.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide du Culture Hub : ce qui manque est nommé, pas remplacé.
class CultureEmptyState extends StatelessWidget {
  const CultureEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.tone = MboaTileTone.indigo,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final MboaTileTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MboaSpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: tone.icon),
          ),
          const SizedBox(height: MboaSpace.md),
          Text(title, style: theme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: MboaSpace.xs),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
          if (action != null) ...[
            const SizedBox(height: MboaSpace.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Squelette de carte pendant le chargement : la page garde sa forme au lieu
/// de sauter quand les données arrivent.
class CultureCardSkeleton extends StatelessWidget {
  const CultureCardSkeleton({super.key, this.height = 132});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(MboaRadius.lg),
      border: Border.all(color: MboaColors.contour),
    ),
  );
}

/// La couleur d'une rubrique, déduite de son code.
///
/// Les rubriques changeaient d'apparence d'une version à l'autre : la teinte
/// est tirée du code, de sorte qu'une rubrique garde la sienne tant que le code
/// ne change pas. Sans cela, toutes les étiquettes se ressemblaient et rien
/// n'aidait à retrouver une rubrique d'un écran à l'autre.
MboaTileTone toneForCategory(String code) {
  const tones = [
    MboaTileTone.rose,
    MboaTileTone.indigo,
    MboaTileTone.ambre,
    MboaTileTone.vert,
    MboaTileTone.orange,
    MboaTileTone.bleu,
  ];
  var hash = 0;
  for (final unit in code.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return tones[hash % tones.length];
}
