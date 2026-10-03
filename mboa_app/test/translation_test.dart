import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mboa_app/design/widgets/audio_button.dart';
import 'package:mboa_app/features/learning/domain/models.dart';
import 'package:mboa_app/features/progress/progress_providers.dart';
import 'package:mboa_app/features/translation/data/translation_repository.dart';
import 'package:mboa_app/features/translation/domain/models.dart';
import 'package:mboa_app/features/translation/presentation/translation_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TranslationRepository {}

class _FakeAudio implements AudioService {
  @override
  Future<void> play(String url, {bool slow = false}) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
  @override
  String? get currentUrl => null;
  @override
  Stream<PlayerState> get state => const Stream.empty();
}

const _basaa = Language(
  id: 'lang-1',
  iso: 'bas',
  name: 'Basaa',
  autonym: 'ɓasaá',
  toneCount: 4,
  publishedWords: 13,
);

TranslationResult _result({
  required List<TranslationMatch> matches,
  required String message,
}) => TranslationResult(
  requestId: 'req-1',
  mode: 'LEXICON',
  message: message,
  disclaimer:
      'MBOA ne traduit pas de phrases libres : il recherche dans un corpus vérifié.',
  confidence: matches.isEmpty ? null : matches.first.confidence,
  matches: matches,
);

const _exact = TranslationMatch(
  vocabularyId: 'v1',
  lemma: 'màlep',
  meaningFr: 'eau',
  category: 'NOUN',
  kind: MatchKind.exact,
  confidence: 1.0,
  audioUrl: '/api/v1/audio/a1',
  audioAttribution: 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
  sourceTitle: 'Lingua Libre — prononciations basaa',
  sourceLicense: 'CC_BY_SA',
);

Future<_MockRepo> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _MockRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationRepositoryProvider.overrideWithValue(repo),
        audioServiceProvider.overrideWithValue(_FakeAudio()),
        selectedLanguageProvider.overrideWith((ref) async => _basaa),
      ],
      child: const MaterialApp(home: TranslationScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_basaa);
  });

  testWidgets(
    'une correspondance exacte montre le sens, l\'audio et la source',
    (tester) async {
      final repo = await _pump(tester);
      when(
        () => repo.translate(
          languageId: any(named: 'languageId'),
          text: any(named: 'text'),
          intoFrench: any(named: 'intoFrench'),
        ),
      ).thenAnswer(
        (_) async => _result(
          matches: const [_exact],
          message: '1 correspondance(s) trouvée(s) dans le corpus Basaa.',
        ),
      );

      await tester.enterText(find.byType(TextField), 'màlep');
      await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
      await tester.pumpAndSettle();

      expect(find.text('màlep'), findsWidgets);
      expect(find.text('eau'), findsOneWidget);
      expect(find.text('correspondance exacte'), findsOneWidget);
      // La provenance voyage avec la réponse.
      expect(find.textContaining('Lingua Libre'), findsWidgets);
      expect(find.byType(AudioButton), findsOneWidget);
    },
  );

  testWidgets('une correspondance sans les tons est signalée comme telle', (
    tester,
  ) async {
    final repo = await _pump(tester);
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer(
      (_) async => _result(
        matches: const [
          TranslationMatch(
            vocabularyId: 'v2',
            lemma: 'bìjɛk',
            meaningFr: 'nourriture',
            category: 'NOUN',
            kind: MatchKind.toneless,
            confidence: 0.8,
          ),
        ],
        message:
            'Correspondance trouvée en ignorant les tons. '
            'Vérifiez les diacritiques : elles changent le sens.',
      ),
    );

    await tester.enterText(find.byType(TextField), 'bijɛk');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    expect(find.text('tons ignorés'), findsOneWidget);
    expect(find.textContaining('diacritiques'), findsWidgets);
  });

  testWidgets('aucun résultat : on l\'assume, sans rien proposer', (
    tester,
  ) async {
    final repo = await _pump(tester);
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer(
      (_) async => _result(
        matches: const [],
        message: 'Aucune correspondance dans le corpus validé.',
      ),
    );

    await tester.enterText(find.byType(TextField), 'motinconnu');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    expect(find.text('Ce mot n’est pas encore dans le corpus'), findsOneWidget);
    expect(
      find.textContaining('ne veut pas dire qu’il n’existe pas'),
      findsOneWidget,
    );
    // Surtout : aucune carte de résultat n'est affichée.
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('une forme sans glose validée est montrée comme telle', (
    tester,
  ) async {
    final repo = await _pump(tester);
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer(
      (_) async => _result(
        matches: const [
          TranslationMatch(
            vocabularyId: 'v3',
            lemma: 'litowa',
            meaningFr: null,
            category: 'OTHER',
            kind: MatchKind.exact,
            confidence: 1.0,
          ),
        ],
        message: '1 correspondance(s).',
      ),
    );

    await tester.enterText(find.byType(TextField), 'litowa');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    expect(find.text('traduction pas encore validée'), findsOneWidget);
  });

  testWidgets('le sens de recherche est inversable', (tester) async {
    final repo = await _pump(tester);
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer((_) async => _result(matches: const [_exact], message: 'ok'));

    await tester.tap(find.text('FR → Basaa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'eau');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: captureAny(named: 'intoFrench'),
      ),
    ).captured;
    expect(captured.last, isFalse, reason: 'la recherche part du français');
  });

  testWidgets('un résultat douteux peut être signalé', (tester) async {
    final repo = await _pump(tester);
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer((_) async => _result(matches: const [_exact], message: 'ok'));
    when(() => repo.report(any(), comment: any(named: 'comment'))).thenAnswer(
      (_) async => 'Merci : un spécialiste examinera cette traduction.',
    );

    await tester.enterText(find.byType(TextField), 'màlep');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Signaler un résultat douteux'));
    await tester.pumpAndSettle();

    verify(
      () => repo.report('req-1', comment: any(named: 'comment')),
    ).called(1);
    expect(find.textContaining('un spécialiste examinera'), findsOneWidget);
  });

  testWidgets('le rappel sur la nature de l\'outil reste visible', (
    tester,
  ) async {
    final repo = await _pump(tester);
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer((_) async => _result(matches: const [_exact], message: 'ok'));

    await tester.enterText(find.byType(TextField), 'màlep');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ne traduit pas de phrases libres'),
      findsOneWidget,
    );
  });

  testWidgets("la saisie au clavier ordinaire rappelle l'orthographe exacte", (
    tester,
  ) async {
    final repo = await _pump(tester);
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer(
      (_) async => _result(
        matches: const [
          TranslationMatch(
            vocabularyId: 'v4',
            lemma: 'ɓasaá',
            meaningFr: 'la langue basaa',
            category: 'NOUN',
            kind: MatchKind.folded,
            confidence: 0.7,
          ),
        ],
        message:
            "Correspondance trouvée : l'orthographe exacte s'écrit « ɓasaá ».",
      ),
    );

    await tester.enterText(find.byType(TextField), 'basaa');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    expect(find.text('lettres spéciales rétablies'), findsOneWidget);
    expect(find.textContaining('orthographe exacte'), findsOneWidget);
    expect(find.text('ɓasaá'), findsWidgets);
  });
}
