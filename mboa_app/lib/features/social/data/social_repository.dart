import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/models.dart';

/// Accès aux commentaires et aux avis.
///
/// Les cibles possibles sont fixées par le serveur : `CULTURAL_CONTENT`,
/// `AUDIO`, `PRODUCT`. On ne les redéclare pas ici — une liste dupliquée
/// finirait par diverger de celle qui fait autorité.
class SocialRepository {
  SocialRepository(this._api);

  final ApiClient _api;

  Future<Comments> comments(String targetType, String targetId) async =>
      Comments.fromJson(
        await _api.get('/social/$targetType/$targetId/comments')
            as Map<String, dynamic>,
      );

  Future<Comment> add(
    String targetType,
    String targetId, {
    required String body,
    int? rating,
  }) async {
    final data = await _api.post('/social/$targetType/$targetId/comments', {
      'body_fr': body,
      if (rating != null) 'rating': rating,
    });
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  Future<void> remove(String commentId) =>
      _api.delete('/social/comments/$commentId');

  /// Signale un commentaire. Le serveur le masque sans l'effacer : la
  /// modération doit pouvoir lire ce qui a été signalé pour trancher.
  Future<String> report(String commentId, String reason) async {
    final data = await _api.post('/social/comments/$commentId/report', {
      'reason': reason,
    });
    return (data as Map<String, dynamic>)['message'] as String? ?? '';
  }
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(apiClientProvider)),
);

/// Les commentaires d'une cible, identifiée par son type et son identifiant.
final commentsProvider =
    FutureProvider.family<Comments, ({String type, String id})>(
      (ref, target) =>
          ref.watch(socialRepositoryProvider).comments(target.type, target.id),
    );
