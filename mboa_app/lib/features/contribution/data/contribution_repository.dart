import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/models.dart';

/// Accès à l'espace contributeur.
///
/// Toutes les règles de validation restent côté serveur : ce dépôt ne fait
/// qu'envoyer la saisie et la décision.
class ContributionRepository {
  ContributionRepository(this._api);

  final ApiClient _api;

  Future<List<ContributorLanguage>> languages() async {
    final data = await _api.get('/cms/languages') as List;
    return data
        .map((e) => ContributorLanguage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ContributionQueue> queue(
    String languageId, {
    bool onlyMissingGloss = false,
  }) async {
    final data = await _api.get(
      '/cms/queue?language_id=$languageId&only_missing_gloss=$onlyMissingGloss',
    );
    return ContributionQueue.fromJson(data as Map<String, dynamic>);
  }

  /// Enregistre une saisie. Le serveur renvoie le nouveau statut et un message
  /// explicite (par exemple : renvoyé en relecture).
  Future<({String status, String message})> save(
    String entryId, {
    String? meaningFr,
    String? meaningEn,
    String? category,
    String? lemma,
    String? ipa,
  }) async {
    final body = <String, dynamic>{
      if (meaningFr != null) 'meaning_fr': meaningFr,
      if (meaningEn != null && meaningEn.isNotEmpty) 'meaning_en': meaningEn,
      if (category != null) 'grammatical_category': category,
      if (lemma != null) 'lemma': lemma,
      if (ipa != null && ipa.isNotEmpty) 'ipa': ipa,
    };
    final data = await _api.patch('/cms/vocabulary/$entryId', body);
    return (
      status: data['status'] as String,
      message: data['message'] as String,
    );
  }

  Future<({String status, String message})> decide(
    String entryId, {
    required String decision,
    String? comment,
  }) async {
    final data = await _api.post('/cms/vocabulary/$entryId/decision', {
      'decision': decision,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return (
      status: data['status'] as String,
      message: data['message'] as String,
    );
  }

  Future<({String status, String message})> publish(String entryId) async {
    final data = await _api.post('/cms/vocabulary/$entryId/publish');
    return (
      status: data['status'] as String,
      message: data['message'] as String,
    );
  }
}

final contributionRepositoryProvider = Provider<ContributionRepository>(
  (ref) => ContributionRepository(ref.watch(apiClientProvider)),
);

final contributorLanguagesProvider = FutureProvider<List<ContributorLanguage>>(
  (ref) => ref.watch(contributionRepositoryProvider).languages(),
);

final contributionQueueProvider =
    FutureProvider.family<ContributionQueue, String>((ref, languageId) {
      return ref.watch(contributionRepositoryProvider).queue(languageId);
    });
