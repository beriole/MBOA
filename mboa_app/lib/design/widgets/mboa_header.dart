import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// En-tête dégradé indigo → violet, présent sur toutes les planches.
///
/// Il remplace l'`AppBar` sur les écrans de premier niveau : le dégradé passe
/// sous la barre d'état, et le contenu de la page vient s'y adosser.
///
/// Les deux extrémités du dégradé portent du texte blanc à plus de 5,7:1 ; les
/// icônes système passent en clair pour rester lisibles.
class MboaGradientHeader extends StatelessWidget {
  const MboaGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.child,
    this.section = MboaSection.accueil,
  });

  final String title;
  final String? subtitle;

  /// Bouton de retour ou avatar, à gauche du titre.
  final Widget? leading;
  final List<Widget> actions;

  /// Contenu supplémentaire posé sous le titre, dans le dégradé.
  final Widget? child;

  /// La section à laquelle appartient l'écran : elle donne son dégradé.
  ///
  /// Toutes les pages partageaient le même indigo, et l'on ne savait pas où
  /// l'on se trouvait. Chaque section a désormais le sien, et la pastille
  /// active de la barre de navigation reprend le même — les deux repères se
  /// répondent.
  final MboaSection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: section.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(MboaRadius.xl),
          ),
          boxShadow: [
            BoxShadow(
              color: section.debut.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MboaSpace.lg,
              MboaSpace.md,
              MboaSpace.lg,
              MboaSpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: MboaSpace.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: text.headlineMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: text.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
                if (child != null) ...[
                  const SizedBox(height: MboaSpace.lg),
                  child!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton de retour posé sur le dégradé.
class MboaHeaderBack extends StatelessWidget {
  const MboaHeaderBack({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
    tooltip: 'Revenir',
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

/// Action posée sur le dégradé (cloche, recherche…).
class MboaHeaderAction extends StatelessWidget {
  const MboaHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, color: Colors.white),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}
