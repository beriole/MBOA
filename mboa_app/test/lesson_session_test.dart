import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/learning/data/learning_repository.dart';
import 'package:mboa_app/features/learning/domain/models.dart';
import 'package:mboa_app/features/lesson/lesson_session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements LearningRepository {}

const _exercises = [
  Exercise(id: 'e1', type: 'LISTEN_AND_CHOOSE', payload: {'prompt_fr': 'P1'}),
  Exercise(id: 'e2', type: 'LISTEN_AND_CHOOSE', payload: {'prompt_fr': 'P2'}),
];

const _lesson = LessonContent(
  id: 'lesson',
  title: 'Leçon',
  unitObjective: 'Objectif',
  xpReward: 10,
  introTitle: 'Intro',
  introSubtitle: null,
  exercises: _exercises,
);

const _summary = LessonSummary(
  score: 0.5,
  correct: 1,
  total: 2,
  xpAwarded: 10,
  totalXp: 12,
  streakDays: 1,
  itemsToReview: 1,
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.lesson('lesson')).thenAnswer((_) async => _lesson);
    when(() => repo.startLesson('lesson')).thenAnswer((_) async => 'session-1');
    when(
      () => repo.completeLesson('lesson', 'session-1'),
    ).thenAnswer((_) async => _summary);
  });

  void answer(String exerciseId, {required bool correct}) {
    when(
      () => repo.attempt(
        exerciseId: exerciseId,
        sessionId: any(named: 'sessionId'),
        answer: any(named: 'answer'),
        responseMs: any(named: 'responseMs'),
      ),
    ).thenAnswer(
      (_) async => AttemptResult(
        isCorrect: correct,
        correctAnswer: 'bon',
        xpDelta: correct ? 2 : 0,
      ),
    );
  }

  test(
    'déroulé complet : intro → réponses → feedback → fin de leçon',
    () async {
      final session = LessonSessionController.lesson(repo, 'lesson');
      await session.load();
      expect(session.phase, SessionPhase.intro);
      expect(session.sessionId, 'session-1');

      session.begin();
      expect(session.phase, SessionPhase.answering);

      answer('e1', correct: true);
      await session.submit({'choice_id': 'bon'});
      expect(session.phase, SessionPhase.feedback);
      expect(session.result!.isCorrect, isTrue);

      await session.next();
      expect(session.index, 1);
      expect(
        session.result,
        isNull,
        reason: 'le feedback est réinitialisé à chaque exercice',
      );

      answer('e2', correct: false);
      await session.submit({'choice_id': 'mauvais'});
      expect(session.result!.isCorrect, isFalse);
      expect(session.selectedId, 'mauvais');

      await session.next();
      expect(session.phase, SessionPhase.done);
      expect(session.summary, _summary);
      expect(session.correctCount, 1);
      expect(session.xpEarned, 2);
      verify(() => repo.completeLesson('lesson', 'session-1')).called(1);
    },
  );

  test('une double soumission pendant la correction est ignorée', () async {
    final session = LessonSessionController.lesson(repo, 'lesson');
    await session.load();
    session.begin();
    answer('e1', correct: true);

    final first = session.submit({'choice_id': 'bon'});
    final second = session.submit({'choice_id': 'bon'});
    await Future.wait([first, second]);

    verify(
      () => repo.attempt(
        exerciseId: 'e1',
        sessionId: any(named: 'sessionId'),
        answer: any(named: 'answer'),
        responseMs: any(named: 'responseMs'),
      ),
    ).called(1);
  });

  test('une erreur réseau laisse l\'apprenant répondre à nouveau', () async {
    final session = LessonSessionController.lesson(repo, 'lesson');
    await session.load();
    session.begin();
    when(
      () => repo.attempt(
        exerciseId: any(named: 'exerciseId'),
        sessionId: any(named: 'sessionId'),
        answer: any(named: 'answer'),
        responseMs: any(named: 'responseMs'),
      ),
    ).thenThrow(Exception('hors ligne'));

    await session.submit({'choice_id': 'bon'});
    expect(session.phase, SessionPhase.answering);
    expect(session.errorMessage, contains('hors ligne'));
    expect(session.result, isNull);
  });

  test(
    'révision sans élément dû : terminée immédiatement, sans fin de leçon',
    () async {
      when(() => repo.reviewExercises()).thenAnswer((_) async => []);
      final session = LessonSessionController.review(repo);
      await session.load();
      expect(session.phase, SessionPhase.done);
      verifyNever(() => repo.completeLesson(any(), any()));
    },
  );

  test('échec de chargement : phase erreur avec message', () async {
    when(
      () => repo.lesson('lesson'),
    ).thenThrow(Exception('serveur injoignable'));
    final session = LessonSessionController.lesson(repo, 'lesson');
    await session.load();
    expect(session.phase, SessionPhase.error);
    expect(session.errorMessage, contains('serveur injoignable'));
  });
}
