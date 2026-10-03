import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// Les briques communes aux cinq écrans de la console.
///
/// Chacun des cinq s'était construit à part : l'un empilait des blocs sable,
/// l'autre des `Card`, le troisième des `ListTile` séparés par des filets. Le
/// résultat ne ressemblait pas à un même outil. Tout passe désormais par ces
/// quatre briques, et un écran ajouté plus tard les reprendra sans rien
/// inventer.
const _couleurAdmin = MboaSection.administration;

/// Rouge de texte des compteurs en retard.
///
/// `MboaColors.erreur` ne donne que 4,38:1 sur le fond rosé des tuiles
/// d'alerte — suffisant pour un chiffre de 26 px, qui compte comme du grand
/// texte, mais le libellé juste en dessous passerait sous le seuil. Ce rouge
/// plus sombre tient à 5,92:1, et le même jeton sert aux deux lignes.
const _rougeTexte = Color(0xFFB91C1C);

/// Fond des bandeaux d'en-tête de carte.
///
/// `administration.fond` ne pouvait pas servir ici : c'est aussi le fond de la
/// page, et le bandeau d'une carte s'y confondait au point que la carte
/// paraissait commencer à mi-hauteur. Ce gris-bleu d'un cran plus soutenu
/// porte `encre900` à 15,00:1 et se détache du fond de page.
const kAdminBandeau = Color(0xFFE7ECF5);

/// Jetons de filtre posés sur un `AdminNotice`.
///
/// Le `ChoiceChip` de Material prend l'`indigo100` du thème quand il est
/// sélectionné : sur le lavande d'un encart, le jeton choisi devenait plus
/// discret que les autres, qui sont blancs. Celui-ci est plein, en indigo
/// profond, blanc dessus à 10,03:1 — on voit lequel est actif.
class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    backgroundColor: Colors.white,
    selectedColor: _couleurAdmin.accent,
    side: BorderSide(
      color: selected ? _couleurAdmin.accent : MboaColors.contour,
    ),
    labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: selected ? Colors.white : MboaColors.encre900,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    ),
    onSelected: (_) => onSelected(),
  );
}

/// Un panneau blanc titré, posé sur le fond teinté de la console.
///
/// Le titre porte un trait vertical de la couleur de la console : le repère
/// coûte deux pixels et fait d'une liste de textes une structure lisible.
class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 22,
                margin: const EdgeInsets.only(right: MboaSpace.md, top: 2),
                decoration: BoxDecoration(
                  color: _couleurAdmin.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (icon != null) ...[
                Icon(icon, size: 20, color: _couleurAdmin.accent),
                const SizedBox(width: MboaSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: MboaSpace.xs),
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: MboaSpace.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: MboaSpace.lg),
          child,
        ],
      ),
    );
  }
}

/// Un chiffre et ce qu'il compte.
///
/// La largeur n'est plus figée à 150 : elle vient de la place disponible, par
/// `AdminStatGrid`. Une tuile de largeur fixe se chevauchait avec ses voisines
/// dès que le texte grossissait, et laissait un vide à droite sur une tablette.
class AdminStat extends StatelessWidget {
  const AdminStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.alert = false,
  });

  final String value;
  final String label;
  final IconData? icon;

  /// Met le chiffre en rouge : un compteur qui désigne un retard se lit
  /// autrement qu'un compteur qui décrit un état.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = alert ? _rougeTexte : _couleurAdmin.accent;

    return Container(
      padding: const EdgeInsets.all(MboaSpace.md),
      decoration: BoxDecoration(
        color: alert ? const Color(0xFFFDF2F2) : _couleurAdmin.fond,
        borderRadius: BorderRadius.circular(MboaRadius.md),
        border: Border.all(
          color: alert
              ? _rougeTexte.withValues(alpha: 0.35)
              : MboaColors.contour,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: MboaSpace.xs),
              ],
              Expanded(
                child: Text(
                  value,
                  style: text.headlineMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
        ],
      ),
    );
  }
}

