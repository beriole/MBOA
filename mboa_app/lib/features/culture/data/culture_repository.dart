import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/feed_models.dart';
import '../domain/gallery_models.dart';
import '../domain/models.dart';

class CultureRepository {
  CultureRepository(this._api);

  final ApiClient _api;

  Future<List<CultureCategory>> categories() async {
    final data = await _api.get('/culture/categories') as List;
    return data
        .map((e) => CultureCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CultureSummary>> contents({String? categoryCode}) async {
    final query = categoryCode == null ? '' : '?category=$categoryCode';
    final data = await _api.get('/culture$query');
    return (data['items'] as List)
        .map((e) => CultureSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CultureContent> content(String id) async => CultureContent.fromJson(
    await _api.get('/culture/$id') as Map<String, dynamic>,
  );

  /// Le fil du patrimoine : fiches publiées et enregistrements sourcés,
  /// mêlés par date. Quand [regionId] est donné, le fil se restreint à ce que
  /// des fiches publiées rattachent à cette région.
  Future<Feed> feed({String? regionId}) async {
    final query = regionId == null ? '' : '?region_id=$regionId';
    return Feed.fromJson(
      await _api.get('/culture/feed$query') as Map<String, dynamic>,
    );
  }

  /// La médiathèque : photographies et vidéos libres, avec leurs crédits.
  Future<Gallery> gallery({String? theme, String? kind}) async {
    final params = <String, String>{
      if (theme != null) 'theme': theme,
      if (kind != null) 'kind': kind,
    };
    final suffix = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return Gallery.fromJson(
      await _api.get('/culture/gallery$suffix') as Map<String, dynamic>,
    );
  }

  // --- Exploration par region (lot 9) ---------------------------------
  Future<List<CultureRegion>> regions() async {
    final data = await _api.get('/culture/regions') as List;
    return data
        .map((e) => CultureRegion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RegionDetail> region(String id) async => RegionDetail.fromJson(
    await _api.get('/culture/regions/$id') as Map<String, dynamic>,
  );

  /// Enregistrements et médias rattachés à une région.
  Future<RegionMedia> regionMedia(String regionId) async =>
      RegionMedia.fromJson(
        await _api.get('/culture/regions/$regionId/media')
            as Map<String, dynamic>,
      );

  // --- Favoris ---------------------------------------------------------
  Future<Favorites> favorites() async => Favorites.fromJson(
    await _api.get('/me/favorites') as Map<String, dynamic>,
  );

  Future<bool> isFavorite(String type, String id) async {
    final data = await _api.get('/me/favorites/$type/$id');
    return data['favori'] as bool;
  }

  /// Met un contenu de côté, ou l'en retire. Renvoie le nouvel état.
  Future<bool> toggleFavorite(
    String type,
    String id, {
    required bool add,
  }) async {
    final data = add
        ? await _api.put('/me/favorites/$type/$id')
        : await _api.delete('/me/favorites/$type/$id');
    return data['favori'] as bool;
  }

  // --- Quiz culturel ---------------------------------------------------
  Future<Quiz> quiz({int limit = 5}) async => Quiz.fromJson(
    await _api.get('/culture/quiz?limit=$limit') as Map<String, dynamic>,
  );

  /// La correction est faite par le serveur : la bonne reponse n'est jamais
  /// descendue jusqu'ici.
  Future<QuizVerdict> answer(String questionId, String choiceId) async =>
      QuizVerdict.fromJson(
        await _api.post('/culture/quiz/answer', {
              'question_id': questionId,
              'choice_id': choiceId,
            })
            as Map<String, dynamic>,
      );
}

final cultureRepositoryProvider = Provider<CultureRepository>(
  (ref) => CultureRepository(ref.watch(apiClientProvider)),
);

final cultureCategoriesProvider = FutureProvider<List<CultureCategory>>(
  (ref) => ref.watch(cultureRepositoryProvider).categories(),
);

/// `null` = toutes les rubriques.
final cultureContentsProvider =
    FutureProvider.family<List<CultureSummary>, String?>((ref, categoryCode) {
      return ref
          .watch(cultureRepositoryProvider)
          .contents(categoryCode: categoryCode);
    });

final cultureContentProvider = FutureProvider.family<CultureContent, String>(
  (ref, id) => ref.watch(cultureRepositoryProvider).content(id),
);

final cultureRegionsProvider = FutureProvider<List<CultureRegion>>(
  (ref) => ref.watch(cultureRepositoryProvider).regions(),
);

final cultureRegionProvider = FutureProvider.family<RegionDetail, String>(
  (ref, id) => ref.watch(cultureRepositoryProvider).region(id),
);

final cultureQuizProvider = FutureProvider<Quiz>(
  (ref) => ref.watch(cultureRepositoryProvider).quiz(),
);

final regionMediaProvider = FutureProvider.family<RegionMedia, String>(
  (ref, id) => ref.watch(cultureRepositoryProvider).regionMedia(id),
);

final favoritesProvider = FutureProvider<Favorites>(
  (ref) => ref.watch(cultureRepositoryProvider).favorites(),
);

/// État d'un favori précis, identifié par « TYPE/id ».
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, key) {
  final parts = key.split('/');
  return ref.watch(cultureRepositoryProvider).isFavorite(parts[0], parts[1]);
});

/// Le fil du patrimoine, éventuellement restreint à une région.
final cultureFeedProvider = FutureProvider.family<Feed, String?>(
  (ref, regionId) =>
      ref.watch(cultureRepositoryProvider).feed(regionId: regionId),
);

/// La médiathèque, éventuellement restreinte à un thème ou à un type.
final cultureGalleryProvider =
    FutureProvider.family<Gallery, ({String? theme, String? kind})>(
      (ref, filtre) => ref
          .watch(cultureRepositoryProvider)
          .gallery(theme: filtre.theme, kind: filtre.kind),
    );
