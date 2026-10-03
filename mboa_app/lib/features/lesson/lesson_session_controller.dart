import 'package:flutter/foundation.dart';

import '../learning/data/learning_repository.dart';
import '../learning/domain/models.dart';

enum SessionPhase {
  loading,
  intro,
  answering,
  submitting,
  feedback,

  /// Carte culturelle, entre le dernier exercice et le résultat (SS21).
  culture,
  finishing,
  done,
  error,
}

/// Machine à états d'une session (livrable I4) :
///
///   loading → intro → answering → submitting → feedback → answering … → finishing → done
///
/// Sert aux leçons et à la révision. La correction, l'XP et la répétition
/// espacée sont calculées par le serveur ; ce contrôleur ne fait qu'orchestrer.
class LessonSessionController extends ChangeNotifier {
  LessonSessionController.lesson(this._repo, this.lessonId) : isReview = false;

  LessonSessionController.review(this._repo) : lessonId = null, isReview = true;

  final LearningRepository _repo;
  final String? lessonId;
  final bool isReview;

  SessionPhase phase = SessionPhase.loading;
  LessonContent? lesson;
  List<Exercise> exercises = const [];
  String? sessionId;
  int index = 0;
  String? selectedId;
  AttemptResult? result;
  LessonSummary? summary;
  String? errorMessage;

  int correctCount = 0;
  int xpEarned = 0;
  DateTime? _shownAt;
  bool _cultureShown = false;

  Exercise? get current => index < exercises.length ? exercises[index] : null;
  double get progress => exercises.isEmpty ? 0 : index / exercises.length;

  Future<void> load() async {
    try {
      if (isReview) {
        exercises = await _repo.reviewExercises();
        phase = exercises.isEmpty ? SessionPhase.done : SessionPhase.answering;
        _shownAt = DateTime.now();
      } else {
        lesson = await _repo.lesson(lessonId!);
        exercises = lesson!.exercises;
        sessionId = await _repo.startLesson(lessonId!);
        phase = SessionPhase.intro;
      }
    } catch (e) {
      errorMessage = e.toString();
      phase = SessionPhase.error;
    }
    notifyListeners();
  }

  void begin() {
    phase = exercises.isEmpty ? SessionPhase.finishing : SessionPhase.answering;
    _shownAt = DateTime.now();
    notifyListeners();
    if (exercises.isEmpty) finish();
  }

  Future<void> submit(Map<String, dynamic> answer) async {
    final exercise = current;
    if (exercise == null || phase != SessionPhase.answering) return;

    selectedId = answer['choice_id'] as String?;
    phase = SessionPhase.submitting;
    notifyListeners();

    try {
      result = await _repo.attempt(
        exerciseId: exercise.id,
        sessionId: sessionId,
        answer: answer,
        responseMs: DateTime.now()
            .difference(_shownAt ?? DateTime.now())
            .inMilliseconds,
      );
      if (result!.isCorrect) correctCount++;
      xpEarned += result!.xpDelta;
      phase = SessionPhase.feedback;
    } catch (e) {
      errorMessage = e.toString();
      phase = SessionPhase.answering;
      selectedId = null;
    }
    notifyListeners();
  }

  Future<void> next() async {
    index++;
    selectedId = null;
    result = null;
    errorMessage = null;
    if (index >= exercises.length) {
      // La carte culturelle s'intercale avant le résultat, une seule fois.
      final card = lesson?.cultureCard;
      if (card != null && !_cultureShown) {
        _cultureShown = true;
        phase = SessionPhase.culture;
        notifyListeners();
        return;
      }
      await finish();
    } else {
      phase = SessionPhase.answering;
      _shownAt = DateTime.now();
      notifyListeners();
    }
  }

  /// Quitte la carte culturelle pour l'écran de résultat.
  Future<void> dismissCulture() => finish();

  Future<void> finish() async {
    phase = SessionPhase.finishing;
    notifyListeners();
    try {
      if (!isReview && sessionId != null) {
        summary = await _repo.completeLesson(lessonId!, sessionId!);
      }
      phase = SessionPhase.done;
    } catch (e) {
      errorMessage = e.toString();
      phase = SessionPhase.error;
    }
    notifyListeners();
  }
}
