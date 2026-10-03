/// Produit les captures du Culture Hub pour le dossier.
///
///   flutter test test/culture_captures_test.dart --dart-define=CAPTURE=true
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/design/theme.dart';
import 'package:mboa_app/features/culture/data/culture_repository.dart';
import 'package:mboa_app/features/culture/domain/models.dart';
import 'package:mboa_app/features/culture/presentation/culture_detail_screen.dart';
import 'package:mboa_app/features/culture/presentation/culture_hub_screen.dart';
import 'package:mboa_app/features/culture/presentation/culture_quiz_screen.dart';
import 'package:mboa_app/features/culture/presentation/culture_widgets.dart';
import 'package:mboa_app/features/culture/presentation/media_screens.dart';
import 'package:mboa_app/features/culture/presentation/region_screens.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CultureRepository {}

const _captureEnabled = bool.fromEnvironment('CAPTURE');
final _boundary = GlobalKey();
final _shots = Directory('../docs/captures');

/// Etat reel du Culture Hub apres le seed : trois fiches, treize rubriques vides.
const _categories = [
  CultureCategory(
    id: 'c1',
    code: 'LANGUAGE',
    name: 'Langue',
    publishedCount: 1,
  ),
  CultureCategory(
    id: 'c2',
    code: 'PEOPLES',
    name: 'Peuples',
    publishedCount: 1,
  ),
  CultureCategory(
    id: 'c3',
    code: 'ORAL_TRADITIONS',
    name: 'Traditions orales',
    publishedCount: 1,
  ),
  CultureCategory(
    id: 'c4',
    code: 'HISTORY',
    name: 'Histoire',
    publishedCount: 0,
  ),
  CultureCategory(id: 'c5', code: 'TALES', name: 'Contes', publishedCount: 0),
  CultureCategory(
    id: 'c6',
    code: 'PROVERBS',
    name: 'Proverbes',
    publishedCount: 0,
  ),
  CultureCategory(id: 'c7', code: 'DANCES', name: 'Danses', publishedCount: 0),
];

const _contents = [
  CultureSummary(
    id: 'f1',
    title: 'Le basaa se parle sur quatre tons',
    summary:
        'En basaa, la hauteur de la voix distingue les mots. '
        'La langue compte quatre tons : haut, bas, descendant et montant.',
    categoryName: 'Langue',
    readingMinutes: 2,
  ),
  CultureSummary(
    id: 'f2',
    title: 'Où parle-t-on le basaa ?',
    summary:
        'Le basaa est parlé dans le Centre et le Littoral du Cameroun. '
        'Il sert aussi de langue véhiculaire au-delà des communautés qui le portent.',
    categoryName: 'Peuples',
    readingMinutes: 3,
    regionName: 'Littoral',
  ),
  CultureSummary(
    id: 'f3',
    title: 'D’où viennent les voix que vous entendez',
    summary:
        'Les enregistrements de l’application proviennent de locuteurs qui les '
        'ont déposés sous licence libre. Aucune voix de synthèse.',
    categoryName: 'Traditions orales',
    readingMinutes: 3,
  ),
];

