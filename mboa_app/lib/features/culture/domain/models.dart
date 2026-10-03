/// Modèles du Culture Hub (SS20, SS21).
library;

class CultureCategory {
  const CultureCategory({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.publishedCount,
  });

  factory CultureCategory.fromJson(Map<String, dynamic> j) => CultureCategory(
    id: j['id'] as String,
    code: j['code'] as String,
    name: j['name_fr'] as String,
    description: j['description_fr'] as String?,
    publishedCount: j['published_count'] as int,
  );

  final String id;
  final String code;
  final String name;
  final String? description;
  final int publishedCount;

  /// Une rubrique vide reste affichée : montrer ce qui reste à documenter
  /// fait partie du propos du projet.
  bool get isEmpty => publishedCount == 0;
}

class CultureSummary {
  const CultureSummary({
    required this.id,
    required this.title,
    required this.summary,
    required this.categoryName,
    required this.readingMinutes,
    this.regionName,
    this.languageName,
  });

  factory CultureSummary.fromJson(Map<String, dynamic> j) => CultureSummary(
    id: j['id'] as String,
    title: j['title_fr'] as String,
    summary: j['summary_fr'] as String,
    categoryName: j['category_name'] as String,
    readingMinutes: j['reading_minutes'] as int,
    regionName: j['region_name'] as String?,
    languageName: j['language_name'] as String?,
  );

  final String id;
  final String title;
  final String summary;
  final String categoryName;
  final int readingMinutes;
  final String? regionName;
  final String? languageName;
}

class CultureSource {
  const CultureSource({
    required this.title,
    this.authors = const [],
    this.year,
    this.url,
    this.license,
    this.locator,
  });

  factory CultureSource.fromJson(Map<String, dynamic> j) => CultureSource(
    title: j['title'] as String,
    authors: ((j['authors'] as List?) ?? const []).cast<String>(),
    year: j['year'] as int?,
    url: j['url'] as String?,
    license: j['license'] as String?,
    locator: j['locator'] as String?,
  );

  final String title;
  final List<String> authors;
  final int? year;
  final String? url;
  final String? license;
  final String? locator;

  /// Référence lisible : « Auteur, Auteur (année) ».
  String get citation {
    final who = authors.isEmpty ? null : authors.join(', ');
    final when = year?.toString();
    final parts = [who, when].whereType<String>();
    return parts.isEmpty ? title : '$title — ${parts.join(', ')}';
  }
}

class CultureContent {
  const CultureContent({
    required this.id,
    required this.title,
    required this.summary,
    required this.categoryName,
    required this.readingMinutes,
    this.body,
    this.regionName,
    this.languageName,
    this.validatedBy,
    this.sources = const [],
    this.related = const [],
  });

