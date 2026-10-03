import 'package:flutter/material.dart';

import '../tokens.dart';

/// Pastille d'icône colorée, motif récurrent des maquettes.
///
/// On la retrouve en tête de chaque ligne de liste (lots 11 et 12) et dans les
/// grilles d'accès rapide (lot 4).
class MboaIconTile extends StatelessWidget {
  const MboaIconTile({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 40,
  });

  final IconData icon;
  final MboaTileTone tone;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(MboaRadius.md),
    ),
    child: Icon(icon, color: tone.icon, size: size * 0.5),
  );
}

/// Ligne de liste « pastille + titre + sous-titre + chevron ».
///
/// C'est la brique de base des écrans de service et de réglages des maquettes.
class MboaTileRow extends StatelessWidget {
  const MboaTileRow({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final MboaTileTone tone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(MboaRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(MboaRadius.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          padding: const EdgeInsets.all(MboaSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MboaRadius.md),
            border: Border.all(color: MboaColors.contour),
          ),
          child: Row(
            children: [
              MboaIconTile(icon: icon, tone: tone),
              const SizedBox(width: MboaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: text.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  (onTap == null
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: MboaColors.encre400,
                        )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compteur encadré : « 12 Leçons », « 320 XP »…
///
/// Les maquettes les alignent par trois ou quatre sous l'en-tête.
class MboaStat extends StatelessWidget {
  const MboaStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.tone = MboaTileTone.indigo,
    this.onLight = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final MboaTileTone tone;

  /// Posé sur le dégradé plutôt que sur le fond clair.
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final foreground = onLight ? Colors.white : MboaColors.encre900;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MboaSpace.md,
        vertical: MboaSpace.sm,
      ),
      decoration: BoxDecoration(
        color: onLight ? Colors.white24 : Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.md),
        border: onLight ? null : Border.all(color: MboaColors.contour),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: onLight ? Colors.white : tone.icon),
                const SizedBox(width: MboaSpace.xs),
              ],
              Text(value, style: text.titleLarge?.copyWith(color: foreground)),
            ],
          ),
          Text(
            label,
            style: text.bodySmall?.copyWith(
              color: onLight ? Colors.white70 : MboaColors.encre500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Encart d'information doux, avec une icône d'accroche.
///
/// Les maquettes l'utilisent pour les astuces et les rappels (« Astuce :
/// parlez clairement… »).
class MboaNoteBox extends StatelessWidget {
  const MboaNoteBox({
    super.key,
    required this.text,
    this.icon = Icons.lightbulb_outline_rounded,
    this.tone = MboaTileTone.ambre,
    this.title,
  });

  final String text;
  final IconData icon;
  final MboaTileTone tone;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.md),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone.icon),
          const SizedBox(width: MboaSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: theme.titleMedium),
                Text(
                  text,
                  style: theme.bodySmall?.copyWith(color: MboaColors.encre900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
