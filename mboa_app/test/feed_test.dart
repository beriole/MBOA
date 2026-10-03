import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/design/widgets/audio_button.dart';
import 'package:mboa_app/features/culture/data/culture_repository.dart';
import 'package:mboa_app/features/culture/domain/feed_models.dart';
import 'package:mboa_app/features/culture/presentation/feed_screen.dart';
import 'package:mboa_app/features/social/data/social_repository.dart';
import 'package:mboa_app/features/social/domain/models.dart';
import 'package:mocktail/mocktail.dart';

/// Tests du fil du patrimoine.
///
/// La forme est celle d'un fil social. Ce qui la remplit ne l'est pas, et c'est
/// précisément ce que ces tests protègent : le fil met en page du contenu
/// validé, il n'ouvre pas un mur de publication libre. Là où il n'y a rien, il
/// le dit — c'est moins joli qu'une vidéo d'illustration, et c'est le but.
class _MockCulture extends Mock implements CultureRepository {}

class _MockSocial extends Mock implements SocialRepository {}

Map<String, dynamic> _ficheJson({int comments = 0, bool withImage = false}) => {
  'id': 'f1',
  'kind': 'FICHE',
  'titre': 'Le basaa se parle sur quatre tons',
  'target_type': 'CULTURAL_CONTENT',
  'texte': 'En basaa, la hauteur de la voix distingue les mots.',
  'corps': 'Texte complet de la fiche.',
  'categorie': 'Langue',
  'region': 'Littoral',
  'langue': 'Basaa',
  'minutes': 2,
  'media': [
    if (withImage)
      {
        'kind': 'IMAGE',
        'url': '/api/v1/media/img1.jpg',
        'caption': 'Un tambour',
        'credit': 'Photo : Jean Ndoumbe',
        'license': 'CC BY 4.0',
      },
  ],
  'date': '2026-09-01T10:00:00+00:00',
  'source': {
    'title': 'Makasso & Lee, Basaa',
    'authors': ['Makasso', 'Lee'],
    'year': 2015,
    'url': null,
  },
  'commentaires': comments,
  'favoris': 3,
};

Map<String, dynamic> _recordingJson({String? meaning}) => {
  'id': 'a1',
  'kind': 'ENREGISTREMENT',
  'titre': 'màlep',
  'target_type': 'AUDIO',
  'texte': meaning,
  'corps': null,
  'categorie': 'Prononciation',
  'region': null,
  'langue': 'Basaa',
  'minutes': null,
  'media': const [],
  'audio_url': '/api/v1/audio/a1',
  'attribution': 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
  'license': 'CC_BY_SA',
  'locuteur': 'BAS-LL-01',
  'date': '2026-08-01T10:00:00+00:00',
  'source': {
    'title': 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
    'authors': [],
    'year': null,
    'url': null,
  },
  'commentaires': 0,
  'favoris': 0,
};

