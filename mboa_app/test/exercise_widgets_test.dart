import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mboa_app/design/widgets/audio_button.dart';
import 'package:mboa_app/design/widgets/feedback_bar.dart';
import 'package:mboa_app/features/exercises/exercise_view.dart';
import 'package:mboa_app/features/learning/domain/models.dart';

/// Lecteur factice : aucun plugin audio n'est disponible dans les tests.
class _FakeAudio implements AudioService {
  final played = <String>[];

  @override
  Future<void> play(String url, {bool slow = false}) async => played.add(url);

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  @override
  String? get currentUrl => played.isEmpty ? null : played.last;

  @override
  Stream<PlayerState> get state => const Stream.empty();
}

const _listen = Exercise(
  id: 'ex',
  type: 'LISTEN_AND_CHOOSE',
  payload: {
    'prompt_fr': "Qu'as-tu entendu ?",
    'audio_url': 'https://example.org/a.wav',
    'audio_attribution': 'Locuteur test - CC BY-SA 4.0',
    'choices': [
      {'id': 'a', 'text': 'forme-a'},
      {'id': 'b', 'text': 'forme-b'},
    ],
  },
);

Future<_FakeAudio> _pump(WidgetTester tester, Widget child) async {
  final audio = _FakeAudio();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioServiceProvider.overrideWithValue(audio)],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  return audio;
}

void main() {
  testWidgets("l'écoute démarre seule, puis le choix est soumis au serveur", (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final audio = await _pump(
      tester,
      buildExerciseView(
        exercise: _listen,
        onSubmit: (a) => submitted = a,
        result: null,
        selectedId: null,
      ),
    );

    expect(audio.played, [
      'https://example.org/a.wav',
    ], reason: 'lecture automatique');
    expect(
      find.textContaining('CC BY-SA'),
      findsOneWidget,
      reason: 'attribution affichée',
    );

    await tester.tap(find.text('forme-b'));
    expect(submitted, {'choice_id': 'b'});
  });

  testWidgets(
    'après correction, les choix sont figés et la bonne réponse est signalée',
    (tester) async {
      var taps = 0;
      await _pump(
        tester,
        buildExerciseView(
          exercise: _listen,
          onSubmit: (_) => taps++,
          result: const AttemptResult(
            isCorrect: false,
            correctAnswer: 'a',
            xpDelta: 0,
          ),
          selectedId: 'b',
        ),
      );

      await tester.tap(find.text('forme-a'));
      expect(taps, 0, reason: 'plus de soumission après correction');
      // Information portée par le texte, pas seulement par la couleur (K9).
      expect(find.bySemanticsLabel('forme-a, bonne réponse'), findsOneWidget);
      expect(
        find.bySemanticsLabel('forme-b, réponse incorrecte'),
        findsOneWidget,
      );
    },
  );

  test('le libellé de la bonne réponse est retrouvé pour le feedback', () {
    const result = AttemptResult(
      isCorrect: false,
      correctAnswer: 'a',
      xpDelta: 0,
    );
    expect(correctLabelFor(_listen, result), 'forme-a');
  });

  testWidgets('feedback incorrect : bienveillant, avec la bonne réponse', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackBar(
            isCorrect: false,
            correctAnswerLabel: 'forme-a',
            onContinue: () => continued = true,
          ),
        ),
      ),
    );

    expect(find.text('Pas encore'), findsOneWidget);
    expect(find.text('forme-a'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.textContaining('Faux'), findsNothing);

    await tester.tap(find.text('Continuer'));
    expect(continued, isTrue);
  });

  testWidgets('feedback correct : XP affichés', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackBar(isCorrect: true, xpDelta: 2, onContinue: () {}),
        ),
      ),
    );
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('+2 XP'), findsOneWidget);
  });

  testWidgets('jeu de paires : seule la première proposition compte', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    const game = Exercise(
      id: 'mg',
      type: 'MEMORY_GAME',
      payload: {
        'prompt_fr': 'Paires',
        'pairs': [
          {'id': 'p1', 'text': 'mot-1', 'audio_url': 'u1'},
          {'id': 'p2', 'text': 'mot-2', 'audio_url': 'u2'},
        ],
      },
    );
    await _pump(
      tester,
      buildExerciseView(
        exercise: game,
        onSubmit: (a) => submitted = a,
        result: null,
        selectedId: null,
      ),
    );

    Finder soundFor(String url) => find.ancestor(
      of: find.byWidgetPredicate((w) => w is AudioButton && w.url == url),
      matching: find.byType(Row),
    );
    Finder tileIn(Finder row) =>
        find.descendant(of: row, matching: find.byType(ChoiceTile));

    // mot-1 : d'abord une erreur, puis la bonne paire.
    await tester.tap(find.text('mot-1'));
    await tester.pump();
    await tester.tap(tileIn(soundFor('u2')).first);
    await tester.pump();
    await tester.tap(tileIn(soundFor('u1')).first);
    await tester.pump();

    // mot-2 : juste du premier coup.
    await tester.tap(find.text('mot-2'));
    await tester.pump();
    await tester.tap(tileIn(soundFor('u2')).first);
    await tester.pump();

    expect(submitted, {
      'matched_ids': ['p2'],
    });
  });
}
