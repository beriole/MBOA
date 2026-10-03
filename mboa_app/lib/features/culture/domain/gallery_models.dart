/// La médiathèque : photographies et vidéos libres.
///
/// Trois champs sont obligatoires et ne doivent jamais être perdus en route :
/// [GalleryMedia.author], [GalleryMedia.license] et [GalleryMedia.sourceUrl].
/// Sans eux, rediffuser le média serait illicite — et sans eux, personne ne peut
/// vérifier d'où il vient.
///
/// [GalleryMedia.title] et [GalleryMedia.description] sont les mots de l'auteur
/// sur Wikimedia Commons, recopiés tels quels. MBOA n'en ajoute aucun : dire
/// d'un masque qu'il est bamileke serait une affirmation, et elle
/// n'appartient pas à la plateforme.
library;

class GalleryMedia {
  const GalleryMedia({
    required this.id,
    required this.kind,
    required this.url,
    required this.title,
    required this.author,
    required this.license,
    required this.sourceUrl,
    required this.theme,
    this.description,
    this.region,
    this.width,
    this.height,
  });

  factory GalleryMedia.fromJson(Map<String, dynamic> j) => GalleryMedia(
    id: j['id'] as String,
    kind: j['kind'] as String,
    url: j['url'] as String,
    title: j['titre'] as String,
    author: j['auteur'] as String,
    license: j['license'] as String,
    sourceUrl: j['source_url'] as String,
    theme: j['theme'] as String,
    description: j['description'] as String?,
    region: j['region'] as String?,
    width: (j['largeur'] as num?)?.toInt(),
    height: (j['hauteur'] as num?)?.toInt(),
  );

  final String id;

  /// `IMAGE` ou `VIDEO`.
  final String kind;
  final String url;

  /// Le titre donné par l'auteur sur Commons.
  final String title;
  final String? description;

  /// Qui l'a produit. Obligatoire : CC BY et CC BY-SA sont inapplicables sans.
  final String author;
  final String license;

  /// La page Commons : licence, auteur et historique y restent vérifiables.
  final String sourceUrl;

  /// Étiquette de rangement (artisanat, danse, marché…), pas une affirmation.
  final String theme;
  final String? region;
  final int? width;
  final int? height;

  bool get isVideo => kind == 'VIDEO';

  /// Le rapport largeur/hauteur connu, quand Commons l'a renseigné.
  double? get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : null;

  /// Le crédit en une ligne, tel qu'il doit accompagner le média.
  String get credit => '$author — $license';
}

class GalleryTheme {
  const GalleryTheme({
    required this.code,
    required this.total,
    this.videos = 0,
  });

  factory GalleryTheme.fromJson(Map<String, dynamic> j) => GalleryTheme(
    code: j['code'] as String,
    total: (j['total'] as num).toInt(),
    videos: (j['videos'] as num?)?.toInt() ?? 0,
  );

  final String code;
  final int total;
  final int videos;
}

class Gallery {
  const Gallery({
    required this.medias,
    required this.themes,
    required this.total,
    required this.notice,
  });

  factory Gallery.fromJson(Map<String, dynamic> j) => Gallery(
    medias: [
      for (final m in (j['medias'] as List? ?? const []))
        GalleryMedia.fromJson(m as Map<String, dynamic>),
    ],
    themes: [
      for (final t in (j['themes'] as List? ?? const []))
        GalleryTheme.fromJson(t as Map<String, dynamic>),
    ],
    total: (j['total'] as num?)?.toInt() ?? 0,
    notice: j['avertissement'] as String? ?? '',
  );

  final List<GalleryMedia> medias;
  final List<GalleryTheme> themes;
  final int total;

  /// L'avertissement vient du serveur : il ne doit pas dépendre de l'écran.
  final String notice;

  bool get isEmpty => medias.isEmpty;
  int get videos => themes.fold(0, (a, t) => a + t.videos);
}
