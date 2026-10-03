/// Produit les captures de la place de marché pour le dossier.
///
///   flutter test test/market_captures_test.dart --dart-define=CAPTURE=true
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/design/theme.dart';
import 'package:mboa_app/features/market/data/market_repository.dart';
import 'package:mboa_app/features/market/domain/models.dart';
import 'package:mboa_app/features/market/presentation/courier_screen.dart';
import 'package:mboa_app/features/market/presentation/market_screen.dart';
import 'package:mboa_app/features/market/presentation/product_detail_screen.dart';
import 'package:mboa_app/features/social/data/social_repository.dart';
import 'package:mboa_app/features/social/domain/models.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MarketRepository {}

const _captureEnabled = bool.fromEnvironment('CAPTURE');
final _boundary = GlobalKey();
final _shots = Directory('../docs/captures');

const _notice =
    'Le règlement se fait en espèces, au livreur, à la remise. '
    'MBOA n’encaisse rien et ne conserve aucune donnée bancaire.';

/// État correspondant à celui produit par scripts.demo_marche.
final _products = [
  Product.fromJson({
    'id': 'p1',
    'title_fr': 'Panier en raphia',
    'description_fr': 'Panier tressé à la main, environ 30 cm.',
    'category': 'VANNERIE',
    'price_xaf': 12000,
    'stock': 3,
    'status': 'PUBLISHED',
    'shop_id': 's1',
    'shop_name': 'Atelier de vannerie',
    'shop_city': 'Edéa',
    'cultural_claim_fr': 'Panier utilisé pour le transport des récoltes.',
    'cultural_claim_status': 'ARTISAN_DECLARATION',
  }),
  Product.fromJson({
    'id': 'p2',
    'title_fr': 'Natte tressée',
    'description_fr': 'Natte en raphia, deux mètres.',
    'category': 'VANNERIE',
    'price_xaf': 25000,
    'stock': 1,
    'status': 'PUBLISHED',
    'shop_id': 's1',
    'shop_name': 'Atelier de vannerie',
    'shop_city': 'Edéa',
    'cultural_claim_status': 'NONE',
  }),
];

final _detail = ProductDetail.fromJson({
  'id': 'p1',
  'title_fr': 'Panier en raphia',
  'description_fr':
      'Panier tressé à la main, environ 30 cm de diamètre. '
      'Chaque pièce est unique ; le motif varie selon la saison de récolte.',
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
  'reglement': _notice,
});

final _courier = CourierDashboard.fromJson({
  'livreur': {
    'id': 'c1',
    'display_name': 'Moussa',
    'phone': '+237600000000',
    'vehicle': 'MOTORCYCLE',
    'cities': ['Edéa', 'Douala'],
    'is_available': true,
  },
  'chiffres': {
    'livrees': 12,
    'en_cours': 1,
    'echouees': 1,
    'especes_declarees': 148000,
  },
  'note':
      'Les espèces déclarées sont ce que vous avez saisi avoir reçu. '
      'MBOA n’encaisse rien et ne certifie pas ces montants.',
});

final _available = [
  Delivery.fromJson({
    'id': 'd1',
    'reference': 'MBOA-C-2026-J7XADQ',
    'total_xaf': 12000,
    'pickup_city': 'Edéa',
    'dropoff_city': 'Edéa',
    'delivery_address_fr': 'Quartier Bilalang, face au marché.',
    'shop_name': 'Atelier de vannerie',
    'shop_phone': '+237600000000',
    'status': 'UNASSIGNED',
  }),
];

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(seconds: 1));
  if (!_captureEnabled) return;
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_shots.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _MockSocial extends Mock implements SocialRepository {}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  MarketRepository repo,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  // La fiche produit affiche les avis. Sans réponse, son indicateur de
  // chargement tourne sans fin et la capture n'a jamais d'image stable.
  final avis = _MockSocial();
  when(() => avis.comments(any(), any())).thenAnswer(
    (_) async => Comments.fromJson(const {
      'commentaires': [],
      'avertissement':
          'Les commentaires expriment l’avis de leurs auteurs. Ils ne sont ni '
          'vérifiés ni sourcés, et ne font pas partie du contenu documenté.',
      'votants': 0,
      'notable': true,
    }),
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          socialRepositoryProvider.overrideWithValue(avis),
        ],
        child: MaterialApp(
          theme: buildMboaTheme(),
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    final fontData = await rootBundle.load('assets/fonts/Inter-Variable.ttf');
    await (FontLoader('Inter')..addFont(Future.value(fontData))).load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final icons = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.view(icons.readAsBytesSync().buffer)),
            ))
            .load();
      }
    }
    if (!_shots.existsSync()) _shots.createSync(recursive: true);
  });

  testWidgets('catalogue', (tester) async {
    final repo = _MockRepo();
    when(
      repo.categories,
    ).thenAnswer((_) async => [(code: 'VANNERIE', count: 2)]);
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
        items: _products,
        notice: _notice,
        bounds: const CatalogBounds(total: 2, minPrice: 5000, maxPrice: 30000),
      ),
    );

    await _pump(tester, const MarketScreen(), repo);
    expect(find.text('Panier en raphia'), findsOneWidget);
    await _capture(tester, '30-boutique-catalogue');
  });

  testWidgets('fiche produit et affirmation culturelle', (tester) async {
    final repo = _MockRepo();
    when(() => repo.product(any())).thenAnswer((_) async => _detail);

    await _pump(tester, const ProductDetailScreen(productId: 'p1'), repo);
    expect(find.text('Déclaration de l’artisan'), findsOneWidget);
    await _capture(tester, '31-boutique-objet');
  });

  testWidgets('espace livreur', (tester) async {
    final repo = _MockRepo();
    when(repo.courier).thenAnswer((_) async => _courier);
    when(repo.availableDeliveries).thenAnswer(
      (_) async => (
        items: _available,
        message:
            'Le client règle en espèces à la remise. Vous déclarez ensuite le '
            'montant reçu ; MBOA n’encaisse rien.',
      ),
    );
    when(repo.myDeliveries).thenAnswer((_) async => <Delivery>[]);

    await _pump(tester, const CourierScreen(), repo);
    expect(find.textContaining('Disponibles'), findsWidgets);
    await _capture(tester, '32-livreur-courses');
  });
}
