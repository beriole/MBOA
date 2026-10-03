import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/market/domain/models.dart';
import 'package:mboa_app/features/market/presentation/market_screen.dart';
import 'package:mboa_app/features/market/presentation/product_photo.dart';

/// La vignette d'un objet doit tenir à tous les grossissements de texte.
///
/// Sa hauteur ne peut pas être une constante : le texte grossit avec le réglage
/// système, la photo non. Deux exigences, vérifiées à quatre échelles :
///
/// 1. **Rien ne déborde.** Le bloc de texte a une hauteur réservée ; si elle est
///    trop courte, Flutter signale un débordement et le test le voit.
/// 2. **La photo reste visible.** Réserver trop de place au texte ferait
///    disparaître l'image, ce qui n'est pas mieux qu'un débordement.
///
/// Le test ne compare plus la hauteur calculée à la hauteur mesurée : depuis que
/// le bloc de texte occupe exactement la hauteur réservée, les deux grandeurs
/// sont liées et leur comparaison ne prouve plus rien. C'est l'absence de
/// débordement qui porte l'exigence.
void main() {
  testWidgets('la vignette tient à tous les grossissements de texte', (
    tester,
  ) async {
    final produit = Product.fromJson({
      'id': 'p1',
      'title_fr': 'Panier en raphia tressé à la main, grand format',
      'category': 'VANNERIE',
      'price_xaf': 12000,
      'stock': 3,
      'status': 'PUBLISHED',
      'shop_id': 's1',
      'shop_name': 'Atelier de vannerie',
      'shop_city': 'Edéa',
      'cultural_claim_status': 'ARTISAN_DECLARATION',
      'images': const [],
      'note_moyenne': 4.5,
      'avis': 2,
      'shop_is_demo': true,
    });

    for (final echelle in [1.0, 1.5, 2.0, 3.0]) {
      // La largeur est celle que la grille donnerait vraiment sur un
      // téléphone de 390 points, à ce grossissement : au-delà de 150 %, elle
      // passe à une colonne, et mesurer une vignette étroite à 200 %
      // reviendrait à tester une mise en page que personne ne voit.
      final largeur = MarketScreenProbe.tileWidth(390, echelle);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(echelle)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: Builder(
                    builder: (context) => SizedBox(
                      width: largeur,
                      height:
                          largeur + MarketScreenProbe.contentHeight(context),
                      child: ProductTile(product: produit),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'à l’échelle $echelle, la vignette déborde : quelqu’un qui a '
            'grossi le texte de son téléphone verrait des bandes '
            'd’avertissement à la place du catalogue',
      );

      final photo = tester.getSize(find.byType(ProductPhoto));
      expect(
        photo.height,
        greaterThan(40),
        reason:
            'à l’échelle $echelle, la photo est réduite à ${photo.height} px : '
            'le texte lui prend toute la place',
      );
    }
  });
}
