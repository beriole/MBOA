import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/culture/data/culture_repository.dart';
import 'package:mboa_app/features/culture/domain/models.dart';
import 'package:mboa_app/features/culture/presentation/media_screens.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CultureRepository {}

Map<String, dynamic> _mediaJson({
  int recordings = 2,
  bool withLanguage = true,
  int videos = 0,
}) => {
  'region': {'id': 'r1', 'code': 'LT', 'name': 'Littoral'},
  'langues': [
    if (withLanguage)
      {
        'id': 'l1',
        'name': 'Basaa',
        'iso639_3': 'bas',
        'fiche_id': 'f1',
        'fiche_titre': 'Où parle-t-on le basaa ?',
      },
  ],
  'enregistrements': [
    for (var i = 0; i < recordings; i++)
      {
        'id': 'a$i',
        'lemma': i == 0 ? 'màlep' : 'bìjɛk',
        'meaning_fr': i == 0 ? 'eau' : null,
        'language_name': 'Basaa',
        'attribution': 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
        'license': 'CC_BY_SA',
        'speaker_code': 'BAS-LL-01',
        'duration_ms': null,
      },
  ],
  'medias': const [],
  'compteurs': {'enregistrements': recordings, 'videos': videos, 'images': 0},
  'provenance': withLanguage
      ? 'Les enregistrements proposés sont ceux des langues qu’une fiche publiée '
            'documente dans cette région.'
      : 'Aucune fiche publiée ne rattache encore de langue à cette région.',
  'video': videos == 0
      ? 'Aucune vidéo au catalogue. MBOA n’en diffusera que sous licence établie ; '
            'aucune illustration de remplissage n’est affichée.'
      : null,
};

