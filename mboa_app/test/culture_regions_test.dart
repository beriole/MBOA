import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/culture/data/culture_repository.dart';
import 'package:mboa_app/features/culture/domain/models.dart';
import 'package:mboa_app/features/culture/presentation/culture_quiz_screen.dart';
import 'package:mboa_app/features/culture/presentation/region_screens.dart';
import 'package:mboa_app/design/widgets/audio_button.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CultureRepository {}

final _regions = [
  CultureRegion.fromJson(const {
    'id': 'r1',
    'code': 'LT',
    'name': 'Littoral',
    'fiches': 2,
    'langues': 1,
  }),
  CultureRegion.fromJson(const {
    'id': 'r2',
    'code': 'OU',
    'name': 'Ouest',
    'fiches': 0,
    'langues': 0,
  }),
];

Map<String, dynamic> _regionDetailJson({
  int fiches = 1,
  Map<String, int> medias = const {},
}) => {
  'region': {'id': 'r1', 'code': 'LT', 'name': 'Littoral'},
  'chiffres': {'fiches': fiches, 'langues': 1, 'communautes': 0},
  'rubriques': [
    if (fiches > 0) {'code': 'LANGUAGE', 'name': 'Langue', 'fiches': fiches},
  ],
  'medias': medias,
  'fiches': [
    for (var i = 0; i < fiches; i++)
      {
        'id': 'f$i',
        'title_fr': 'Le basaa se parle sur quatre tons',
        'summary_fr': 'En basaa, la hauteur de la voix distingue les mots.',
        'category_name': 'Langue',
        'reading_minutes': 2,
      },
  ],
};

Map<String, dynamic> _quizJson({int questions = 2}) => {
  'fiches_publiees': 3,
  'message': 'Les questions sont tirées des fiches publiées du Culture Hub.',
  'questions': [
    for (var i = 0; i < questions; i++)
      {
        'id': 'f$i:CATEGORY',
        'type': 'CATEGORY',
        'prompt_fr': 'À quelle rubrique appartient la fiche « Fiche $i » ?',
        'choices': [
          {'id': 'c1', 'label': 'Langue'},
          {'id': 'c2', 'label': 'Contes'},
          {'id': 'c3', 'label': 'Danses'},
          {'id': 'c4', 'label': 'Proverbes'},
        ],
      },
  ],
};

QuizVerdict _verdict({bool correct = true}) => QuizVerdict.fromJson({
  'is_correct': correct,
  'correct_label': 'Langue',
  // La bonne proposition est désignée par son identifiant, pas par son
  // libellé : deux propositions peuvent porter le même texte, et les
  // questions d'écoute ont des libellés volontairement neutres.
  'correct_id': 'c1',
  'explication_fr': '« Fiche 0 » est classée dans la rubrique Langue.',
  'fiche': {'id': 'f0', 'title_fr': 'Fiche 0', 'summary_fr': 'Résumé'},
  'source': {'title': 'Makasso & Lee 2015', 'authors': [], 'year': 2015},
});

/// Une question d'écoute, et sa correction.
///
/// Le quiz ne tirait ses questions que des fiches culturelles, trop peu
/// nombreuses. Il puise désormais aussi dans les enregistrements du
/// vocabulaire, dont l'auteur et la licence sont connus.
Map<String, dynamic> _listeningQuizJson() => {
  'fiches_publiees': 3,
  'mots_enregistres': 13,
  'questions_disponibles': 33,
  'message': '33 questions sont aujourd’hui dérivables.',
  'questions': [
    {
      'id': 'v1:AUDIO_WORD',
      'type': 'AUDIO_WORD',
      'prompt_fr': 'Quel mot entendez-vous ?',
      'audio_url': '/api/v1/audio/a1',
      'choices': [
        {'id': 'v1', 'label': 'màlep'},
        {'id': 'v2', 'label': 'bìjɛk'},
        {'id': 'v3', 'label': 'litowa'},
      ],
    },
  ],
};