/// Dispose des `AdminStat` en colonnes égales.
///
/// Le nombre de colonnes suit la largeur *et* le grossissement du texte : à
/// 200 %, trois colonnes sur un téléphone donneraient des libellés coupés au
/// milieu d'un mot.
class AdminStatGrid extends StatelessWidget {
  const AdminStatGrid({super.key, required this.children});

  final List<Widget> children;

  static int colonnes(double largeur, double echelle) {
    final utile = largeur / echelle;
    if (utile >= 660) return 4;
    if (utile >= 440) return 3;
    if (utile >= 260) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final echelle = MediaQuery.textScalerOf(context).scale(16) / 16;

    return LayoutBuilder(
      builder: (context, contraintes) {
        final n = colonnes(contraintes.maxWidth, echelle);
        final largeur = (contraintes.maxWidth - MboaSpace.md * (n - 1)) / n;
        return Wrap(
          spacing: MboaSpace.md,
          runSpacing: MboaSpace.md,
          children: [
            for (final enfant in children)
              SizedBox(width: largeur, child: enfant),
          ],
        );
      },
    );
  }
}

/// Un encart d'information, d'avertissement ou de confirmation.
///
/// Le ton ne repose jamais sur la seule couleur : chaque ton a son icône, pour
/// rester lisible en niveaux de gris et pour qui ne distingue pas le rouge du
/// vert.
enum AdminNoticeTone {
  /// Tout va bien.
  bon(MboaColors.succes, MboaColors.forest100, Icons.verified_rounded),

  /// Quelque chose cloche et attend quelqu'un.
  alerte(MboaColors.erreur, Color(0xFFFDECEA), Icons.error_outline_rounded),

  /// Une règle, une limite, un rappel.
  note(Color(0xFF3730A3), Color(0xFFEDEBFB), Icons.info_outline_rounded);

  const AdminNoticeTone(this.trait, this.fond, this.icone);
  final Color trait;
  final Color fond;
  final IconData icone;
}

class AdminNotice extends StatelessWidget {
  const AdminNotice({
    super.key,
    required this.message,
    this.tone = AdminNoticeTone.note,
    this.title,
    this.child,
  });

  final String? title;
  final String message;
  final AdminNoticeTone tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: tone.fond,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border(left: BorderSide(color: tone.trait, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(tone.icone, color: tone.trait, size: 22),
              const SizedBox(width: MboaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: text.titleMedium?.copyWith(
                          color: MboaColors.encre900,
                        ),
                      ),
                    Text(
                      message,
                      style: text.bodyMedium?.copyWith(
                        color: MboaColors.encre900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: MboaSpace.md), child!],
        ],
      ),
    );
  }
}

/// Une étiquette : rôle, langue, périmètre, état.
class AdminTag extends StatelessWidget {
  const AdminTag(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fond = color ?? MboaColors.sable100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: MboaColors.encre500),
            const SizedBox(width: 4),
          ],
          // `Flexible` et non `Text` nu : à 200 % de grossissement, une
          // étiquette comme « non implémenté » mesurait 374 px pour 326
          // disponibles et débordait de la carte. Elle passe maintenant à la
          // ligne dans sa pastille.
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MboaColors.encre900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'écran vide d'un onglet : on dit quoi, et d'où ça viendra.
class AdminEmpty extends StatelessWidget {
  const AdminEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(MboaSpace.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: MboaColors.contour),
              ),
              child: Icon(icon, size: 36, color: _couleurAdmin.accent),
            ),
            const SizedBox(height: MboaSpace.lg),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: MboaSpace.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'erreur de chargement d'un onglet.
///
/// Elle ne jette plus la trace brute au milieu de l'écran : on dit ce qui a
/// échoué, puis le détail technique en petit, pour qu'il reste copiable sans
/// occuper toute la page.
class AdminError extends StatelessWidget {
  const AdminError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: MboaColors.encre400,
            ),
            const SizedBox(height: MboaSpace.md),
            Text(
              'Ces données n’ont pas pu être chargées',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MboaSpace.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: MboaSpace.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le voile d'attente d'un onglet.
class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(strokeWidth: 3),
    ),
  );
}
