import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';

/// La vignette d'un produit, ou l'aveu qu'il n'y en a pas.
///
/// Cette absence mérite son propre widget, parce que la tentation de la combler
/// est forte : une grille de place de marché avec des cases vides paraît
/// inachevée, et une image d'illustration la rendrait immédiatement plus jolie.
///
/// Ce serait un mensonge. Un objet artisanal est unique — le panier photographié
/// dans une banque d'images n'est pas celui que l'acheteur recevra. MBOA affiche
/// donc un cadre qui dit ce qu'il en est, et l'artisan est invité à déposer ses
/// propres photos.
class ProductPhoto extends StatelessWidget {
  const ProductPhoto({
    super.key,
    required this.url,
    required this.title,
    this.fit,
  });

  final String? url;
  final String title;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    if (url == null) return _Absente(title: title);

    return Image.network(
      url!.startsWith('/') ? '$kApiBase${url!}' : url!,
      fit: fit ?? BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const ColoredBox(
              color: MboaColors.sable100,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      // Une photo qui ne charge pas retombe sur le même aveu : mieux vaut dire
      // qu'il n'y a rien à voir qu'afficher une icône de fichier cassé.
      errorBuilder: (context, error, stack) => _Absente(title: title),
    );
  }
}

class _Absente extends StatelessWidget {
  const _Absente({required this.title});
  final String title;

  /// En dessous, le libellé ne tient plus et n'était de toute façon plus
  /// lisible. L'icône suffit, et le texte reste annoncé aux lecteurs d'écran
  /// par le [Semantics] qui enveloppe le tout.
  static const _libelleMin = 110.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aucune photo pour $title',
      child: LayoutBuilder(
        builder: (context, contraintes) {
          final place =
              contraintes.maxHeight >= _libelleMin &&
              contraintes.maxWidth >= _libelleMin;
          return Container(
            color: MboaColors.sable100,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(MboaSpace.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: MboaColors.encre400,
                  size: place ? 28 : 20,
                ),
                if (place) ...[
                  const SizedBox(height: MboaSpace.xs),
                  Flexible(
                    child: Text(
                      'Pas de photo',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