Map<String, dynamic> _favoritesJson({int contents = 1, int recordings = 1}) => {
  'fiches': [
    for (var i = 0; i < contents; i++)
      {
        'id': 'f$i',
        'title_fr': 'Le basaa se parle sur quatre tons',
        'summary_fr': 'Résumé',
        'category_name': 'Langue',
        'reading_minutes': 2,
      },
  ],
  'enregistrements': [
    for (var i = 0; i < recordings; i++)
      {
        'id': 'a$i',
        'lemma': 'màlep',
        'meaning_fr': 'eau',
        'language_name': 'Basaa',
        'attribution': 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
        'license': 'CC_BY_SA',
      },
  ],
  'total': contents + recordings,
};

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  CultureRepository repo,
) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [cultureRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('médiathèque de région', () {
    testWidgets('la provenance du rattachement est affichée', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.regionMedia(any()),
      ).thenAnswer((_) async => RegionMedia.fromJson(_mediaJson()));
      when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => false);

      await _pump(tester, const RegionMediaScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      // Les enregistrements ne sont pas « de la région » : une fiche l'établit.
      expect(find.textContaining('qu’une fiche publiée'), findsOneWidget);
      expect(find.text('Basaa'), findsOneWidget);
      expect(
        find.text('établi par « Où parle-t-on le basaa ? »'),
        findsOneWidget,
      );
    });

    testWidgets('chaque piste porte son attribution', (tester) async {
      final repo = _MockRepo();
      when(() => repo.regionMedia(any())).thenAnswer(
        (_) async => RegionMedia.fromJson(_mediaJson(recordings: 1)),
      );
      when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => false);

      await _pump(tester, const RegionMediaScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      expect(find.text('màlep'), findsOneWidget);
      // CC BY-SA exige le crédit : il est visible avec la piste.
      expect(
        find.text('Bile rene (Lingua Libre) — CC BY-SA 4.0'),
        findsOneWidget,
      );
    });

    testWidgets('un mot sans sens confirmé le dit', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.regionMedia(any()),
      ).thenAnswer((_) async => RegionMedia.fromJson(_mediaJson()));
      when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => false);

      await _pump(tester, const RegionMediaScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      // Le second enregistrement n'a pas de glose : on ne l'invente pas.
      expect(find.text('sens non renseigné'), findsOneWidget);
      expect(find.text('eau'), findsOneWidget);
    });

    testWidgets('l’absence de vidéo est expliquée', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.regionMedia(any()),
      ).thenAnswer((_) async => RegionMedia.fromJson(_mediaJson()));
      when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => false);

      await _pump(tester, const RegionMediaScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      expect(find.text('Pas de vidéo'), findsOneWidget);
      expect(find.textContaining('sous licence établie'), findsOneWidget);
    });

    testWidgets('une région sans langue rattachée n’invente rien', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(() => repo.regionMedia(any())).thenAnswer(
        (_) async => RegionMedia.fromJson(
          _mediaJson(recordings: 0, withLanguage: false),
        ),
      );

      await _pump(tester, const RegionMediaScreen(regionId: 'r1'), repo);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Aucune fiche publiée ne rattache'),
        findsOneWidget,
      );
      expect(find.text('Aucun enregistrement'), findsOneWidget);
    });
  });

  group('favoris', () {
    testWidgets('les fiches et les enregistrements sont séparés', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        repo.favorites,
      ).thenAnswer((_) async => Favorites.fromJson(_favoritesJson()));
      when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => true);

      await _pump(tester, const FavoritesScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Fiches'), findsOneWidget);
      expect(find.text('Enregistrements'), findsOneWidget);
      expect(find.text('Le basaa se parle sur quatre tons'), findsOneWidget);
      expect(find.text('màlep'), findsOneWidget);
    });

    testWidgets('sans favori, l’écran explique comment en ajouter', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.favorites).thenAnswer(
        (_) async =>
            Favorites.fromJson(_favoritesJson(contents: 0, recordings: 0)),
      );

      await _pump(tester, const FavoritesScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('Rien de mis de côté'), findsOneWidget);
      expect(find.textContaining('Le cœur, sur une fiche'), findsOneWidget);
    });

    testWidgets('le cœur bascule et appelle le serveur', (tester) async {
      final repo = _MockRepo();
      when(() => repo.isFavorite(any(), any())).thenAnswer((_) async => false);
      when(
        () => repo.toggleFavorite(any(), any(), add: any(named: 'add')),
      ).thenAnswer((_) async => true);

      await _pump(
        tester,
        const Scaffold(
          body: FavoriteButton(type: 'CULTURAL_CONTENT', id: 'f1'),
        ),
        repo,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      verify(
        () => repo.toggleFavorite('CULTURAL_CONTENT', 'f1', add: true),
      ).called(1);
    });

    testWidgets('l’état inconnu n’affiche pas un cœur vide trompeur', (
      tester,
    ) async {
      final repo = _MockRepo();
      // La réponse n'arrive jamais : on reste en chargement.
      when(
        () => repo.isFavorite(any(), any()),
      ).thenAnswer((_) => Completer<bool>().future);

      await _pump(
        tester,
        const Scaffold(
          body: FavoriteButton(type: 'AUDIO', id: 'a1'),
        ),
        repo,
      );
      await tester.pump();

      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });
  });

  group('modèles', () {
    test('un enregistrement sans glose se reconnaît', () {
      final media = RegionMedia.fromJson(_mediaJson());
      expect(media.recordings.first.hasMeaning, isTrue);
      expect(media.recordings.last.hasMeaning, isFalse);
    });

    test('les compteurs viennent du serveur', () {
      final media = RegionMedia.fromJson(_mediaJson(recordings: 3));
      expect(media.counts['enregistrements'], 3);
      expect(media.counts['videos'], 0);
      expect(media.videoNotice, isNotNull);
    });

    test('une liste de favoris vide se reconnaît', () {
      final vide = Favorites.fromJson(
        _favoritesJson(contents: 0, recordings: 0),
      );
      expect(vide.isEmpty, isTrue);
      expect(Favorites.fromJson(_favoritesJson()).total, 2);
    });
  });
}
