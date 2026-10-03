import 'package:flutter/material.dart';

import '../tokens.dart';

/// La barre de navigation de l'application.
///
/// Elle remplace la `NavigationBar` de Material, qui posait cinq icônes grises
/// sur un fond blanc : rien ne ressortait, et l'application entière paraissait
/// vide. Trois partis pris :
///
/// 1. **Un fond sombre en dégradé.** Une barre sombre sous des pages claires
///    ancre l'écran au lieu de s'y dissoudre. Les icônes blanches y tiennent à
///    plus de 10,9:1 — lisible en plein soleil, ce qui n'est pas un détail au
///    Cameroun.
/// 2. **La destination active porte la couleur de sa section.** La pastille
///    reprend le dégradé de l'en-tête de la page où elle mène : on voit d'un
///    coup d'œil où l'on est, et la couleur est un repère, pas un ornement.
/// 3. **L'icône et le libellé sont toujours tous les deux là.** Une barre à
///    icônes seules oblige à deviner ; celle-ci nomme ses destinations.
///
/// L'animation reste courte (180 ms) et ne déplace rien d'autre que la pastille :
/// on peut appuyer sur une autre destination pendant qu'elle se joue.
class MboaNavBar extends StatelessWidget {
  const MboaNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<MboaNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: kMboaNavGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MboaRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33312E81),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MboaSpace.sm,
            vertical: MboaSpace.sm,
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MboaNavDestination {
  const MboaNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.section,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// La section vers laquelle mène cette destination : elle donne sa couleur à
  /// la pastille active.
  final MboaSection section;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final MboaNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        child: Padding(
          // Le rembourrage porte la hauteur au-delà du seuil tactile même
          // lorsque l'icône et le libellé sont serrés.
          padding: const EdgeInsets.symmetric(vertical: MboaSpace.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: MboaMotion.quick,
                curve: Curves.easeOut,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: MboaSpace.lg),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(colors: destination.section.gradient)
                      : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(MboaRadius.lg),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: destination.section.debut.withValues(
                              alpha: 0.5,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  // Inactive : lavande claire. Mesurée à 6,11:1 sur l'indigo et
                  // 5,86:1 sur le violet de la barre — lisible sans
                  // concurrencer la destination active.
                  color: selected ? Colors.white : const Color(0xFFBFB8E8),
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFFBFB8E8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
