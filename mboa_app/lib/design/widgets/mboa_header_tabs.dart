import 'package:flutter/material.dart';

import '../tokens.dart';

/// Onglets en pastilles, posés dans un `MboaGradientHeader`.
///
/// Le `TabBar` de Material dessine un soulignement sur fond de surface : sur un
/// en-tête dégradé il faut lui imposer une couleur de fond, et l'on obtient
/// alors une bande blanche collée sous le dégradé — exactement ce qui donnait à
/// la console son air d'écran inachevé.
///
/// Ces pastilles vivent *dans* le dégradé. L'onglet actif est un jeton blanc
/// plein portant la couleur de la section ; les autres sont des jetons
/// translucides portant du blanc.
///
/// **Contrastes mesurés (WCAG 2.2).** Jeton actif : texte `section.debut` sur
/// blanc. Jeton inactif : blanc à 18 % par-dessus le dégradé, soit du blanc sur
/// `#5B55B4` au point le plus clair du dégradé de l'administration — 6,20:1.
/// Un blanc à 12 % aurait été plus discret mais la pastille devenait invisible.
class MboaHeaderTabs extends StatelessWidget {
  const MboaHeaderTabs({
    super.key,
    required this.controller,
    required this.tabs,
    required this.section,
  });

  final TabController controller;
  final List<MboaHeaderTab> tabs;
  final MboaSection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // `AnimatedBuilder` et non `TabBar` : c'est l'animation du contrôleur qui
    // nous dit quel onglet est actif, y compris quand on glisse entre deux
    // pages sans toucher la barre.
    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Le défilement part du bord de l'en-tête et non du bord de l'écran :
        // sans ce retrait, la première pastille serait collée à la marge.
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  right: i == tabs.length - 1 ? 0 : MboaSpace.sm,
                ),
                child: _Pastille(
                  tab: tabs[i],
                  actif: controller.index == i,
                  section: section,
                  style: text.labelLarge,
                  onTap: () => controller.animateTo(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un onglet : une icône, un libellé, et éventuellement un nombre à traiter.
class MboaHeaderTab {
  const MboaHeaderTab({required this.icon, required this.label, this.badge});

  final IconData icon;
  final String label;

  /// Nombre d'éléments en attente. `null` quand l'onglet n'a pas de file,
  /// `0` quand la file est vide — auquel cas rien ne s'affiche, car une
  /// pastille « 0 » attire l'œil sur une absence de travail.
  final int? badge;
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.tab,
    required this.actif,
    required this.section,
    required this.style,
    required this.onTap,
  });

  final MboaHeaderTab tab;
  final bool actif;
  final MboaSection section;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? section.debut : Colors.white;
    final badge = tab.badge;

    return Semantics(
      button: true,
      selected: actif,
      child: Material(
        color: actif ? Colors.white : Colors.white.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            // 44 de haut, plus les 8 de marge entre deux rangées de l'en-tête :
            // la cible tactile atteint le seuil que le projet s'est fixé sans
            // faire grossir l'en-tête.
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: MboaSpace.lg,
              vertical: MboaSpace.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 18, color: couleur),
                const SizedBox(width: MboaSpace.sm),
                Text(
                  tab.label,
                  style: style?.copyWith(
                    color: couleur,
                    fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (badge != null && badge > 0) ...[
                  const SizedBox(width: MboaSpace.sm),
                  _Compteur(valeur: badge, actif: actif),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le nombre à traiter, en rouge : c'est une file d'attente, pas une décoration.
class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.actif});

  final int valeur;
  final bool actif;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      // Sur jeton actif (blanc) : rouge plein, blanc dessus à 4,80:1. Sur jeton
      // inactif : blanc plein, `erreur` dessus à 4,80:1 également.
      color: actif ? MboaColors.erreur : Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$valeur',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: actif ? Colors.white : MboaColors.erreur,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    ),
  );
}
