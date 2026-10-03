import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/design/theme.dart';
import 'package:mboa_app/design/tokens.dart';
import 'package:mboa_app/features/culture/data/culture_repository.dart';
import 'package:mboa_app/features/culture/domain/feed_models.dart';
import 'package:mboa_app/features/culture/presentation/feed_screen.dart';
import 'package:mboa_app/features/market/data/market_repository.dart';
import 'package:mboa_app/features/market/domain/models.dart';
import 'package:mboa_app/features/market/presentation/market_screen.dart';
import 'package:mboa_app/features/market/presentation/product_photos_editor.dart';
import 'package:mboa_app/features/social/data/social_repository.dart';
import 'package:mboa_app/features/social/domain/models.dart';
import 'package:mboa_app/features/social/presentation/comments_section.dart';
import 'package:mocktail/mocktail.dart';

/// Contrôles d'interface applicables à tout l'écran, pas à une fonction.
///
/// Trois exigences sont vérifiées ici parce qu'elles ne se voient pas en
/// regardant une maquette sur un écran de bureau, à taille de texte normale :
///
///  - **la cible tactile** : 48 dp minimum, faute de quoi un bouton existe à
///    l'œil mais pas au doigt ;
///  - **le grossissement du texte** : quelqu'un qui a réglé son téléphone sur
///    200 % doit pouvoir se servir de l'application, pas voir des bandes
///    d'avertissement de débordement ;
///  - **l'étiquette d'un champ** : un intitulé qui disparaît dès la première
///    lettre tapée n'est pas une étiquette.
class _MockRepo extends Mock implements MarketRepository {}

class _MockSocial extends Mock implements SocialRepository {}

class _MockCulture extends Mock implements CultureRepository {}

CultureRepository _fil() {
  final culture = _MockCulture();
  when(() => culture.feed(regionId: any(named: 'regionId'))).thenAnswer(
    (_) async => Feed.fromJson({
      'posts': [
        {
          'id': 'f1',
          'kind': 'FICHE',
          'titre': 'Le basaa se parle sur quatre tons, et cela change le sens',
          'target_type': 'CULTURAL_CONTENT',
          'texte': 'En basaa, la hauteur de la voix distingue les mots.',
          'corps': 'Texte complet.',
          'categorie': 'Langue',
          'region': 'Littoral',
          'langue': 'Basaa',
          'minutes': 2,
          'media': const [],
          'date': '2026-09-01T10:00:00+00:00',
          'source': {
            'title': 'Makasso & Lee, Basaa',
            'authors': ['Makasso', 'Lee'],
            'year': 2015,
            'url': null,
          },
          'commentaires': 2,
          'favoris': 3,
        },
      ],
      'compteurs': {
        'fiches': 1,
        'enregistrements': 0,
        'videos': 0,
        'images': 0,
      },
      'manques': [
        {'kind': 'VIDEO', 'message': 'Aucune vidéo au catalogue.'},
      ],
      'avertissement':
          'Chaque publication de ce fil est passée par la validation.',
    }),
  );
  when(() => culture.isFavorite(any(), any())).thenAnswer((_) async => false);
  return culture;
}

Map<String, dynamic> _productJson({
  List<Map<String, dynamic>> images = const [],
}) => {
  'id': 'p1',
  'title_fr': 'Panier en raphia tressé à la main, grand format',
  'description_fr': 'Panier tressé à la main.',
  'category': 'VANNERIE',
  'price_xaf': 12000,
  'stock': 3,
  'status': 'PUBLISHED',
  'shop_id': 's1',
  'shop_name': 'Atelier de vannerie',
  'shop_city': 'Edéa',
  'region_name': 'Littoral',
  'cultural_claim_fr': 'Panier utilisé pour le transport des récoltes.',
  'cultural_claim_status': 'ARTISAN_DECLARATION',
  'images': images,
  'note_moyenne': 4.5,
  'avis': 2,
};

