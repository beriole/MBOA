import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/market/data/market_repository.dart';
import 'package:mboa_app/features/market/domain/models.dart';
import 'package:mboa_app/features/market/presentation/market_screen.dart';
import 'package:mboa_app/features/market/presentation/payment_choice.dart';
import 'package:mboa_app/features/market/presentation/product_detail_screen.dart';
import 'package:mboa_app/features/social/data/social_repository.dart';
import 'package:mboa_app/features/social/domain/models.dart';
import 'package:mboa_app/features/social/presentation/comments_section.dart';
import 'package:mocktail/mocktail.dart';

/// La boutique comme place de marché : grille, photos, avis, caisse simulée.
///
/// Trois limites sont vérifiées ici, parce qu'elles sont faciles à perdre en
/// rendant l'écran plus avenant :
///
///  - un produit sans photo reçoit un cadre qui le dit, jamais une image
///    d'emprunt ; un objet artisanal est unique ;
///  - la caisse de démonstration s'annonce comme telle, des deux côtés ;
///  - on note un objet, pas un fait culturel.
class _MockRepo extends Mock implements MarketRepository {}

class _MockSocial extends Mock implements SocialRepository {}

Map<String, dynamic> _productJson({
  List<Map<String, dynamic>> images = const [],
  double? rating,
  int reviews = 0,
  int stock = 3,
}) => {
  'id': 'p1',
  'title_fr': 'Panier en raphia',
  'description_fr': 'Panier tressé à la main.',
  'category': 'VANNERIE',
  'price_xaf': 12000,
  'stock': stock,
  'status': 'PUBLISHED',
  'shop_id': 's1',
  'shop_name': 'Atelier de vannerie',
  'shop_city': 'Edéa',
  'region_name': 'Littoral',
  'cultural_claim_fr': null,
  'cultural_claim_status': 'NONE',
  'images': images,
  'note_moyenne': rating,
  'avis': reviews,
};

