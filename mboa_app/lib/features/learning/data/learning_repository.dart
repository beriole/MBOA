import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api_client.dart';
import '../domain/models.dart';

/// Accès au contenu pédagogique et à la progression.
///
/// Le client n'envoie que des faits ("j'ai répondu ceci") ; la correction,
/// l'XP et la planification des révisions sont décidés par le serveur.
class LearningRepository {
  LearningRepository(this._api);

  final ApiClient _api;
  static const _uuid = Uuid();

  Future<List<Language>> languages() async {
    final data = await _api.get('/languages') as List;
    return data
        .map((e) => Language.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LearningPath> path(String languageId) async =>
      LearningPath.fromJson(await _api.get('/languages/$languageId/path'));

  Future<LessonContent> lesson(String lessonId) async =>
      LessonContent.fromJson(await _api.get('/lessons/$lessonId'));

  Future<String> startLesson(String lessonId) async =>
      (await _api.post('/lessons/$lessonId/start'))['session_id'] as String;

  /// `clientAttemptId` est généré ici : renvoyer la même tentative (après une
  /// coupure réseau) ne la compte qu'une fois côté serveur.
  Future<AttemptResult> attempt({
    required String exerciseId,
    String? sessionId,
    required Map<String, dynamic> answer,
    required int responseMs,
  }) async {
    final data = await _api.post('/exercises/$exerciseId/attempt', {
      'session_id': sessionId,
      'client_attempt_id': _uuid.v4(),
      'answer': answer,
      'response_ms': responseMs,
    });
    return AttemptResult.fromJson(data as Map<String, dynamic>);
  }

  Future<LessonSummary> completeLesson(
    String lessonId,
    String sessionId,
  ) async => LessonSummary.fromJson(
    await _api.post('/lessons/$lessonId/complete', {'session_id': sessionId}),
  );

  Future<Map<String, dynamic>> progress() async =>
      Map<String, dynamic>.from(await _api.get('/progress'));

  Future<List<Exercise>> reviewExercises() async {
    final data = await _api.get('/review/exercises');
    return (data['exercises'] as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Provenance> provenance(String vocabularyId) async =>
      Provenance.fromJson(
        await _api.get('/vocabulary/$vocabularyId/provenance'),
      );

  /// Démonstration locale uniquement : simule le passage d'une journée.
  Future<int> advanceDay() async =>
      (await _api.post('/dev/advance-day'))['items_shifted'] as int;
}

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LearningRepository(ref.watch(apiClientProvider)),
);