  factory CultureContent.fromJson(Map<String, dynamic> j) => CultureContent(
    id: j['id'] as String,
    title: j['title_fr'] as String,
    summary: j['summary_fr'] as String,
    body: j['body_fr'] as String?,
    categoryName: j['category_name'] as String,
    readingMinutes: j['reading_minutes'] as int,
    regionName: j['region_name'] as String?,
    languageName: j['language_name'] as String?,
    validatedBy: j['validated_by'] as String?,
    sources: ((j['sources'] as List?) ?? const [])
        .map((e) => CultureSource.fromJson(e as Map<String, dynamic>))
        .toList(),
    related: ((j['related'] as List?) ?? const [])
        .map((e) => CultureSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String title;
  final String summary;
  final String? body;
  final String categoryName;
  final int readingMinutes;
  final String? regionName;
  final String? languageName;
  final String? validatedBy;
  final List<CultureSource> sources;
  final List<CultureSummary> related;

  List<String> get paragraphs => (body ?? '')
      .split('\n\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

/// La carte « Le savais-tu ? » affichée à l'intérieur d'une leçon (SS21).
class CultureCard {
  const CultureCard({
    required this.id,
    required this.title,
    required this.summary,
    required this.categoryName,
    this.sourceTitle,
  });

  factory CultureCard.fromJson(Map<String, dynamic> j) => CultureCard(
    id: j['id'] as String,
    title: j['title_fr'] as String,
    summary: j['summary_fr'] as String,
    categoryName: j['category_name'] as String,
    sourceTitle: j['source_title'] as String?,
  );

  final String id;
  final String title;
  final String summary;
  final String categoryName;
  final String? sourceTitle;
}

/// Une région du Cameroun, avec ce qui y est documenté (lot 9).
class CultureRegion {
  const CultureRegion({
    required this.id,
    required this.code,
    required this.name,
    required this.fiches,
    this.langues = 0,
  });

  factory CultureRegion.fromJson(Map<String, dynamic> j) => CultureRegion(
    id: j['id'] as String,
    code: j['code'] as String,
    name: j['name'] as String,
    fiches: j['fiches'] as int? ?? 0,
    langues: j['langues'] as int? ?? 0,
  );

  final String id;
  final String code;
  final String name;
  final int fiches;
  final int langues;

  /// Une région sans fiche reste affichée : c'est une carte du travail à faire.
  bool get isEmpty => fiches == 0;
}

/// Rubrique représentée dans une région : les onglets de la maquette sont
/// construits sur ce qui existe, pas sur une liste fixe.
class RegionTopic {
  const RegionTopic({
    required this.code,
    required this.name,
    required this.fiches,
  });

  factory RegionTopic.fromJson(Map<String, dynamic> j) => RegionTopic(
    code: j['code'] as String,
    name: j['name'] as String,
    fiches: j['fiches'] as int,
  );

  final String code;
  final String name;
  final int fiches;
}

class RegionDetail {
  const RegionDetail({
    required this.region,
    required this.counts,
    required this.topics,
    required this.media,
    required this.contents,
  });

  factory RegionDetail.fromJson(Map<String, dynamic> j) => RegionDetail(
    region: CultureRegion.fromJson({
      ...j['region'] as Map<String, dynamic>,
      'fiches': (j['chiffres'] as Map)['fiches'],
    }),
    counts: Map<String, int>.from(
      (j['chiffres'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
    ),
    topics: (j['rubriques'] as List)
        .map((e) => RegionTopic.fromJson(e as Map<String, dynamic>))
        .toList(),
    media: Map<String, int>.from(
      (j['medias'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
    ),
    contents: (j['fiches'] as List)
        .map((e) => CultureSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final CultureRegion region;
  final Map<String, int> counts;
  final List<RegionTopic> topics;

  /// Nombre de médias par type : IMAGE, AUDIO, VIDEO.
  final Map<String, int> media;
  final List<CultureSummary> contents;

  int mediaCount(String kind) => media[kind] ?? 0;
}

/// Une proposition de réponse au quiz.
class QuizChoice {
  const QuizChoice({required this.id, required this.label, this.audioUrl});

  factory QuizChoice.fromJson(Map<String, dynamic> j) => QuizChoice(
    id: j['id'] as String,
    label: j['label'] as String,
    audioUrl: j['audio_url'] as String?,
  );

  final String id;
  final String label;

  /// Renseigné quand c'est la proposition elle-même qui s'écoute : le libellé
  /// est alors neutre (« Enregistrement 2 »), sans quoi la réponse se lirait.
  final String? audioUrl;
}

/// Une question du quiz culturel.
///
/// Aucun champ ne désigne la bonne réponse : la correction est faite par le
/// serveur, qui la relit depuis la base.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.choices,
    this.audioUrl,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: j['id'] as String,
    type: j['type'] as String,
    prompt: j['prompt_fr'] as String,
    audioUrl: j['audio_url'] as String?,
    choices: (j['choices'] as List)
        .map((e) => QuizChoice.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String type;
  final String prompt;
  final List<QuizChoice> choices;

  /// Renseigné quand l'énoncé s'écoute plutôt qu'il ne se lit.
  final String? audioUrl;

  /// Vrai si la question se joue à l'oreille, d'un côté ou de l'autre.
  bool get isListening =>
      audioUrl != null || choices.any((c) => c.audioUrl != null);
}

class Quiz {
  const Quiz({
    required this.questions,
    required this.message,
    required this.publishedCount,
    this.recordedCount = 0,
    this.availableCount = 0,
  });

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
    questions: (j['questions'] as List)
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList(),
    message: j['message'] as String? ?? '',
    publishedCount: j['fiches_publiees'] as int? ?? 0,
    recordedCount: j['mots_enregistres'] as int? ?? 0,
    availableCount: j['questions_disponibles'] as int? ?? 0,
  );

  final List<QuizQuestion> questions;
  final String message;

  /// De quoi le quiz est tiré. Ces deux nombres expliquent son étendue : elle
  /// est dictée par le corpus validé, pas par un choix d'affichage.
  final int publishedCount;
  final int recordedCount;

  /// Tout ce que le corpus permettrait aujourd'hui, au-delà de ce tirage.
  final int availableCount;

  bool get isEmpty => questions.isEmpty;
}

/// Correction d'une réponse, avec ce qui l'établit.
///
/// Une question de fiche renvoie la fiche et sa source ; une question d'écoute
/// renvoie l'attribution de l'enregistrement. D'où [contentId] et
/// [contentTitle] optionnels : il n'y a pas toujours de fiche derrière, mais il
/// y a toujours quelque chose.
class QuizVerdict {
  const QuizVerdict({
    required this.isCorrect,
    required this.correctLabel,
    required this.correctId,
    required this.explanation,
    this.contentId,
    this.contentTitle,
    this.sourceTitle,
    this.audioUrl,
  });

  factory QuizVerdict.fromJson(Map<String, dynamic> j) {
    final fiche = j['fiche'] as Map<String, dynamic>?;
    return QuizVerdict(
      isCorrect: j['is_correct'] as bool,
      correctLabel: j['correct_label'] as String,
      correctId: j['correct_id'] as String? ?? '',
      explanation: j['explication_fr'] as String,
      contentId: fiche?['id'] as String?,
      contentTitle: fiche?['title_fr'] as String?,
      sourceTitle: j['source'] == null
          ? null
          : (j['source'] as Map)['title'] as String?,
      audioUrl: j['audio_url'] as String?,
    );
  }

  final bool isCorrect;
  final String correctLabel;

  /// L'identifiant de la bonne proposition. On repère par lui, jamais par le
  /// libellé : deux propositions peuvent porter le même texte, et les questions
  /// d'écoute ont des libellés volontairement neutres.
  final String correctId;
  final String explanation;
  final String? contentId;
  final String? contentTitle;
  final String? sourceTitle;

  /// La piste de la bonne réponse, sur une question d'écoute : on veut
  /// réentendre ce qu'on n'a pas reconnu.
  final String? audioUrl;

  /// Vrai quand une fiche peut être ouverte pour vérifier.
  bool get hasContent => contentId != null;
}

/// Un enregistrement réel, avec son attribution et sa licence (lot 9).
///
/// L'attribution n'est pas décorative : CC BY-SA l'exige, et elle voyage donc
/// avec chaque piste jusqu'à l'écran.
class Recording {
  const Recording({
    required this.id,
    required this.lemma,
    required this.languageName,
    this.meaning,
    this.attribution,
    this.license,
    this.speakerCode,
    this.durationMs,
  });

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
    id: j['id'] as String,
    lemma: j['lemma'] as String,
    languageName: j['language_name'] as String? ?? '',
    meaning: j['meaning_fr'] as String?,
    attribution: j['attribution'] as String?,
    license: j['license'] as String?,
    speakerCode: j['speaker_code'] as String?,
    durationMs: j['duration_ms'] as int?,
  );

  final String id;
  final String lemma;
  final String languageName;
  final String? meaning;
  final String? attribution;
  final String? license;
  final String? speakerCode;
  final int? durationMs;

  /// Le sens n'est pas toujours connu : un mot peut être attesté et enregistré
  /// sans que personne ait encore confirmé ce qu'il veut dire.
  bool get hasMeaning => meaning != null && meaning!.isNotEmpty;
}

/// La langue qu'une fiche publiée rattache à une région, et la fiche qui
/// l'établit : le lien est traçable, il n'est pas décrété.
class RegionLanguage {
  const RegionLanguage({
    required this.id,
    required this.name,
    required this.contentId,
    required this.contentTitle,
  });

  factory RegionLanguage.fromJson(Map<String, dynamic> j) => RegionLanguage(
    id: j['id'] as String,
    name: j['name'] as String,
    contentId: j['fiche_id'] as String,
    contentTitle: j['fiche_titre'] as String,
  );

  final String id;
  final String name;
  final String contentId;
  final String contentTitle;
}

class RegionMedia {
  const RegionMedia({
    required this.regionName,
    required this.languages,
    required this.recordings,
    required this.counts,
    required this.provenance,
    this.videoNotice,
  });

  factory RegionMedia.fromJson(Map<String, dynamic> j) => RegionMedia(
    regionName: (j['region'] as Map)['name'] as String,
    languages: (j['langues'] as List)
        .map((e) => RegionLanguage.fromJson(e as Map<String, dynamic>))
        .toList(),
    recordings: (j['enregistrements'] as List)
        .map((e) => Recording.fromJson(e as Map<String, dynamic>))
        .toList(),
    counts: Map<String, int>.from(
      (j['compteurs'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
    ),
    provenance: j['provenance'] as String? ?? '',
    videoNotice: j['video'] as String?,
  );

  final String regionName;
  final List<RegionLanguage> languages;
  final List<Recording> recordings;
  final Map<String, int> counts;

  /// D'où vient le rattachement entre la région et ces enregistrements.
  final String provenance;

  /// Renseigné seulement quand aucune vidéo n'existe.
  final String? videoNotice;
}

/// Ce qu'une personne a mis de côté.
class Favorites {
  const Favorites({required this.contents, required this.recordings});

  factory Favorites.fromJson(Map<String, dynamic> j) => Favorites(
    contents: (j['fiches'] as List)
        .map(
          (e) => CultureSummary.fromJson({
            ...e as Map<String, dynamic>,
            'category_name': e['category_name'],
          }),
        )
        .toList(),
    recordings: (j['enregistrements'] as List)
        .map((e) => Recording.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final List<CultureSummary> contents;
  final List<Recording> recordings;

  bool get isEmpty => contents.isEmpty && recordings.isEmpty;
  int get total => contents.length + recordings.length;
}