const _detail = CultureContent(
  id: 'f1',
  title: 'Le basaa se parle sur quatre tons',
  summary:
      'En basaa, la hauteur de la voix distingue les mots. '
      'La langue compte quatre tons : haut, bas, descendant et montant.',
  body:
      'Le basaa fait partie des langues à tons : la hauteur à laquelle une syllabe '
      'est prononcée change le mot lui-même, comme le feraient des lettres '
      'différentes en français.\n\n'
      'Les descriptions linguistiques s’accordent sur quatre tons contrastifs : haut, '
      'bas, descendant et montant.\n\n'
      'Conséquence pratique pour qui apprend : les accents écrits au-dessus des '
      'voyelles ne sont pas décoratifs. Les omettre revient à changer de mot.',
  categoryName: 'Langue',
  readingMinutes: 2,
  languageName: 'Basaa',
  validatedBy: 'DEMO — validateur de démonstration (à remplacer)',
  sources: [
    CultureSource(
      title: 'Basaa — Illustrations of the IPA, JIPA 45(1)',
      authors: ['Emmanuel-Moselly Makasso', 'Seunghun J. Lee'],
      year: 2015,
      license: 'COPYRIGHT_NO_AGREEMENT',
      locator: 'Makasso & Lee 2015, Illustrations of the IPA',
    ),
    CultureSource(
      title: 'Basaa (A.43), in The Bantu Languages',
      authors: ['Larry M. Hyman'],
      year: 2003,
      license: 'COPYRIGHT_NO_AGREEMENT',
      locator: 'Hyman 2003, chapitre 15, section phonologie',
    ),
  ],
  related: [
    CultureSummary(
      id: 'f2',
      title: 'Où parle-t-on le basaa ?',
      summary: '',
      categoryName: 'Peuples',
      readingMinutes: 3,
    ),
  ],
);

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
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

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  CultureRepository repo,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        overrides: [cultureRepositoryProvider.overrideWithValue(repo)],
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

  testWidgets('Culture Hub', (tester) async {
    final repo = _MockRepo();
    when(() => repo.categories()).thenAnswer((_) async => _categories);
    when(
      () => repo.contents(categoryCode: any(named: 'categoryCode')),
    ).thenAnswer((_) async => _contents);

    await _pump(tester, const CultureHubScreen(), repo);
    expect(
      find.descendant(
        of: find.byType(CultureFilterPill),
        matching: find.text('Langue'),
      ),
      findsOneWidget,
    );
    // Les rubriques défilent horizontalement : celles du bout de la bande ne
    // sont construites qu'une fois amenées à l'écran.
    await tester.drag(
      find.byType(CultureFilterPill).first,
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(CultureFilterPill),
        matching: find.text('Contes'),
      ),
      findsOneWidget,
    );
    await _capture(tester, '24-culture-hub');
  });

  testWidgets('fiche culturelle sourcée', (tester) async {
    final repo = _MockRepo();
    when(() => repo.content(any())).thenAnswer((_) async => _detail);

    await _pump(tester, const CultureDetailScreen(contentId: 'f1'), repo);
    expect(find.text('D’où viennent ces informations'), findsOneWidget);
    await _capture(tester, '25-culture-fiche');
  });

  testWidgets('regions culturelles', (tester) async {
    final repo = _MockRepo();
    when(repo.regions).thenAnswer((_) async => _regions);

    await _pump(tester, const RegionsScreen(), repo);
    expect(find.text('Littoral'), findsOneWidget);
    await _capture(tester, '26-culture-regions');
  });

  testWidgets('mediatheque d’une region', (tester) async {
    final repo = _MockRepo();
    when(() => repo.regionMedia(any())).thenAnswer((_) async => _media);
    when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => false);

    await _pump(tester, const RegionMediaScreen(regionId: 'r1'), repo);
    expect(find.textContaining('qu’une fiche publiée'), findsOneWidget);
    await _capture(tester, '28-culture-ecoute-region');
  });

  testWidgets('mes favoris', (tester) async {
    final repo = _MockRepo();
    when(repo.favorites).thenAnswer((_) async => _favoris);
    when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => true);

    await _pump(tester, const FavoritesScreen(), repo);
    expect(find.text('Fiches'), findsOneWidget);
    await _capture(tester, '29-culture-favoris');
  });

  testWidgets('quiz culturel', (tester) async {
    final repo = _MockRepo();
    when(
      () => repo.quiz(limit: any(named: 'limit')),
    ).thenAnswer((_) async => _quiz);

    await _pump(tester, const CultureQuizScreen(), repo);
    expect(find.text('Question 1 sur 5'), findsOneWidget);
    await _capture(tester, '27-culture-quiz');
  });
}

