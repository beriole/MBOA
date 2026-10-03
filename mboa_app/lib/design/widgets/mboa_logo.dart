import 'package:flutter/material.dart';

import '../tokens.dart';

/// Les deux déclinaisons du logo MBOA, telles que fournies par le porteur.
///
/// Le fichier d'origine avait un fond crème opaque ; il a été détouré pour que
/// la marque puisse se poser aussi bien sur le fond clair que sur le dégradé
/// indigo de l'en-tête.
enum MboaLogoVariant {
  /// Marque complète, avec le mot-symbole et la signature.
  complet('assets/brand/mboa-logo.png'),

  /// Emblème seul : la feuille, le Cameroun et le visage. Pour les formats
  /// où le lettrage deviendrait illisible.
  embleme('assets/brand/mboa-embleme.png');

  const MboaLogoVariant(this.asset);

  final String asset;
}

/// Affiche le logo MBOA.
///
/// L'image porte son propre texte : on lui donne donc une étiquette
/// d'accessibilité explicite, et on la déclare comme image plutôt que de la
/// laisser muette pour un lecteur d'écran.
class MboaLogo extends StatelessWidget {
  const MboaLogo({
    super.key,
    this.variant = MboaLogoVariant.complet,
    this.height = 160,
  });

  final MboaLogoVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'MBOA — nos langues, notre héritage',
    child: ExcludeSemantics(
      child: Image.asset(
        variant.asset,
        height: height,
        fit: BoxFit.contain,
        // L'application doit rester lisible si l'asset venait à manquer.
        errorBuilder: (context, _, __) => Text(
          'MBOA',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: MboaColors.forest900,
            letterSpacing: 2,
          ),
        ),
      ),
    ),
  );
}
