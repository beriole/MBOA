import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/models.dart';

class TranslationRepository {
  TranslationRepository(this._api);

  final ApiClient _api;

  /// `intoFrench` : true si l'on saisit un mot de la langue nationale.
  Future<TranslationResult> translate({
    required String languageId,
    required String text,
    required bool intoFrench,
  }) async {
    final data = await _api.post('/translate', {
      'language_id': languageId,
      'text': text,
      'into_french': intoFrench,
    });
    return TranslationResult.fromJson(data as Map<String, dynamic>);
  }

  /// Signale une correspondance douteuse : elle rejoint la file des spécialistes.
  Future<String> report(String requestId, {String? comment}) async {
    final data = await _api.post('/translate/$requestId/report', {
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return data['message'] as String;
  }
}

final translationRepositoryProvider = Provider<TranslationRepository>(
  (ref) => TranslationRepository(ref.watch(apiClientProvider)),
);
