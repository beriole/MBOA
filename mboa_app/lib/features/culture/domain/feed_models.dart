/// Le fil du patrimoine.
///
/// La forme est celle d'un fil social : des cartes, des images, des sons, des
/// commentaires dessous. Ce qui la remplit ne l'est pas. Un fil social affiche
/// ce que n'importe qui poste ; celui-ci n'affiche que ce qui est déjà passé
/// par la validation — une fiche porte sa source, un enregistrement porte son
/// auteur et sa licence.
///
/// D'où [FeedPost.source], jamais nul dans un fil correctement alimenté, et
/// [Feed.gaps], qui **annonce ce qui manque** au lieu de le combler.
library;

class FeedMedia {
  const FeedMedia({
    required this.kind,
    required this.url,
    this.caption,
    this.credit,
    this.license,
  });

  factory FeedMedia.fromJson(Map<String, dynamic> j) => FeedMedia(
    kind: j['kind'] as String,
    url: j['url'] as String,
    caption: j['caption'] as String?,
    credit: j['credit'] as String?,
    license: j['license'] as String?,
  );

  /// `IMAGE`, `AUDIO` ou `VIDEO`.
  final String kind;
  final String url;
  final String? caption;
  final String? credit;
  final String? license;
}

class FeedSource {
  const FeedSource({
    required this.title,
    this.authors = const [],
    this.year,
    this.url,
  });

  factory FeedSource.fromJson(Map<String, dynamic> j) => FeedSource(
    title: j['title'] as String? ?? '',
    authors: [for (final a in (j['authors'] as List? ?? const [])) a as String],
    year: (j['year'] as num?)?.toInt(),
    url: j['url'] as String?,
  );

  final String title;
  final List<String> authors;
  final int? year;
  final String? url;

  /// La référence en une ligne, telle qu'on la citerait.
  String get citation {
    final parts = <String>[
      if (authors.isNotEmpty) authors.join(', '),
      title,
      if (year != null) '$year',
    ];
    return parts.join(' — ');
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.kind,
    required this.title,
    required this.targetType,
    this.text,
    this.body,
    this.category,
    this.region,
    this.language,
    this.minutes,
    this.media = const [],
    this.audioUrl,
    this.attribution,
    this.speaker,
    this.date,
    this.source,
    this.comments = 0,
    this.favorites = 0,
  });

  factory FeedPost.fromJson(Map<String, dynamic> j) => FeedPost(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['titre'] as String,
    targetType: j['target_type'] as String,
    text: j['texte'] as String?,
    body: j['corps'] as String?,
    category: j['categorie'] as String?,
    region: j['region'] as String?,
    language: j['langue'] as String?,
    minutes: (j['minutes'] as num?)?.toInt(),
    media: [
      for (final m in (j['media'] as List? ?? const []))
        FeedMedia.fromJson(m as Map<String, dynamic>),
    ],
    audioUrl: j['audio_url'] as String?,
    attribution: j['attribution'] as String?,
    speaker: j['locuteur'] as String?,
    date: DateTime.tryParse(j['date'] as String? ?? ''),
    source: j['source'] == null
        ? null
        : FeedSource.fromJson(j['source'] as Map<String, dynamic>),
    comments: (j['commentaires'] as num?)?.toInt() ?? 0,
    favorites: (j['favoris'] as num?)?.toInt() ?? 0,
  );

  final String id;

  /// `FICHE` ou `ENREGISTREMENT`.
  final String kind;
  final String title;

  /// Le type à passer aux favoris et aux commentaires.
  final String targetType;

  /// Le résumé d'une fiche, ou la glose d'un mot — **nul quand elle manque.**
  /// Une glose absente n'est jamais remplacée par une approximation.
  final String? text;
  final String? body;
  final String? category;
  final String? region;
  final String? language;
  final int? minutes;
  final List<FeedMedia> media;
  final String? audioUrl;
  final String? attribution;
  final String? speaker;
  final DateTime? date;

  /// Ce qui répond de cette publication, hors de MBOA.
  final FeedSource? source;
  final int comments;
  final int favorites;

  bool get isRecording => kind == 'ENREGISTREMENT';
  FeedMedia? get image => _first('IMAGE');
  FeedMedia? get video => _first('VIDEO');

  FeedMedia? _first(String kind) {
    for (final m in media) {
      if (m.kind == kind) return m;
    }
    return null;
  }
}

/// Ce qui manque au catalogue, et pourquoi on le dit au lieu de l'illustrer.
class FeedGap {
  const FeedGap({required this.kind, required this.message});

  factory FeedGap.fromJson(Map<String, dynamic> j) =>
      FeedGap(kind: j['kind'] as String, message: j['message'] as String);

  final String kind;
  final String message;
}

class Feed {
  const Feed({
    required this.posts,
    required this.counts,
    required this.gaps,
    required this.notice,
  });

  factory Feed.fromJson(Map<String, dynamic> j) => Feed(
    posts: [
      for (final p in (j['posts'] as List? ?? const []))
        FeedPost.fromJson(p as Map<String, dynamic>),
    ],
    counts: {
      for (final e in (j['compteurs'] as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    gaps: [
      for (final g in (j['manques'] as List? ?? const []))
        FeedGap.fromJson(g as Map<String, dynamic>),
    ],
    notice: j['avertissement'] as String? ?? '',
  );

  final List<FeedPost> posts;
  final Map<String, int> counts;
  final List<FeedGap> gaps;
  final String notice;

  bool get isEmpty => posts.isEmpty;
}