/// Mediatheque du Littoral, telle que l'API la sert : treize enregistrements
/// Lingua Libre, rattaches par une fiche publiee.
final _media = RegionMedia.fromJson(const {
  'region': {'id': 'r1', 'code': 'LT', 'name': 'Littoral'},
  'langues': [
    {
      'id': 'l1',
      'name': 'Basaa',
      'iso639_3': 'bas',
      'fiche_id': 'f2',
      'fiche_titre': 'Où parle-t-on le basaa ?',
    },
  ],
  'enregistrements': [
    {
      'id': 'a1',
      'lemma': 'ɓasaá',
      'meaning_fr': 'eau',
      'language_name': 'Basaa',
      'attribution':
          'Bile rene (Lingua Libre, lingualibre.org/wiki/Q590173) '
          '— CC BY-SA 4.0',
      'license': 'CC_BY_SA',
      'speaker_code': 'BAS-LL-01',
      'duration_ms': null,
    },
    {
      'id': 'a2',
      'lemma': 'màlep',
      'meaning_fr': null,
      'language_name': 'Basaa',
      'attribution':
          'Bile rene (Lingua Libre, lingualibre.org/wiki/Q590173) '
          '— CC BY-SA 4.0',
      'license': 'CC_BY_SA',
      'speaker_code': 'BAS-LL-01',
      'duration_ms': null,
    },
  ],
  'medias': [],
  'compteurs': {'enregistrements': 13, 'videos': 0, 'images': 0},
  'provenance':
      'Les enregistrements proposés sont ceux des langues qu’une fiche '
      'publiée documente dans cette région. Chaque piste porte son attribution '
      'et sa licence.',
  'video':
      'Aucune vidéo au catalogue. MBOA n’en diffusera que sous licence '
      'établie ; aucune illustration de remplissage n’est affichée.',
});

final _favoris = Favorites.fromJson(const {
  'fiches': [
    {
      'id': 'f1',
      'title_fr': 'Le basaa se parle sur quatre tons',
      'summary_fr': 'En basaa, la hauteur de la voix distingue les mots.',
      'category_name': 'Langue',
      'reading_minutes': 2,
    },
  ],
  'enregistrements': [
    {
      'id': 'a1',
      'lemma': 'mààŋgɛ',
      'meaning_fr': 'enfant',
      'language_name': 'Basaa',
      'attribution': 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
      'license': 'CC_BY_SA',
    },
  ],
  'total': 2,
});

/// Les dix regions du Cameroun, avec le compte reel de fiches publiees.
final _regions = [
  for (final (code, nom, fiches) in const [
    ('LT', 'Littoral', 1),
    ('CE', 'Centre', 0),
    ('OU', 'Ouest', 0),
    ('NW', 'Nord-Ouest', 0),
    ('SW', 'Sud-Ouest', 0),
    ('ES', 'Est', 0),
    ('AD', 'Adamaoua', 0),
    ('NO', 'Nord', 0),
    ('EN', 'Extrême-Nord', 0),
    ('SU', 'Sud', 0),
  ])
    CultureRegion.fromJson({
      'id': code,
      'code': code,
      'name': nom,
      'fiches': fiches,
      'langues': fiches > 0 ? 1 : 0,
    }),
];

/// Une question telle que l'API la produit : tiree d'une fiche publiee, et
/// sans aucun champ designant la bonne reponse.
final _quiz = Quiz.fromJson(const {
  'fiches_publiees': 3,
  'message':
      'Les questions sont tirées des fiches publiées du Culture Hub. '
      'Le quiz s’étoffera à mesure que des fiches sourcées seront validées.',
  'questions': [
    {
      'id': 'f1:CATEGORY',
      'type': 'CATEGORY',
      'prompt_fr':
          'À quelle rubrique appartient la fiche '
          '« Le basaa se parle sur quatre tons » ?',
      'choices': [
        {'id': 'c1', 'label': 'Artisanat'},
        {'id': 'c2', 'label': 'Langue'},
        {'id': 'c3', 'label': 'Proverbes'},
        {'id': 'c4', 'label': 'Danses'},
      ],
    },
    {'id': 'f2:REGION', 'type': 'REGION', 'prompt_fr': '…', 'choices': []},
    {'id': 'f3:SUMMARY', 'type': 'SUMMARY', 'prompt_fr': '…', 'choices': []},
    {'id': 'f4:CATEGORY', 'type': 'CATEGORY', 'prompt_fr': '…', 'choices': []},
    {'id': 'f5:REGION', 'type': 'REGION', 'prompt_fr': '…', 'choices': []},
  ],
});
