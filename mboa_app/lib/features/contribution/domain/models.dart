/// Modèles de l'espace contributeur.
library;

class ContributorLanguage {
  const ContributorLanguage({
    required this.id,
    required this.name,
    required this.iso,
    required this.missingGloss,
    required this.total,
  });

  factory ContributorLanguage.fromJson(Map<String, dynamic> j) =>
      ContributorLanguage(
        id: j['id'] as String,
        name: j['name'] as String,
        iso: j['iso639_3'] as String,
        missingGloss: j['sans_glose'] as int,
        total: j['total'] as int,
      );

  final String id;
  final String name;
  final String iso;
  final int missingGloss;
  final int total;

  double get glossRatio => total == 0 ? 0 : (total - missingGloss) / total;
}

/// Une entrée du corpus telle que la voit un contributeur : la forme, son
/// enregistrement, et surtout sa provenance — on ne valide pas à l'aveugle.
class CorpusEntry {
  const CorpusEntry({
    required this.id,
    required this.lemma,
    required this.meaningFr,
    required this.category,
    required this.status,
    required this.hasGloss,
    this.audioUrl,
    this.audioAttribution,
    this.sourceTitle,
    this.sourceLicense,
    this.sourceLocator,
  });

  factory CorpusEntry.fromJson(Map<String, dynamic> j) => CorpusEntry(
    id: j['id'] as String,
    lemma: j['lemma'] as String,
    meaningFr: j['meaning_fr'] as String?,
    category: j['grammatical_category'] as String,
    status: j['status'] as String,
    hasGloss: j['has_gloss'] as bool,
    audioUrl: j['audio_url'] as String?,
    audioAttribution: j['audio_attribution'] as String?,
    sourceTitle: j['source_title'] as String?,
    sourceLicense: j['source_license'] as String?,
    sourceLocator: j['source_locator'] as String?,
  );

  final String id;
  final String lemma;
  final String? meaningFr;
  final String category;
  final String status;
  final bool hasGloss;
  final String? audioUrl;
  final String? audioAttribution;
  final String? sourceTitle;
  final String? sourceLicense;
  final String? sourceLocator;

  /// Une entrée traduite et relue attend une décision.
  bool get awaitsDecision => status == 'HUMAN_REVIEW';
  bool get isValidated => status == 'VALIDATED';
  bool get isPublished => status == 'PUBLISHED';
}

class ContributionQueue {
  const ContributionQueue({
    required this.languageId,
    required this.counts,
    required this.missingGloss,
    required this.entries,
  });

  factory ContributionQueue.fromJson(Map<String, dynamic> j) =>
      ContributionQueue(
        languageId: j['language_id'] as String,
        counts: Map<String, int>.from(j['counts'] as Map),
        missingGloss: j['missing_gloss'] as int,
        entries: (j['items'] as List)
            .map((e) => CorpusEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String languageId;
  final Map<String, int> counts;
  final int missingGloss;
  final List<CorpusEntry> entries;

  int get total => counts.values.fold(0, (a, b) => a + b);
  int get published => counts['PUBLISHED'] ?? 0;
  int get awaitingReview => counts['HUMAN_REVIEW'] ?? 0;
}

/// Catégories grammaticales proposées à la saisie.
const Map<String, String> kGrammaticalCategories = {
  'NOUN': 'Nom',
  'VERB': 'Verbe',
  'ADJ': 'Adjectif',
  'ADV': 'Adverbe',
  'PRON': 'Pronom',
  'NUM': 'Numéral',
  'PREP': 'Préposition',
  'CONJ': 'Conjonction',
  'INTERJ': 'Interjection',
  'EXPR': 'Expression',
  'OTHER': 'Autre',
};

const Map<String, String> kStatusLabels = {
  'DRAFT': 'Brouillon',
  'SOURCE_FOUND': 'Source trouvée',
  'TO_VERIFY': 'À traduire',
  'HUMAN_REVIEW': 'À relire',
  'VALIDATED': 'Validé',
  'PUBLISHED': 'Publié',
  'REJECTED': 'Rejeté',
};
