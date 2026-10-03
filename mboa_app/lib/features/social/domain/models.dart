/// Commentaires et avis.
///
/// Un seul modèle sert la boutique et le patrimoine, parce que la règle est la
/// même des deux côtés : **un avis n'est pas une source.** L'écran qui affiche
/// ces objets doit toujours montrer qui parle, et rappeler que ces propos ne
/// sont pas vérifiés.
///
/// La note (1 à 5) n'existe que là où elle a un sens : sur un objet vendu. On
/// ne note pas un fait de langue ou de culture, et le serveur refuse de le
/// faire — [Comments.rateable] porte cette distinction jusqu'à l'écran.
library;

class Comment {
  const Comment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.rating,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'] as String,
    author: j['auteur'] as String? ?? 'Anonyme',
    body: j['body_fr'] as String,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
    rating: (j['rating'] as num?)?.toInt(),
  );

  final String id;
  final String author;
  final String body;
  final DateTime? createdAt;
  final int? rating;
}

class Comments {
  const Comments({
    required this.items,
    required this.notice,
    this.average,
    this.voters = 0,
    this.rateable = false,
  });

  factory Comments.fromJson(Map<String, dynamic> j) => Comments(
    items: [
      for (final c in (j['commentaires'] as List? ?? const []))
        Comment.fromJson(c as Map<String, dynamic>),
    ],
    notice: j['avertissement'] as String? ?? '',
    average: (j['note_moyenne'] as num?)?.toDouble(),
    voters: (j['votants'] as num?)?.toInt() ?? 0,
    rateable: j['notable'] as bool? ?? false,
  );

  final List<Comment> items;

  /// L'avertissement vient du serveur : il ne doit pas dépendre de l'écran qui
  /// l'affiche, sinon un écran pourrait l'oublier.
  final String notice;
  final double? average;
  final int voters;

  /// Vrai seulement là où une note a un sens.
  final bool rateable;

  bool get isEmpty => items.isEmpty;
}