MarketRepository _catalogue() {
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
      items: [Product.fromJson(_productJson())],
      notice: 'Règlement à la livraison.',
      bounds: const CatalogBounds(total: 1, minPrice: 1000, maxPrice: 90000),
    ),
  );
  return repo;
}

SocialRepository _social() {
  final avis = _MockSocial();
  when(() => avis.comments(any(), any())).thenAnswer(
    (_) async => Comments.fromJson(const {
      'commentaires': [],
      'avertissement': 'Les commentaires expriment l’avis de leurs auteurs.',
      'votants': 0,
      'notable': true,
    }),
  );
  return avis;
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  MarketRepository? repo,
  SocialRepository? social,
  CultureRepository? culture,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketRepositoryProvider.overrideWithValue(repo ?? _MockRepo()),
        socialRepositoryProvider.overrideWithValue(social ?? _social()),
        cultureRepositoryProvider.overrideWithValue(culture ?? _fil()),
      ],
      child: MaterialApp(
        // Le thème réel de l'application : sans lui, l'audit mesurerait les
        // valeurs Material par défaut et validerait un écran qui n'existe pas.
        theme: buildMboaTheme(),
        // `copyWith` et non un `MediaQueryData` neuf : remplacer l'objet
        // entier effacerait la taille de l'écran, et l'on testerait une
        // fenêtre de zéro pixel.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Toutes les zones tapables rendues, avec leur taille réelle.
///
/// On mesure le composant qui **porte** la zone tactile, pas l'effet d'encre
/// qu'il contient. Material étend la zone sensible d'un `IconButton` ou d'une
/// puce au-delà de leur dessin : leur `InkWell` fait 40 dp alors que le doigt
/// dispose bien de 48. Mesurer l'encre ferait crier au défaut là où il n'y en
/// a pas — et masquerait les vrais, noyés dans le bruit.
Iterable<({String quoi, Size taille})> _touchTargets(
  WidgetTester tester,
) sync* {
  final porteurs = <RenderBox>{};

  for (final type in ['IconButton', 'RawChip']) {
    for (final element
        in find
            .byWidgetPredicate((w) => w.runtimeType.toString() == type)
            .evaluate()) {
      final box = element.renderObject;
      if (box is RenderBox && box.hasSize) {
        porteurs.add(box);
        yield (quoi: type, taille: box.size);
      }
    }
  }

  // Les zones tapables restantes : celles qui ne sont contenues dans aucun
  // composant déjà mesuré.
  for (final element
      in find
          .byWidgetPredicate((w) => w is InkWell || w is InkResponse)
          .evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;

    var ancetre = box.parent;
    var contenu = false;
    while (ancetre != null) {
      if (porteurs.contains(ancetre)) {
        contenu = true;
        break;
      }
      ancetre = ancetre.parent;
    }
    if (!contenu) yield (quoi: 'InkWell', taille: box.size);
  }
}

void main() {
  group('cibles tactiles', () {
    testWidgets('aucune commande n’est plus petite que le seuil', (
      tester,
    ) async {
      await _pump(tester, const MarketScreen(), repo: _catalogue());
      await tester.pumpAndSettle();

      final trop = _touchTargets(tester)
          .where(
            (t) =>
                t.taille.height < kMinTouchTarget ||
                t.taille.width < kMinTouchTarget,
          )
          .map((t) => '${t.quoi} ${t.taille}')
          .toList();
      expect(
        trop,
        isEmpty,
        reason:
            'une commande plus petite que $kMinTouchTarget dp existe à '
            'l’œil mais pas au doigt (trouvé : $trop)',
      );
    });

    testWidgets(
      'les puces de la feuille de filtres étendent leur zone tactile',
      (tester) async {
        await _pump(tester, const MarketScreen(), repo: _catalogue());
        await tester.pumpAndSettle();

        // Le bandeau de catégories n'utilise plus de `ChoiceChip` : ce sont des
        // pastilles dessinées, mesurées par le contrôle général au-dessus. Les
        // puces Material subsistent dans la feuille de filtres, et c'est là
        // qu'on vérifie leur zone tactile.
        // `OutlinedButton.icon` construit un `_OutlinedButtonWithIcon` :
        // `widgetWithText(OutlinedButton, …)` ne le trouve pas, car ce finder
        // compare le type exact.
        await tester.tap(
          find.ancestor(
            of: find.text('Filtrer'),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          ),
        );
        await tester.pumpAndSettle();

        final puces = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
        expect(
          puces,
          isNotEmpty,
          reason: 'la feuille de filtres doit s’ouvrir',
        );
        for (final puce in puces) {
          expect(
            puce.materialTapTargetSize,
            MaterialTapTargetSize.padded,
            reason:
                'une puce dessinée à 40 dp sans zone tactile étendue se '
                'rate au doigt',
          );
        }
      },
    );

    testWidgets('le retrait d’une photo reste atteignable', (tester) async {
      final produit = Product.fromJson(
        _productJson(
          images: [
            {
              'id': 'i1',
              'url': '/api/v1/market/images/products/p1/a.jpg',
              'caption': null,
            },
          ],
        ),
      );

      await _pump(
        tester,
        Scaffold(body: ProductPhotosEditor(product: produit)),
      );
      await tester.pumpAndSettle();

      final bouton = find.byTooltip('Retirer cette photo');
      expect(bouton, findsOneWidget);

      // Un bouton posé en débord d'une Stack est dessiné mais ne reçoit pas le
      // toucher : la zone est hors des limites du parent. On vérifie donc que
      // son centre tombe bien à l'intérieur de l'éditeur.
      final zone = tester.getRect(bouton);
      final editeur = tester.getRect(find.byType(ProductPhotosEditor));
      expect(
        editeur.contains(zone.center),
        isTrue,
        reason:
            'le bouton de retrait déborde de son parent : il est visible '
            'mais ne répond pas au toucher (bouton $zone, parent $editeur)',
      );
    });
  });

  group('grossissement du texte', () {
    testWidgets('la grille tient à 200 %', (tester) async {
      await _pump(
        tester,
        const MarketScreen(),
        repo: _catalogue(),
        textScale: 2.0,
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'la grille déborde quand le texte est grossi : quelqu’un qui a '
            'réglé son téléphone sur 200 % ne peut pas s’en servir',
      );
    });

    testWidgets('le bloc d’avis tient à 200 %', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: CommentsSection(targetType: 'PRODUCT', targetId: 'p1'),
          ),
        ),
        textScale: 2.0,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('fil du patrimoine', () {
    testWidgets('aucune commande n’est plus petite que le seuil', (
      tester,
    ) async {
      await _pump(tester, const CultureFeedScreen());
      await tester.pumpAndSettle();

      final trop = _touchTargets(tester)
          .where(
            (t) =>
                t.taille.height < kMinTouchTarget ||
                t.taille.width < kMinTouchTarget,
          )
          .map((t) => '${t.quoi} ${t.taille}')
          .toList();
      expect(trop, isEmpty, reason: 'trouvé : $trop');
    });

    testWidgets('le fil tient à 200 %', (tester) async {
      await _pump(tester, const CultureFeedScreen(), textScale: 2.0);
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'le fil déborde au grossissement de texte le plus courant '
            'chez les personnes qui en ont besoin',
      );
    });
  });

  group('étiquettes de saisie', () {
    testWidgets('le champ de commentaire porte une étiquette persistante', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: CommentsSection(targetType: 'PRODUCT', targetId: 'p1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final champ = tester.widget<TextField>(find.byType(TextField));
      expect(
        champ.decoration?.labelText,
        isNotNull,
        reason:
            'un intitulé posé en placeholder disparaît dès la première '
            'lettre : il ne reste plus rien pour dire ce qu’on écrit',
      );
    });
  });
}
