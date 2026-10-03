import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/culture/data/culture_repository.dart';
import 'package:mboa_app/features/culture/domain/models.dart';
import 'package:mboa_app/features/culture/presentation/culture_card_view.dart';
import 'package:mboa_app/features/culture/presentation/culture_detail_screen.dart';
import 'package:mboa_app/features/culture/presentation/culture_hub_screen.dart';
import 'package:mboa_app/features/culture/presentation/culture_widgets.dart';
import 'package:mboa_app/features/learning/domain/models.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CultureRepository {}

const _categories = [
  CultureCategory(
    id: 'c1',
    code: 'LANGUAGE',
    name: 'Langue',
    publishedCount: 1,
  ),
  CultureCategory(id: 'c2', code: 'TALES', name: 'Contes', publishedCount: 0),
];

const _summary = CultureSummary(
  id: 'f1',
  title: 'Le basaa se parle sur quatre tons',
  summary: 'En basaa, la hauteur de la voix distingue les mots.',
  categoryName: 'Langue',
  readingMinutes: 2,
  regionName: 'Littoral',
);

const _detail = CultureContent(
  id: 'f1',
  title: 'Le basaa se parle sur quatre tons',
  summary: 'En basaa, la hauteur de la voix distingue les mots.',
  body: 'Premier paragraphe.\n\nSecond paragraphe.',
  categoryName: 'Langue',
  readingMinutes: 2,
  validatedBy: 'Validateur natif',
  sources: [
    CultureSource(
      title: 'Basaa — Illustrations of the IPA, JIPA 45(1)',
      authors: ['Makasso', 'Lee'],
      year: 2015,
      license: 'COPYRIGHT_NO_AGREEMENT',
      locator: 'section tons',
    ),
  ],
  related: [_summary],
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  CultureRepository repo,
) async {
  tester.view.physicalSize = const Size(1000, 2600);
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
  group('Culture Hub', () {
    testWidgets('les rubriques vides restent visibles, avec leur compte', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(() => repo.categories()).thenAnswer((_) async => _categories);
      when(
        () => repo.contents(categoryCode: any(named: 'categoryCode')),
      ).thenAnswer((_) async => [_summary]);

      await _pump(tester, const CultureHubScreen(), repo);
      await tester.pumpAndSettle();

      // Le nom de la rubrique et son compte sont deux éléments distincts dans
      // la pastille : la pastille elle-même est ce qui les rassemble.
      final pilules = find.byType(CultureFilterPill);
      expect(
        find.descendant(of: pilules, matching: find.text('Langue')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pilules, matching: find.text('1')),
        findsOneWidget,
      );
      // Montrer ce qui reste à documenter fait partie du propos.
      expect(
        find.descendant(of: pilules, matching: find.text('Contes')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pilules, matching: find.text('0')),
        findsOneWidget,
      );
      expect(find.text(_summary.title), findsOneWidget);
    });

    testWidgets('une rubrique sans fiche assume le vide', (tester) async {
      final repo = _MockRepo();
      when(() => repo.categories()).thenAnswer((_) async => _categories);
      when(
        () => repo.contents(categoryCode: any(named: 'categoryCode')),
      ).thenAnswer((_) async => []);

      await _pump(tester, const CultureHubScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Rien à lire ici pour l’instant'), findsOneWidget);
      expect(find.textContaining('que personne n’a vérifié'), findsOneWidget);
    });

    testWidgets('filtrer par rubrique interroge le serveur', (tester) async {
      final repo = _MockRepo();
      when(() => repo.categories()).thenAnswer((_) async => _categories);
      when(
        () => repo.contents(categoryCode: any(named: 'categoryCode')),
      ).thenAnswer((_) async => [_summary]);

      await _pump(tester, const CultureHubScreen(), repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contes'));
      await tester.pumpAndSettle();

      verify(() => repo.contents(categoryCode: 'TALES')).called(1);
    });
  });

  group('fiche détaillée', () {
    testWidgets('les sources sont affichées avec la fiche', (tester) async {
      final repo = _MockRepo();
      when(() => repo.content(any())).thenAnswer((_) async => _detail);

      await _pump(tester, const CultureDetailScreen(contentId: 'f1'), repo);
      await tester.pumpAndSettle();

      expect(find.text('D’où viennent ces informations'), findsOneWidget);
      expect(find.textContaining('Makasso, Lee, 2015'), findsOneWidget);
      expect(find.text('section tons'), findsOneWidget);
      expect(find.textContaining('Relu et validé par'), findsOneWidget);
      // Le corps est découpé en paragraphes lisibles.
      expect(find.text('Premier paragraphe.'), findsOneWidget);
      expect(find.text('Second paragraphe.'), findsOneWidget);
    });

    test('la citation compose auteurs et année', () {
      expect(
        _detail.sources.first.citation,
        'Basaa — Illustrations of the IPA, JIPA 45(1) — Makasso, Lee, 2015',
      );
      const sansAuteur = CultureSource(title: 'Titre seul');
      expect(sansAuteur.citation, 'Titre seul');
    });

    test('le corps vide ne produit aucun paragraphe', () {
      const vide = CultureContent(
        id: 'x',
        title: 't',
        summary: 's',
        categoryName: 'c',
        readingMinutes: 1,
      );
      expect(vide.paragraphs, isEmpty);
    });
  });

  group('carte « Le savais-tu ? »', () {
    testWidgets('elle montre le résumé et sa source', (tester) async {
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CultureCardView(
              card: const CultureCard(
                id: 'f1',
                title: 'Le basaa se parle sur quatre tons',
                summary: 'La hauteur de la voix distingue les mots.',
                categoryName: 'Langue',
                sourceTitle: 'Makasso & Lee 2015',
              ),
              onContinue: () => continued = true,
            ),
          ),
        ),
      );

      expect(find.text('LE SAVAIS-TU ?'), findsOneWidget);
      expect(find.text('Le basaa se parle sur quatre tons'), findsOneWidget);
      expect(
        find.textContaining('Source : Makasso & Lee 2015'),
        findsOneWidget,
      );
      expect(find.text('Découvrir davantage'), findsOneWidget);

      await tester.tap(find.text('Continuer'));
      expect(continued, isTrue);
    });
  });

  group('leçon', () {
    Map<String, dynamic> lessonJson({Map<String, dynamic>? card}) => {
      'id': 'l1',
      'title_fr': 'Leçon',
      'xp_reward': 10,
      'unit': {'title_fr': 'U', 'objective_fr': 'O'},
      'blocks': const [],
      'culture_card': card,
    };

    test('la carte est lue depuis la leçon', () {
      final lesson = LessonContent.fromJson(
        lessonJson(
          card: {
            'id': 'f1',
            'title_fr': 'Titre',
            'summary_fr': 'Résumé',
            'category_name': 'Langue',
            'source_title': 'Source',
          },
        ),
      );
      expect(lesson.cultureCard, isNotNull);
      expect(lesson.cultureCard!.title, 'Titre');
    });

    test('une leçon sans fiche n’invente pas de carte', () {
      expect(LessonContent.fromJson(lessonJson()).cultureCard, isNull);
    });
  });
}
