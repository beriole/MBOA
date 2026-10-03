import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/learning/domain/models.dart';

Map<String, dynamic> _lesson(String id, String status) => {
  'id': id,
  'title_fr': 'Leçon $id',
  'kind': 'LESSON',
  'estimated_minutes': 4,
  'xp_reward': 10,
  'status': status,
  'best_score': null,
};

LearningPath _path(List<String> statuses) => LearningPath.fromJson({
  'course': {'title_fr': 'Cours', 'level': 'N0'},
  'sections': [
    {
      'title_fr': 'Section',
      'objective_fr': null,
      'units': [
        {
          'id': 'u1',
          'title_fr': 'Unité',
          'objective_fr': 'Objectif',
          'lessons': [for (final (i, s) in statuses.indexed) _lesson('l$i', s)],
        },
      ],
    },
  ],
});

void main() {
  test(
    'la prochaine leçon est la première non terminée et non verrouillée',
    () {
      final path = _path(['COMPLETED', 'AVAILABLE', 'LOCKED']);
      expect(path.nextLesson?.id, 'l1');
      expect(path.completedCount, 1);
    },
  );

  test('une leçon en cours est reprise en priorité', () {
    expect(_path(['IN_PROGRESS', 'LOCKED']).nextLesson?.id, 'l0');
  });

  test('parcours terminé : plus de prochaine leçon', () {
    expect(_path(['COMPLETED', 'COMPLETED']).nextLesson, isNull);
  });

  test(
    'un statut inconnu est traité comme disponible, jamais comme terminé',
    () {
      expect(_path(['???']).allLessons.first.status, NodeStatus.available);
    },
  );

  test("l'unité d'une leçon est retrouvée", () {
    final path = _path(['AVAILABLE']);
    expect(path.unitOf(path.allLessons.first)?.title, 'Unité');
  });

  test('le contenu de leçon ne garde que les blocs porteurs d\'exercice', () {
    final lesson = LessonContent.fromJson({
      'id': 'x',
      'title_fr': 'Titre',
      'xp_reward': 10,
      'unit': {'title_fr': 'U', 'objective_fr': 'O'},
      'blocks': [
        {
          'kind': 'INTRO',
          'payload': {'title_fr': 'Intro'},
          'exercise': null,
        },
        {
          'kind': 'PRACTICE',
          'payload': null,
          'exercise': {
            'id': 'e1',
            'type': 'LISTEN_AND_CHOOSE',
            'payload': {'prompt_fr': 'P'},
          },
        },
        {'kind': 'RECAP', 'payload': {}, 'exercise': null},
      ],
    });
    expect(lesson.introTitle, 'Intro');
    expect(lesson.exercises.map((e) => e.id), ['e1']);
  });
}
