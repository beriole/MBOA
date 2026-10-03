/// Modèles de la traduction (SS41).
library;

/// Comment une correspondance a été trouvée. L'apprenant doit pouvoir faire la
/// différence entre « c'est exactement ce mot » et « c'est peut-être celui-ci ».
enum MatchKind {
  /// L'orthographe saisie correspond exactement.
  exact,

  /// Correspond une fois les tons retirés.
  toneless,

  /// Correspond une fois les lettres ɓ ɛ ɔ ŋ remplacées par leur équivalent
  /// clavier : c'est le cas le plus fréquent depuis un téléphone.
  folded,

  /// Forme approchante (faute de frappe, variante) : à confirmer.
  fuzzy,
}

MatchKind _kind(String value) => switch (value) {
  'EXACT' => MatchKind.exact,
  'TONELESS' => MatchKind.toneless,
  'FOLDED' => MatchKind.folded,
  _ => MatchKind.fuzzy,
};

class TranslationMatch {
  const TranslationMatch({
    required this.vocabularyId,
    required this.lemma,
    required this.meaningFr,
    required this.category,
    required this.kind,
    required this.confidence,
    this.audioUrl,
    this.audioAttribution,
    this.sourceTitle,
    this.sourceLicense,
    this.examples = const [],
  });

  factory TranslationMatch.fromJson(Map<String, dynamic> j) => TranslationMatch(
    vocabularyId: j['vocabulary_id'] as String,
    lemma: j['lemma'] as String,
    meaningFr: j['meaning_fr'] as String?,
    category: j['grammatical_category'] as String,
    kind: _kind(j['kind'] as String),
    confidence: (j['confidence'] as num).toDouble(),
    audioUrl: j['audio_url'] as String?,
    audioAttribution: j['audio_attribution'] as String?,
    sourceTitle: j['source_title'] as String?,
    sourceLicense: j['source_license'] as String?,
    examples: (j['examples'] as List? ?? [])
        .map((e) => TranslationExample.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String vocabularyId;
  final String lemma;
  final String? meaningFr;
  final String category;
  final MatchKind kind;
  final double confidence;
  final String? audioUrl;
  final String? audioAttribution;
  final String? sourceTitle;
  final String? sourceLicense;
  final List<TranslationExample> examples;

  /// Une forme sans traduction validée : on l'affiche quand même, mais en le disant.
  bool get awaitsGloss => meaningFr == null;
}

class TranslationExample {
  const TranslationExample({required this.text, this.translationFr});

  factory TranslationExample.fromJson(Map<String, dynamic> j) =>
      TranslationExample(
        text: j['text'] as String,
        translationFr: j['translation_fr'] as String?,
      );

  final String text;
  final String? translationFr;
}

class TranslationResult {
  const TranslationResult({
    required this.requestId,
    required this.mode,
    required this.message,
    required this.disclaimer,
    required this.matches,
    this.confidence,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> j) =>
      TranslationResult(
        requestId: j['request_id'] as String,
        mode: j['mode'] as String,
        message: j['message'] as String,
        disclaimer: j['disclaimer'] as String,
        confidence: (j['confidence'] as num?)?.toDouble(),
        matches: (j['matches'] as List)
            .map((e) => TranslationMatch.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String requestId;
  final String mode;
  final String message;
  final String disclaimer;
  final double? confidence;
  final List<TranslationMatch> matches;

  bool get isEmpty => matches.isEmpty;
}