QuizVerdict _listeningVerdict() => QuizVerdict.fromJson({
  'is_correct': true,
  'correct_label': 'màlep',
  'correct_id': 'v1',
  'explication_fr': 'C’est « màlep », en Basaa.',
  // Pas de fiche derrière une question d'écoute : c'est l'attribution de
  // l'enregistrement qui répond de la réponse.
  'fiche': null,
  'audio_url': '/api/v1/audio/a1',
  'source': {
    'title': 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
    'authors': [],
    'year': null,
  },
});

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  CultureRepository repo,
) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [cultureRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('régions', () {
    testWidgets('une région sans fiche reste listée', (tester) async {
      final repo = _MockRepo();
      when(repo.regions).thenAnswer((_) async => _regions);

      await _pump(tester, const RegionsScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Littoral'), findsOneWidget);
      expect(find.text('Ouest'), findsOneWidget);
      // La région vide le dit, au lieu de disparaître.
      expect(find.text('Rien de publié pour l’instant'), findsOneWidget);
      expect(find.textContaining('1 documentée'), findsOneWidget);
    });

    testWidgets('le détail d’une région montre ses chiffres réels', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        () => repo.region(any()),
      ).thenAnswer((_) async => RegionDetail.fromJson(_regionDetailJson()));

      await _pump(tester, const RegionDetailScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      expect(find.text('Littoral'), findsOneWidget);
      expect(find.text('fiches publiées'), findsOneWidget);
      expect(find.text('Langue · 1'), findsOneWidget);
      expect(find.text('Le basaa se parle sur quatre tons'), findsOneWidget);
    });

    testWidgets('une région sans média ne montre pas de vidéo d’illustration', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        () => repo.region(any()),
      ).thenAnswer((_) async => RegionDetail.fromJson(_regionDetailJson()));

      await _pump(tester, const RegionDetailScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      expect(
        find.text('Ni vidéo ni enregistrement pour l’instant'),
        findsOneWidget,
      );
      expect(find.textContaining('provenance et la licence'), findsOneWidget);
    });

    testWidgets('une région vide assume le vide', (tester) async {
      final repo = _MockRepo();
      when(() => repo.region(any())).thenAnswer(
        (_) async => RegionDetail.fromJson(_regionDetailJson(fiches: 0)),
      );

      await _pump(tester, const RegionDetailScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      expect(find.text('Rien de publié sur Littoral'), findsOneWidget);
      expect(find.textContaining('que personne n’a vérifié'), findsOneWidget);
    });
  });

  group('quiz culturel', () {
    testWidgets('aucune proposition n’est marquée avant la réponse', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        () => repo.quiz(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Quiz.fromJson(_quizJson()));

      await _pump(tester, const CultureQuizScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Question 1 sur 2'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);
      // Tant que rien n'est répondu, aucune coche ni croix n'apparaît.
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    });

    testWidgets('la correction cite la fiche et sa source', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.quiz(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Quiz.fromJson(_quizJson()));
      when(() => repo.answer(any(), any())).thenAnswer((_) async => _verdict());

      await _pump(tester, const CultureQuizScreen(), repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Langue'));
      await tester.pumpAndSettle();

      expect(find.text('Bonne réponse'), findsOneWidget);
      expect(
        find.textContaining('est classée dans la rubrique Langue'),
        findsOneWidget,
      );
      expect(find.text('Source : Makasso & Lee 2015'), findsOneWidget);
      expect(find.text('Lire la fiche'), findsOneWidget);
      verify(() => repo.answer('f0:CATEGORY', 'c1')).called(1);
    });

    testWidgets('une mauvaise réponse montre la bonne', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.quiz(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Quiz.fromJson(_quizJson()));
      when(
        () => repo.answer(any(), any()),
      ).thenAnswer((_) async => _verdict(correct: false));

      await _pump(tester, const CultureQuizScreen(), repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contes'));
      await tester.pumpAndSettle();

      expect(find.text('Réponse : Langue'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('le résultat ne prétend pas mesurer un niveau', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.quiz(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Quiz.fromJson(_quizJson(questions: 1)));
      when(() => repo.answer(any(), any())).thenAnswer((_) async => _verdict());

      await _pump(tester, const CultureQuizScreen(), repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Langue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir mon résultat'));
      await tester.pumpAndSettle();

      expect(find.text('1/1'), findsOneWidget);
      expect(
        find.textContaining('Ce n’est pas une évaluation de niveau'),
        findsOneWidget,
      );
    });

    testWidgets('sans fiche publiée, le quiz le dit', (tester) async {
      final repo = _MockRepo();
      when(() => repo.quiz(limit: any(named: 'limit'))).thenAnswer(
        (_) async => Quiz.fromJson(const {
          'questions': [],
          'fiches_publiees': 0,
          'message':
              'Aucune fiche publiée ne permet encore de poser une question.',
        }),
      );

      await _pump(tester, const CultureQuizScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Pas encore de quiz'), findsOneWidget);
      expect(find.textContaining('Aucune fiche publiée'), findsOneWidget);
      expect(
        find.textContaining('le quiz grandit avec le Culture Hub'),
        findsOneWidget,
      );
    });

    testWidgets('une question d’écoute se joue et ne se lit pas', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        () => repo.quiz(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Quiz.fromJson(_listeningQuizJson()));

      await _pump(tester, const CultureQuizScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Quel mot entendez-vous ?'), findsOneWidget);
      // L'énoncé porte un bouton de lecture : sans lui, la question est
      // impossible à répondre.
      expect(find.byType(AudioButton), findsOneWidget);
      expect(find.text('màlep'), findsOneWidget);
    });

    testWidgets('une correction sans fiche ne propose pas d’en lire une', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        () => repo.quiz(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Quiz.fromJson(_listeningQuizJson()));
      when(
        () => repo.answer(any(), any()),
      ).thenAnswer((_) async => _listeningVerdict());

      await _pump(tester, const CultureQuizScreen(), repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('màlep'));
      await tester.pumpAndSettle();

      expect(find.text('Bonne réponse'), findsOneWidget);
      // Il n'y a pas de fiche derrière un enregistrement : proposer d'en lire
      // une mènerait vers une page inexistante.
      expect(find.text('Lire la fiche'), findsNothing);
      // Mais l'attribution, elle, répond de la réponse.
      expect(find.textContaining('Lingua Libre'), findsOneWidget);
      expect(find.text('Réécouter la bonne réponse'), findsOneWidget);
    });
  });

  group('modèles', () {
    test('une question ne porte jamais la réponse', () {
      final quiz = Quiz.fromJson(_quizJson());
      final question = quiz.questions.first;
      // Le modèle n'expose aucun champ de correction : elle vient du serveur.
      expect(question.choices.length, 4);
      expect(question.choices.map((c) => c.label), contains('Langue'));
    });

    test('une région sans fiche se reconnaît', () {
      expect(_regions[1].isEmpty, isTrue);
      expect(_regions[0].isEmpty, isFalse);
    });

    test('le détail compte les médias par type', () {
      final detail = RegionDetail.fromJson(
        _regionDetailJson(medias: const {'AUDIO': 3, 'VIDEO': 1}),
      );
      expect(detail.mediaCount('AUDIO'), 3);
      expect(detail.mediaCount('IMAGE'), 0);
    });
  });
}