Map<String, dynamic> _feedJson({
  List<Map<String, dynamic>>? posts,
  List<Map<String, dynamic>>? gaps,
}) => {
  'posts': posts ?? [_ficheJson(), _recordingJson()],
  'compteurs': {'fiches': 1, 'enregistrements': 1, 'videos': 0, 'images': 0},
  'manques':
      gaps ??
      [
        {
          'kind': 'VIDEO',
          'message':
              'Aucune vidéo au catalogue. MBOA n’en diffusera que sous '
              'licence établie ; aucune illustration de remplissage '
              'n’est affichée.',
        },
        {
          'kind': 'CHANT',
          'message':
              'Aucun chant ni morceau de musique n’est encore collecté. Les '
              'enregistrements disponibles sont des mots isolés du '
              'vocabulaire : les présenter comme de la musique serait faux.',
        },
      ],
  'avertissement':
      'Chaque publication de ce fil est passée par la validation : une '
      'fiche porte sa source, un enregistrement porte son auteur et sa '
      'licence. Les commentaires, eux, n’engagent que leurs auteurs.',
};

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> json, {
  SocialRepository? social,
}) async {
  tester.view.physicalSize = const Size(1100, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final culture = _MockCulture();
  when(
    () => culture.feed(regionId: any(named: 'regionId')),
  ).thenAnswer((_) async => Feed.fromJson(json));
  when(() => culture.isFavorite(any(), any())).thenAnswer((_) async => false);

  final avis = social ?? _MockSocial();
  when(() => avis.comments(any(), any())).thenAnswer(
    (_) async => Comments.fromJson(const {
      'commentaires': [],
      'avertissement': 'Les commentaires expriment l’avis de leurs auteurs.',
      'votants': 0,
      'notable': false,
    }),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cultureRepositoryProvider.overrideWithValue(culture),
        socialRepositoryProvider.overrideWithValue(avis),
      ],
      child: const MaterialApp(home: CultureFeedScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('fil du patrimoine', () {
    testWidgets('chaque carte affiche ce qui l’établit', (tester) async {
      await _pump(tester, _feedJson());
      await tester.pumpAndSettle();

      expect(find.text('Le basaa se parle sur quatre tons'), findsOneWidget);
      // La source d'une fiche et l'attribution d'un enregistrement sont
      // visibles sur la carte, pas cachées derrière un clic.
      expect(
        find.textContaining('Makasso, Lee — Makasso & Lee, Basaa — 2015'),
        findsOneWidget,
      );
      expect(find.textContaining('Lingua Libre'), findsOneWidget);
    });

    testWidgets('un enregistrement se joue depuis le fil', (tester) async {
      await _pump(tester, _feedJson(posts: [_recordingJson()]));
      await tester.pumpAndSettle();

      expect(find.byType(AudioButton), findsOneWidget);
      expect(find.text('Locuteur BAS-LL-01'), findsOneWidget);
    });

    testWidgets('une glose absente n’est pas remplacée', (tester) async {
      await _pump(tester, _feedJson(posts: [_recordingJson()]));
      await tester.pumpAndSettle();

      // Le corpus n'a pas de sens confirmé pour ce mot. On le dit.
      expect(find.text('Sens non renseigné'), findsOneWidget);
    });

    testWidgets('une glose présente est affichée telle quelle', (tester) async {
      await _pump(tester, _feedJson(posts: [_recordingJson(meaning: 'eau')]));
      await tester.pumpAndSettle();

      expect(find.text('eau'), findsOneWidget);
      expect(find.text('Sens non renseigné'), findsNothing);
    });

    testWidgets('ce qui manque est annoncé, pas illustré', (tester) async {
      await _pump(tester, _feedJson());
      await tester.pumpAndSettle();

      expect(find.text('Ce qui manque encore'), findsOneWidget);
      expect(find.textContaining('licence établie'), findsOneWidget);
      // Le point le plus facile à perdre : un mot du vocabulaire n'est pas un
      // chant, et le fil refuse de le présenter comme tel.
      expect(find.textContaining('mots isolés du vocabulaire'), findsOneWidget);
    });

    testWidgets('le crédit d’une image voyage avec elle', (tester) async {
      await _pump(tester, _feedJson(posts: [_ficheJson(withImage: true)]));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Photo : Jean Ndoumbe'),
        findsOneWidget,
        reason: 'la licence n’autorise la republication qu’avec son crédit',
      );
      expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    });

    testWidgets('les commentaires s’ouvrent sous la carte', (tester) async {
      await _pump(tester, _feedJson(posts: [_ficheJson(comments: 2)]));
      await tester.pumpAndSettle();

      // Repliés, ils affichent leur nombre ; ils n'entrent pas dans la fiche.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Ce qu’en disent les gens'), findsNothing);

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.text('Ce qu’en disent les gens'), findsOneWidget);
      expect(
        find.textContaining('n’engagent que leurs auteurs'),
        findsOneWidget,
      );
    });

    testWidgets('un fil vide assume le vide', (tester) async {
      await _pump(tester, _feedJson(posts: const [], gaps: const []));
      await tester.pumpAndSettle();

      expect(find.text('Rien de publié pour l’instant'), findsOneWidget);
      expect(find.textContaining('préfère un fil vide'), findsOneWidget);
    });
  });

  group('modèles du fil', () {
    test('une publication sans source se reconnaît', () {
      final feed = Feed.fromJson(_feedJson());
      for (final post in feed.posts) {
        expect(post.source, isNotNull);
      }
    });

    test('la citation assemble auteurs, titre et année', () {
      final feed = Feed.fromJson(_feedJson());
      final fiche = feed.posts.firstWhere((p) => p.kind == 'FICHE');
      expect(
        fiche.source!.citation,
        'Makasso, Lee — Makasso & Lee, Basaa — 2015',
      );
    });

    test('un enregistrement n’est pas confondu avec une fiche', () {
      final feed = Feed.fromJson(_feedJson());
      final son = feed.posts.firstWhere((p) => p.kind == 'ENREGISTREMENT');
      expect(son.isRecording, isTrue);
      expect(son.targetType, 'AUDIO');
      expect(son.video, isNull);
    });
  });
}