Comments _comments({
  List<Map<String, dynamic>> items = const [],
  double? average,
  int voters = 0,
  bool rateable = true,
}) => Comments.fromJson({
  'commentaires': items,
  'avertissement':
      'Les commentaires expriment l’avis de leurs auteurs. '
      'Ils ne sont ni vérifiés ni sourcés, et ne font pas partie du '
      'contenu documenté.',
  'note_moyenne': average,
  'votants': voters,
  'notable': rateable,
});

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required MarketRepository repo,
  SocialRepository? social,
}) async {
  tester.view.physicalSize = const Size(1100, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // On ne stube que le double créé ici : réécrire celui que l'appelant
  // fournit effacerait la réponse qu'il vient de préparer.
  final avis = social ?? _defaultSocial();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketRepositoryProvider.overrideWithValue(repo),
        socialRepositoryProvider.overrideWithValue(avis),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Un double qui répond « aucun avis », pour les écrans où ce n'est pas le
/// sujet du test.
SocialRepository _defaultSocial() {
  final avis = _MockSocial();
  when(() => avis.comments(any(), any())).thenAnswer((_) async => _comments());
  return avis;
}

MarketRepository _catalogue(Map<String, dynamic> product) {
  final repo = _MockRepo();
  when(repo.categories).thenAnswer((_) async => [(code: 'VANNERIE', count: 1)]);
  when(
    () => repo.products(
      category: any(named: 'category'),
      query: any(named: 'query'),
      minPrice: any(named: 'minPrice'),
      maxPrice: any(named: 'maxPrice'),
      sort: any(named: 'sort'),
    ),
  ).thenAnswer(
    (_) async => CatalogPage(
      items: [Product.fromJson(product)],
      notice: 'Règlement à la livraison.',
      bounds: const CatalogBounds(total: 1, minPrice: 1000, maxPrice: 90000),
    ),
  );
  return repo;
}

void main() {
  group('grille du catalogue', () {
    testWidgets('les produits sont présentés en grille', (tester) async {
      await _pump(
        tester,
        const MarketScreen(),
        repo: _catalogue(_productJson()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(ProductTile), findsOneWidget);
      expect(find.text('Panier en raphia'), findsOneWidget);
    });

    testWidgets('un produit sans photo le dit au lieu d’en emprunter une', (
      tester,
    ) async {
      await _pump(
        tester,
        const MarketScreen(),
        repo: _catalogue(_productJson()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pas de photo'), findsOneWidget);
      expect(
        find.byType(Image),
        findsNothing,
        reason: 'aucune image n’est inventée pour combler la vignette',
      );
    });

    testWidgets('la note moyenne apparaît quand il y a des avis', (
      tester,
    ) async {
      await _pump(
        tester,
        const MarketScreen(),
        repo: _catalogue(_productJson(rating: 4.5, reviews: 2)),
      );
      await tester.pumpAndSettle();

      expect(find.text('4.5 (2)'), findsOneWidget);
    });

    testWidgets('sans avis, aucune note n’est affichée', (tester) async {
      await _pump(
        tester,
        const MarketScreen(),
        repo: _catalogue(_productJson()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('caisse', () {
    testWidgets('les deux règlements ouverts disent qu’aucun argent ne passe', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: PaymentChoice(value: 'CASH_ON_DELIVERY', onChanged: _ignore),
          ),
        ),
        repo: _MockRepo(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Espèces à la livraison'), findsOneWidget);
      expect(find.text('Paiement simulé (démonstration)'), findsOneWidget);
      expect(find.textContaining('n’encaisse rien'), findsOneWidget);
    });

    testWidgets('choisir la simulation prévient que rien n’est payé', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: PaymentChoice(value: 'SIMULATION', onChanged: _ignore),
          ),
        ),
        repo: _MockRepo(),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Aucun argent'), findsOneWidget);
      // L'artisan est prévenu aussi : c'est lui qui préparerait le colis.
      expect(
        find.textContaining('ne préparera pas d’envoi réel'),
        findsOneWidget,
      );
    });

    testWidgets('le mode choisi est transmis au serveur', (tester) async {
      final repo = _MockRepo();
      when(() => repo.product('p1')).thenAnswer(
        (_) async => ProductDetail.fromJson({
          ..._productJson(),
          'reglement': 'Règlement à la livraison.',
        }),
      );
      when(
        () => repo.order(
          productId: any(named: 'productId'),
          quantity: any(named: 'quantity'),
          city: any(named: 'city'),
          address: any(named: 'address'),
          phone: any(named: 'phone'),
          note: any(named: 'note'),
          paymentMode: any(named: 'paymentMode'),
        ),
      ).thenAnswer((_) async => 'MBOA-C-2026-4K7QPX');

      await _pump(
        tester,
        const ProductDetailScreen(productId: 'p1'),
        repo: repo,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commander'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Ville de livraison'),
        'Edéa',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Adresse'),
        'Quartier Bilalang',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Téléphone'),
        '+237600000000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paiement simulé (démonstration)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer la commande'));
      await tester.pumpAndSettle();

      verify(
        () => repo.order(
          productId: 'p1',
          quantity: 1,
          city: 'Edéa',
          address: 'Quartier Bilalang',
          phone: '+237600000000',
          note: any(named: 'note'),
          paymentMode: 'SIMULATION',
        ),
      ).called(1);
    });
  });

  group('avis', () {
    testWidgets('l’avertissement précède les commentaires', (tester) async {
      final social = _MockSocial();
      when(() => social.comments(any(), any())).thenAnswer(
        (_) async => _comments(
          items: [
            {
              'id': 'c1',
              'auteur': 'Awa',
              'body_fr': 'Le tressage est serré.',
              'rating': 4,
              'created_at': '2026-09-01T10:00:00+00:00',
            },
          ],
          average: 4,
          voters: 1,
        ),
      );

      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: CommentsSection(targetType: 'PRODUCT', targetId: 'p1'),
          ),
        ),
        repo: _MockRepo(),
        social: social,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ni vérifiés ni sourcés'), findsOneWidget);
      expect(find.text('Awa'), findsOneWidget);
      expect(find.text('Le tressage est serré.'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
    });

    testWidgets('on ne note pas ce qui ne se note pas', (tester) async {
      final social = _MockSocial();
      when(
        () => social.comments(any(), any()),
      ).thenAnswer((_) async => _comments(rateable: false));

      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: CommentsSection(
              targetType: 'CULTURAL_CONTENT',
              targetId: 'f1',
            ),
          ),
        ),
        repo: _MockRepo(),
        social: social,
      );
      await tester.pumpAndSettle();

      // Aucune étoile de saisie : on ne vote pas sur un fait établi.
      expect(find.text('Votre note'), findsNothing);
      expect(find.byIcon(Icons.star_border_rounded), findsNothing);
      // Le champ de commentaire, lui, reste ouvert.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('un commentaire écrit est envoyé au serveur', (tester) async {
      final social = _MockSocial();
      when(
        () => social.comments(any(), any()),
      ).thenAnswer((_) async => _comments(rateable: false));
      when(
        () => social.add(
          any(),
          any(),
          body: any(named: 'body'),
          rating: any(named: 'rating'),
        ),
      ).thenAnswer(
        (_) async => Comment.fromJson({
          'id': 'c9',
          'auteur': 'Moi',
          'body_fr': 'Très instructif.',
          'created_at': '2026-09-25T10:00:00+00:00',
        }),
      );

      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: CommentsSection(
              targetType: 'CULTURAL_CONTENT',
              targetId: 'f1',
            ),
          ),
        ),
        repo: _MockRepo(),
        social: social,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Très instructif.');
      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();

      verify(
        () => social.add(
          'CULTURAL_CONTENT',
          'f1',
          body: 'Très instructif.',
          rating: null,
        ),
      ).called(1);
    });
  });

  group('modèles', () {
    test('la vignette suit les photos déposées', () {
      final produit = Product.fromJson(
        _productJson(
          images: [
            {
              'id': 'i1',
              'url': '/api/v1/market/images/products/p1/a.jpg',
              'caption': null,
            },
            {
              'id': 'i2',
              'url': '/api/v1/market/images/products/p1/b.jpg',
              'caption': null,
            },
          ],
        ),
      );
      expect(produit.images, hasLength(2));
      expect(produit.coverUrl, '/api/v1/market/images/products/p1/a.jpg');
      expect(produit.hasNoPhoto, isFalse);
    });

    test('sans photo, le produit le sait', () {
      final produit = Product.fromJson(_productJson());
      expect(produit.hasNoPhoto, isTrue);
      expect(produit.coverUrl, isNull);
    });
  });
}

void _ignore(String _) {}
