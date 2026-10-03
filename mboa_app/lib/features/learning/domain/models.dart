/// Modèles du parcours d'apprentissage, tels que servis par l'API.
///
/// Aucun contenu de cours n'est codé en dur dans l'application (SS42) :
/// tout provient de ces objets.
library;

import '../../culture/domain/models.dart';

class Language {
  const Language({
    required this.id,
    required this.iso,
    required this.name,
    this.autonym,
    this.toneCount,
    required this.publishedWords,
  });

  factory Language.fromJson(Map<String, dynamic> j) => Language(
    id: j['id'] as String,
    iso: j['iso639_3'] as String,
    name: j['name'] as String,
    autonym: j['autonym'] as String?,
    toneCount: j['tone_count'] as int?,
    publishedWords: j['published_words'] as int? ?? 0,
  );

  final String id;
  final String iso;
  final String name;
  final String? autonym;
  final int? toneCount;
  final int publishedWords;
}

enum NodeStatus { locked, available, inProgress, completed }

NodeStatus _status(String? s) => switch (s) {
  'COMPLETED' => NodeStatus.completed,
  'IN_PROGRESS' => NodeStatus.inProgress,
  'LOCKED' => NodeStatus.locked,
  _ => NodeStatus.available,
};

class LessonNode {
  const LessonNode({
    required this.id,
    required this.title,
    required this.kind,
    required this.minutes,
    required this.xp,
    required this.status,
    this.bestScore,
  });

  factory LessonNode.fromJson(Map<String, dynamic> j) => LessonNode(
    id: j['id'] as String,
    title: j['title_fr'] as String,
    kind: j['kind'] as String,
    minutes: j['estimated_minutes'] as int,
    xp: j['xp_reward'] as int,
    status: _status(j['status'] as String?),
    bestScore: (j['best_score'] as num?)?.toDouble(),
  );

  final String id;
  final String title;
  final String kind;
  final int minutes;
  final int xp;
  final NodeStatus status;
  final double? bestScore;
}

class UnitNode {
  const UnitNode({
    required this.id,
    required this.title,
    required this.objective,
    required this.lessons,
  });

