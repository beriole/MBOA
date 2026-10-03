import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/market/data/market_repository.dart';
import 'package:mboa_app/features/market/domain/models.dart';
import 'package:mboa_app/features/market/presentation/claim_badge.dart';
import 'package:mboa_app/features/market/presentation/courier_screen.dart';
import 'package:mboa_app/features/market/presentation/market_screen.dart';
import 'package:mboa_app/features/market/presentation/my_orders_screen.dart';
import 'package:mboa_app/features/market/presentation/product_detail_screen.dart';
import 'package:mboa_app/features/social/data/social_repository.dart';
import 'package:mboa_app/features/social/domain/models.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MarketRepository {}

class _MockSocial extends Mock implements SocialRepository {}

/// Un bloc d'avis vide, servi instantanément.
///
/// Sans cette réponse, la fiche produit reste sur son indicateur de
/// chargement, qui tourne indéfiniment : `pumpAndSettle` n'a alors plus rien
/// de stable à attendre et échoue par expiration.
Comments _emptyComments({bool rateable = true}) => Comments.fromJson({
  'commentaires': const [],
  'avertissement': 'Les commentaires expriment l’avis de leurs auteurs.',
  'note_moyenne': null,
  'votants': 0,
  'notable': rateable,
});

Map<String, dynamic> _productJson({
  String? claim,
  String claimStatus = 'NONE',
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
  'cultural_claim_fr': claim,
  'cultural_claim_status': claimStatus,
};

const _notice =
    'Le règlement se fait en espèces, au livreur, à la remise. '
    'MBOA n’encaisse rien.';

Map<String, dynamic> _orderJson({
  String status = 'IN_DELIVERY',
  List<Map<String, dynamic>> timeline = const [],
}) => {
  'id': 'o1',
  'reference': 'MBOA-C-2026-4K7QPX',
  'status': status,
  'total_xaf': 12000,
  'shop_name': 'Atelier de vannerie',
  'delivery_city': 'Edéa',
  'created_at': '2026-09-25T09:00:00+00:00',
  'lignes': [
    {'title_fr': 'Panier en raphia', 'unit_price_xaf': 12000, 'quantity': 1},
  ],
  'timeline': timeline,
  'delivery_status': 'IN_TRANSIT',
  'courier_name': 'Moussa',
  'courier_phone': '+237600000000',
};

Map<String, dynamic> _deliveryJson({String status = 'ASSIGNED'}) => {
  'id': 'd1',
  'reference': 'MBOA-C-2026-4K7QPX',
  'total_xaf': 12000,
  'dropoff_city': 'Edéa',
  'pickup_city': 'Edéa',
  'delivery_address_fr': 'Quartier Bilalang, face au marché.',
  'shop_name': 'Atelier de vannerie',
  'delivery_phone': '+237611111111',
  'status': status,
  'timeline': const [],
};

/// `find.byType` compare le type exact : `FilledButton.icon` construit une
/// sous-classe, que `widgetWithText` ne retrouverait pas.
Finder _filledButton(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is FilledButton),
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  MarketRepository repo, {
  SocialRepository? social,
}) async {
  tester.view.physicalSize = const Size(1100, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final avis = social ?? _MockSocial();
  when(
    () => avis.comments(any(), any()),
  ).thenAnswer((_) async => _emptyComments());

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

void main() {
  group('catalogue', () {
    testWidgets('le mode de règlement est affiché avec les objets', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        repo.categories,
      ).thenAnswer((_) async => [(code: 'VANNERIE', count: 1)]);
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
          items: [Product.fromJson(_productJson())],
          notice: _notice,
          bounds: const CatalogBounds(
            total: 1,
            minPrice: 1000,
            maxPrice: 90000,
          ),
        ),
      );

      await _pump(tester, const MarketScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Panier en raphia'), findsOneWidget);
      expect(find.text('12 000 FCFA'), findsOneWidget);
      expect(find.textContaining('n’encaisse rien'), findsOneWidget);
      // MBOA dit ce qu'elle est dans cette relation.
      expect(
        find.textContaining('MBOA met en relation et n’achète rien'),
        findsOneWidget,
      );
    });

    testWidgets('un catalogue vide explique pourquoi', (tester) async {
      final repo = _MockRepo();
      when(repo.categories).thenAnswer((_) async => []);
      when(() => repo.products(category: any(named: 'category'))).thenAnswer(
        (_) async => CatalogPage(
          items: <Product>[],
          notice: _notice,
          bounds: const CatalogBounds(
            total: 1,
            minPrice: 1000,
            maxPrice: 90000,
          ),
        ),
      );

      await _pump(tester, const MarketScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Aucun objet en vente ici'), findsOneWidget);
      expect(find.textContaining('dossiers d’artisans'), findsOneWidget);
    });
  });

  group('affirmation culturelle', () {
    testWidgets(
      'une déclaration de l’artisan n’est pas présentée comme un fait',
      (tester) async {
        final repo = _MockRepo();
        when(() => repo.product(any())).thenAnswer(
          (_) async => ProductDetail.fromJson({
            ..._productJson(
              claim: 'Masque utilisé lors des cérémonies d’initiation.',
              claimStatus: 'ARTISAN_DECLARATION',
            ),
            'reglement': _notice,
          }),
        );

        await _pump(tester, const ProductDetailScreen(productId: 'p1'), repo);
        await tester.pumpAndSettle();

        expect(find.text('Ce que le vendeur dit de cet objet'), findsOneWidget);
        expect(find.text('Déclaration de l’artisan'), findsOneWidget);
        expect(find.textContaining('MBOA ne l’a pas vérifiée'), findsOneWidget);
      },
    );

    testWidgets('une affirmation documentée renvoie à sa fiche', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(() => repo.product(any())).thenAnswer(
        (_) async => ProductDetail.fromJson({
          ..._productJson(
            claim: 'Pagne ndop, porté lors des funérailles.',
            claimStatus: 'LINKED_TO_SOURCE',
          ),
          'reglement': _notice,
          'fiche_culturelle': {
            'id': 'f1',
            'title_fr': 'Le pagne ndop',
            'summary_fr': 'Résumé',
            'source_title': 'Hyman 2003',
          },
        }),
      );

      await _pump(tester, const ProductDetailScreen(productId: 'p1'), repo);
      await tester.pumpAndSettle();

      expect(find.text('Documenté par une fiche MBOA'), findsOneWidget);
      expect(find.text('Le pagne ndop'), findsOneWidget);
      expect(find.text('Source : Hyman 2003'), findsOneWidget);
    });

    testWidgets('un objet sans affirmation n’affiche aucune étiquette', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(() => repo.product(any())).thenAnswer(
        (_) async =>
            ProductDetail.fromJson({..._productJson(), 'reglement': _notice}),
      );

      await _pump(tester, const ProductDetailScreen(productId: 'p1'), repo);
      await tester.pumpAndSettle();

      expect(find.byType(ClaimBadge), findsNothing);
      expect(find.text('Ce que le vendeur dit de cet objet'), findsNothing);
    });
  });

  group('commande', () {
    testWidgets('le formulaire annonce le règlement en espèces', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(() => repo.product(any())).thenAnswer(
        (_) async =>
            ProductDetail.fromJson({..._productJson(), 'reglement': _notice}),
      );

      await _pump(tester, const ProductDetailScreen(productId: 'p1'), repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commander'));
      await tester.pumpAndSettle();

      expect(find.text('Total à régler'), findsOneWidget);
      expect(
        find.textContaining('ne demande aucune donnée bancaire'),
        findsOneWidget,
      );
      // Rien n'est envoyable tant que l'adresse manque.
      final bouton = _filledButton('Envoyer la commande');
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
    });

    testWidgets('un objet épuisé ne se commande pas', (tester) async {
      final repo = _MockRepo();
      when(() => repo.product(any())).thenAnswer(
        (_) async => ProductDetail.fromJson({
          ..._productJson(stock: 0),
          'reglement': _notice,
        }),
      );

      await _pump(tester, const ProductDetailScreen(productId: 'p1'), repo);
      await tester.pumpAndSettle();

      expect(find.text('Épuisé'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_filledButton('Épuisé')).onPressed,
        isNull,
      );
    });

    testWidgets('le suivi affiche les étapes réellement renseignées', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.myOrders).thenAnswer(
        (_) async => [
          Order.fromJson(
            _orderJson(
              timeline: const [
                {
                  'status': 'ASSIGNED',
                  'at': '2026-09-25T10:00:00+00:00',
                  'note': 'Moussa',
                },
                {
                  'status': 'PICKED_UP',
                  'at': '2026-09-25T10:30:00+00:00',
                  'note': null,
                },
              ],
            ),
          ),
        ],
      );

      await _pump(tester, const MyOrdersScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('MBOA-C-2026-4K7QPX'), findsOneWidget);
      expect(find.text('En cours de livraison'), findsOneWidget);
      expect(find.text('Course acceptée par un livreur'), findsOneWidget);
      expect(find.text('Colis récupéré chez l’artisan'), findsOneWidget);
      // En livraison, l'annulation n'est plus proposée.
      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('une commande livrée rappelle que MBOA n’a rien encaissé', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.myOrders).thenAnswer(
        (_) async => [Order.fromJson(_orderJson(status: 'DELIVERED'))],
      );

      await _pump(tester, const MyOrdersScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Livrée'), findsOneWidget);
      expect(find.textContaining('n’a encaissé aucune somme'), findsOneWidget);
    });
  });

  group('espace livreur', () {
    testWidgets('la remise exige de déclarer la somme reçue', (tester) async {
      final repo = _MockRepo();
      when(repo.courier).thenAnswer(
        (_) async => CourierDashboard.fromJson({
          'livreur': {
            'id': 'c1',
            'display_name': 'Moussa',
            'phone': '+237600000000',
            'vehicle': 'MOTORCYCLE',
            'cities': ['Edéa'],
            'is_available': true,
          },
          'chiffres': {
            'livrees': 4,
            'en_cours': 1,
            'echouees': 0,
            'especes_declarees': 48000,
          },
          'note':
              'Les espèces déclarées sont ce que vous avez saisi avoir reçu.',
        }),
      );
      when(repo.myDeliveries).thenAnswer(
        (_) async => [Delivery.fromJson(_deliveryJson(status: 'IN_TRANSIT'))],
      );
      when(
        () => repo.advanceDelivery(
          any(),
          status: any(named: 'status'),
          note: any(named: 'note'),
          cashDeclaredXaf: any(named: 'cashDeclaredXaf'),
        ),
      ).thenAnswer((_) async => 0);

      await _pump(tester, const CourierScreen(), repo);
      await tester.pumpAndSettle();
      // L'écran livreur n'utilise plus d'onglets Material : il a une barre de
      // navigation, et « En cours » y désigne désormais un compteur du tableau
      // de bord, pas une destination. La liste des courses est sous « Mes
      // courses ».
      await tester.tap(find.text('Mes courses'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('J’ai remis le colis'));
      await tester.pumpAndSettle();

      expect(find.text('Remise du colis'), findsOneWidget);
      expect(find.textContaining('ne certifie pas ce montant'), findsOneWidget);
      // Le libellé et le montant sont désormais sur deux widgets, aux deux
      // bouts d'une ligne. L'exigence est la même : le livreur voit ce qu'il
      // doit avoir reçu avant de saisir.
      expect(find.text('Montant attendu :'), findsOneWidget);
      expect(find.text('12 000 FCFA'), findsWidgets);

      await tester.tap(_filledButton('Confirmer la livraison & la remise'));
      await tester.pumpAndSettle();

      verify(
        () => repo.advanceDelivery(
          'd1',
          status: 'DELIVERED',
          note: '',
          cashDeclaredXaf: 12000,
        ),
      ).called(1);
    });

    testWidgets('un écart de caisse doit être expliqué avant confirmation', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.courier).thenAnswer(
        (_) async => CourierDashboard.fromJson({
          'livreur': {
            'id': 'c1',
            'display_name': 'Moussa',
            'phone': null,
            'vehicle': 'BICYCLE',
            'cities': ['Edéa'],
            'is_available': true,
          },
          'chiffres': {
            'livrees': 0,
            'en_cours': 1,
            'echouees': 0,
            'especes_declarees': 0,
          },
          'note': 'note',
        }),
      );
      when(repo.myDeliveries).thenAnswer(
        (_) async => [Delivery.fromJson(_deliveryJson(status: 'IN_TRANSIT'))],
      );

      await _pump(tester, const CourierScreen(), repo);
      await tester.pumpAndSettle();
      // L'écran livreur n'utilise plus d'onglets Material : il a une barre de
      // navigation, et « En cours » y désigne désormais un compteur du tableau
      // de bord, pas une destination. La liste des courses est sous « Mes
      // courses ».
      await tester.tap(find.text('Mes courses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('J’ai remis le colis'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '10000');
      await tester.pumpAndSettle();

      expect(find.textContaining('Écart de -2000 FCFA'), findsOneWidget);
      final bouton = _filledButton('Confirmer la livraison & la remise');
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);

      await tester.enterText(
        find.byType(TextField).last,
        'Client sans appoint.',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(bouton).onPressed, isNotNull);
    });

    testWidgets('un livreur indisponible voit le message du serveur', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.courier).thenAnswer(
        (_) async => CourierDashboard.fromJson({
          'livreur': {
            'id': 'c1',
            'display_name': 'Moussa',
            'phone': null,
            'vehicle': 'MOTORCYCLE',
            'cities': ['Edéa'],
            'is_available': false,
          },
          'chiffres': {
            'livrees': 0,
            'en_cours': 0,
            'echouees': 0,
            'especes_declarees': 0,
          },
          'note': 'note',
        }),
      );
      when(repo.availableDeliveries).thenAnswer(
        (_) async => (
          items: <Delivery>[],
          message:
              'Vous etes en indisponible. Passez-vous disponible pour voir les courses.',
        ),
      );

      await _pump(tester, const CourierScreen(), repo);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Disponibles'));
      await tester.pumpAndSettle();

      expect(find.textContaining('indisponible'), findsWidgets);
      expect(find.textContaining('Passez-vous disponible'), findsOneWidget);
    });
  });

  group('modèles', () {
    test('les francs CFA sont groupés par milliers', () {
      expect(formatXaf(12000), '12 000 FCFA');
      expect(formatXaf(500), '500 FCFA');
      expect(formatXaf(1250000), '1 250 000 FCFA');
    });

    test('l’étape suivante d’une course est déterminée par son état', () {
      Delivery at(String status) =>
          Delivery.fromJson(_deliveryJson(status: status));
      expect(at('ASSIGNED').nextStatus, 'PICKED_UP');
      expect(at('PICKED_UP').nextStatus, 'IN_TRANSIT');
      expect(at('IN_TRANSIT').nextStatus, 'DELIVERED');
      // Une course close ne propose plus rien.
      expect(at('DELIVERED').nextStatus, isNull);
      expect(at('FAILED').nextLabel, isNull);
    });

    test('une commande n’est annulable qu’avant la préparation', () {
      bool annulable(String status) =>
          Order.fromJson(_orderJson(status: status)).isCancellable;
      expect(annulable('PENDING_CONFIRMATION'), isTrue);
      expect(annulable('CONFIRMED'), isTrue);
      expect(annulable('READY_FOR_PICKUP'), isFalse);
      expect(annulable('IN_DELIVERY'), isFalse);
    });

    test('un statut d’affirmation inconnu retombe sur « aucune »', () {
      expect(CulturalClaim.parse('QUELQUE_CHOSE'), CulturalClaim.none);
      expect(CulturalClaim.parse(null), CulturalClaim.none);
      expect(CulturalClaim.none.label, isEmpty);
    });
  });
}
