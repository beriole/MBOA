import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../culture/data/culture_repository.dart';
import '../culture/domain/models.dart';

/// Ce que le corpus publié permet en matière de test de positionnement.
///
/// Le serveur décide : l'application n'estime pas elle-même si un test aurait
/// du sens.
class PlacementInfo {
  const PlacementInfo({
    required this.available,
    required this.published,
    required this.required,
    required this.explanation,
    this.types = 0,
    this.typesRequired = 0,
  });

  factory PlacementInfo.fromJson(Map<String, dynamic> j) => PlacementInfo(
    available: j['disponible'] as bool,
    published: j['exercices_publies'] as int,
    required: j['minimum_requis'] as int,
    explanation: j['explication'] as String,
    types: j['types_publies'] as int? ?? 0,
    typesRequired: j['types_requis'] as int? ?? 0,
  );

  final bool available;
  final int published;
  final int required;
  final String explanation;

  /// Nombre de types d'exercices publiés, et minimum attendu : un test bâti
  /// sur un seul type mesurerait une seule compétence.
  final int types;
  final int typesRequired;
}

/// Récapitulatif de fin de configuration.
///
/// Les lignes vides sont écartées : on ne présente pas une valeur par défaut
/// comme un choix de la personne.
class SetupSummary {
  const SetupSummary({required this.lines});

  factory SetupSummary.fromJson(Map<String, dynamic> j) {
    const motivations = {
      'DISCOVER_CULTURE': 'Découvrir ma culture',
      'FAMILY': 'Communiquer avec ma famille',
      'TRAVEL': 'Voyager au Cameroun',
      'PROFESSIONAL': 'Raisons professionnelles',
      'PERSONAL': 'Par intérêt personnel',
      'OTHER': 'Autre raison',
    };
    const notifications = {
      'reminders': 'rappels',
      'new_content': 'nouveaux contenus',
      'tips': 'conseils',
      'offers': 'offres',
    };

    final lines = <(String, String)>[];
    void add(String label, String value) {
      if (value.isNotEmpty) lines.add((label, value));
    }

    add('Nom', j['nom'] as String? ?? '');
    add(
      'Motivations',
      (j['motivations'] as List).map((m) => motivations[m] ?? '$m').join(', '),
    );
    add('Centres d’intérêt', (j['interets'] as List).join(', '));
    if (j['minutes'] != null) {
      add(
        'Objectif quotidien',
        '${j['minutes']} min · ${j['daily_goal_xp']} XP',
      );
    }
    final actives = (j['notifications_actives'] as List)
        .map((n) => notifications[n] ?? '$n')
        .join(', ');
    add('Notifications', actives.isEmpty ? 'aucune' : actives);
    if (j['test_de_positionnement'] == true) {
      add('Test de positionnement', 'accepté');
    }

    return SetupSummary(lines: lines);
  }

  final List<(String, String)> lines;
}

class SetupRepository {
  SetupRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> save(Map<String, dynamic> body) async =>
      await _api.put('/me/preferences', body) as Map<String, dynamic>;

  Future<PlacementInfo> placement() async => PlacementInfo.fromJson(
    await _api.get('/me/preferences/placement') as Map<String, dynamic>,
  );

  Future<SetupSummary> summary() async => SetupSummary.fromJson(
    await _api.get('/me/preferences/summary') as Map<String, dynamic>,
  );
}

final setupRepositoryProvider = Provider<SetupRepository>(
  (ref) => SetupRepository(ref.watch(apiClientProvider)),
);

final setupPlacementProvider = FutureProvider<PlacementInfo>(
  (ref) => ref.watch(setupRepositoryProvider).placement(),
);

final setupSummaryProvider = FutureProvider<SetupSummary>(
  (ref) => ref.watch(setupRepositoryProvider).summary(),
);

/// Les rubriques proposées à l'étape « centres d'intérêt » sont celles du
/// Culture Hub, avec leur nombre réel de fiches publiées.
final setupCategoriesProvider = FutureProvider<List<CultureCategory>>(
  (ref) => ref.watch(cultureRepositoryProvider).categories(),
);