  factory UnitNode.fromJson(Map<String, dynamic> j) => UnitNode(
    id: j['id'] as String,
    title: j['title_fr'] as String,
    objective: j['objective_fr'] as String,
    lessons: (j['lessons'] as List)
        .map((e) => LessonNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String title;
  final String objective;
  final List<LessonNode> lessons;
}

class SectionNode {
  const SectionNode({
    required this.title,
    required this.objective,
    required this.units,
  });

  factory SectionNode.fromJson(Map<String, dynamic> j) => SectionNode(
    title: j['title_fr'] as String,
    objective: j['objective_fr'] as String?,
    units: (j['units'] as List)
        .map((e) => UnitNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String title;
  final String? objective;
  final List<UnitNode> units;
}

class LearningPath {
  const LearningPath({
    required this.courseTitle,
    required this.level,
    required this.sections,
  });

  factory LearningPath.fromJson(Map<String, dynamic> j) => LearningPath(
    courseTitle: j['course']['title_fr'] as String,
    level: j['course']['level'] as String,
    sections: (j['sections'] as List)
        .map((e) => SectionNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String courseTitle;
  final String level;
  final List<SectionNode> sections;

  Iterable<LessonNode> get allLessons =>
      sections.expand((s) => s.units).expand((u) => u.lessons);

  /// La prochaine leçon à faire : c'est elle que "Continuer" ouvre.
  LessonNode? get nextLesson {
    for (final lesson in allLessons) {
      if (lesson.status != NodeStatus.completed &&
          lesson.status != NodeStatus.locked) {
        return lesson;
      }
    }
    return null;
  }

  UnitNode? unitOf(LessonNode lesson) {
    for (final unit in sections.expand((s) => s.units)) {
      if (unit.lessons.any((l) => l.id == lesson.id)) return unit;
    }
    return null;
  }

  int get completedCount =>
      allLessons.where((l) => l.status == NodeStatus.completed).length;
}

/// Exercice tel que reçu : la réponse n'y figure jamais.
class Exercise {
  const Exercise({required this.id, required this.type, required this.payload});

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    type: j['type'] as String,
    payload: Map<String, dynamic>.from(j['payload'] as Map),
  );

  final String id;
  final String type;
  final Map<String, dynamic> payload;

  String get prompt => payload['prompt_fr'] as String? ?? '';
}

class LessonContent {
  const LessonContent({
    required this.id,
    required this.title,
    required this.unitObjective,
    required this.xpReward,
    required this.introTitle,
    required this.introSubtitle,
    required this.exercises,
    this.cultureCard,
  });

  factory LessonContent.fromJson(Map<String, dynamic> j) {
    final blocks = (j['blocks'] as List).cast<Map<String, dynamic>>();
    final intro = blocks.where((b) => b['kind'] == 'INTRO').firstOrNull;
    return LessonContent(
      id: j['id'] as String,
      title: j['title_fr'] as String,
      unitObjective: j['unit']['objective_fr'] as String,
      xpReward: j['xp_reward'] as int,
      introTitle:
          intro?['payload']?['title_fr'] as String? ?? j['title_fr'] as String,
      introSubtitle: intro?['payload']?['subtitle_fr'] as String?,
      exercises: blocks
          .where((b) => b['exercise'] != null)
          .map((b) => Exercise.fromJson(b['exercise'] as Map<String, dynamic>))
          .toList(),
      // Nulle quand l'unité n'a pas de fiche rattachée : on n'invente pas de
      // contenu de remplissage.
      cultureCard: j['culture_card'] == null
          ? null
          : CultureCard.fromJson(j['culture_card'] as Map<String, dynamic>),
    );
  }

  final String id;
  final String title;
  final String unitObjective;
  final int xpReward;
  final String introTitle;
  final String? introSubtitle;
  final List<Exercise> exercises;

  /// Carte « Le savais-tu ? » de l'unité (SS21).
  final CultureCard? cultureCard;
}

class AttemptResult {
  const AttemptResult({
    required this.isCorrect,
    this.correctAnswer,
    this.explanation,
    this.detail,
    required this.xpDelta,
  });

  factory AttemptResult.fromJson(Map<String, dynamic> j) => AttemptResult(
    isCorrect: j['is_correct'] as bool,
    correctAnswer: j['correct_answer'],
    explanation: j['explanation_fr'] as String?,
    detail: j['detail'] as String?,
    xpDelta: j['xp_delta'] as int? ?? 0,
  );

  final bool isCorrect;
  final Object? correctAnswer;
  final String? explanation;
  final String? detail;
  final int xpDelta;
}

class LessonSummary {
  const LessonSummary({
    required this.score,
    required this.correct,
    required this.total,
    required this.xpAwarded,
    required this.totalXp,
    required this.streakDays,
    required this.itemsToReview,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> j) => LessonSummary(
    score: (j['score'] as num).toDouble(),
    correct: j['correct'] as int,
    total: j['total'] as int,
    xpAwarded: j['xp_awarded'] as int,
    totalXp: j['total_xp'] as int,
    streakDays: j['streak']['current_days'] as int,
    itemsToReview: j['items_to_review'] as int,
  );

  final double score;
  final int correct;
  final int total;
  final int xpAwarded;
  final int totalXp;
  final int streakDays;
  final int itemsToReview;
}

class Provenance {
  const Provenance({
    required this.lemma,
    this.meaning,
    required this.sourceTitle,
    required this.license,
    this.sourceUrl,
    this.validatedBy,
    required this.references,
    required this.history,
  });

  factory Provenance.fromJson(Map<String, dynamic> j) => Provenance(
    lemma: j['lemma'] as String,
    meaning: j['meaning_fr'] as String?,
    sourceTitle: j['source']['title'] as String? ?? '—',
    license: j['source']['license'] as String? ?? '—',
    sourceUrl: j['source']['url'] as String?,
    validatedBy: j['validated_by'] as String?,
    references: (j['references'] as List)
        .map((r) => (r as Map)['locator'] as String? ?? '')
        .toList(),
    history: (j['history'] as List)
        .map(
          (h) =>
              '${(h as Map)['from_status'] ?? 'création'} → ${h['to_status']}',
        )
        .toList(),
  );

  final String lemma;
  final String? meaning;
  final String sourceTitle;
  final String license;
  final String? sourceUrl;
  final String? validatedBy;
  final List<String> references;
  final List<String> history;
}
