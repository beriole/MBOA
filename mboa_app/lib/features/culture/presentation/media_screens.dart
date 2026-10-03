import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/audio_button.dart';
import '../../../design/widgets/mboa_header.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../data/culture_repository.dart';
import '../domain/models.dart';
import 'culture_widgets.dart';

/// Médiathèque d'une région (lot 9, écrans 4 et 7).
///
/// Ce que l'écran doit rendre visible, et que la maquette ne montrait pas :
/// **les enregistrements ne sont pas « de la région »**. Ce sont ceux des
/// langues qu'une fiche publiée y documente. La phrase de provenance vient du
/// serveur et n'est pas réécrite ici.
class RegionMediaScreen extends ConsumerWidget {
  const RegionMediaScreen({super.key, required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(regionMediaProvider(regionId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: media.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(regionMediaProvider(regionId)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              MboaGradientHeader(
                section: MboaSection.culture,
                title: data.regionName,
                subtitle: 'Écouter la région',
                leading: const MboaHeaderBack(),
              ),
              Padding(
                padding: const EdgeInsets.all(MboaSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MboaNoteBox(
                      icon: Icons.info_outline_rounded,
                      tone: MboaTileTone.indigo,
                      text: data.provenance,
                    ),
                    if (data.languages.isNotEmpty) ...[
                      const SizedBox(height: MboaSpace.lg),
                      const CultureSectionTitle(
                        title: 'Les langues rattachées',
                        subtitle: 'Chaque rattachement est établi par une fiche',
                      ),
                      const SizedBox(height: MboaSpace.md),
                      for (final language in data.languages)
                        _LanguageOrigin(language: language),
                    ],
                    const SizedBox(height: MboaSpace.lg),
                    if (data.recordings.isEmpty)
                      MboaNoteBox(
                        icon: Icons.music_off_outlined,
                        tone: MboaTileTone.indigo,
                        title: 'Aucun enregistrement',
                        text:
                            'Les voix arriveront avec les fiches qui rattachent '
                            'une langue à cette région.',
                      )
                    else ...[
                      Text(
                        '${data.recordings.length} enregistrement'
                        '${data.recordings.length > 1 ? 's' : ''}',
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: MboaSpace.md),
                      for (final recording in data.recordings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: MboaSpace.md),
                          child: RecordingCard(recording: recording),
                        ),
                    ],
                    if (data.videoNotice != null) ...[
                      const SizedBox(height: MboaSpace.lg),
                      MboaNoteBox(
                        icon: Icons.videocam_off_outlined,
                        tone: MboaTileTone.ambre,
                        title: 'Pas de vidéo',
                        text: data.videoNotice!,
                      ),
                    ],
                    const SizedBox(height: MboaSpace.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La fiche qui établit le rattachement langue ↔ région.
class _LanguageOrigin extends StatelessWidget {
  const _LanguageOrigin({required this.language});
  final RegionLanguage language;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(MboaRadius.md),
        onTap: () => context.push('/culture/${language.contentId}'),
        child: Container(
          padding: const EdgeInsets.all(MboaSpace.md),
          decoration: BoxDecoration(
            color: MboaColors.forest100,
            borderRadius: BorderRadius.circular(MboaRadius.md),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.record_voice_over_outlined,
                size: 18,
                color: MboaColors.forest700,
              ),
              const SizedBox(width: MboaSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(language.name, style: text.titleMedium),
                    Text(
                      'établi par « ${language.contentTitle} »',
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MboaColors.encre400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une piste : le mot, son sens s'il est connu, l'écoute, l'attribution.
class RecordingCard extends ConsumerStatefulWidget {
  const RecordingCard({
    super.key,
    required this.recording,
    this.showFavorite = true,
  });

  final Recording recording;
  final bool showFavorite;

  @override
  ConsumerState<RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends ConsumerState<RecordingCard> {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final recording = widget.recording;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AudioButton(
                  url: '$kApiBase/api/v1/audio/${recording.id}',
                  size: 48,
                  semanticLabel: 'Écouter ${recording.lemma}',
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recording.lemma, style: text.titleLarge),
                      Text(
                        // Un mot peut être attesté et enregistré sans que
                        // personne ait encore écrit ce qu'il veut dire. On le
                        // dit dans des termes distincts d'une glose saisie qui
                        // resterait, elle, à confirmer.
                        recording.hasMeaning
                            ? recording.meaning!
                            : 'sens non renseigné',
                        style: text.bodyMedium?.copyWith(
                          color: recording.hasMeaning
                              ? MboaColors.encre500
                              : MboaColors.terre700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showFavorite)
                  FavoriteButton(type: 'AUDIO', id: recording.id),
              ],
            ),
            if (recording.attribution != null) ...[
              const SizedBox(height: MboaSpace.md),
              Text(
                recording.attribution!,
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bouton « mettre de côté », partagé par les fiches et les enregistrements.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.type,
    required this.id,
    this.onLight = false,
  });

  final String type;
  final String id;

  /// Posé sur le dégradé d'un en-tête plutôt que sur le fond clair : le cœur
  /// non sélectionné y serait sinon illisible.
  final bool onLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '$type/$id';
    final state = ref.watch(isFavoriteProvider(key));
    final idle = onLight ? Colors.white70 : MboaColors.encre500;
    return state.when(
      // Tant qu'on ne sait pas, on n'affiche pas un cœur vide qui laisserait
      // croire que le contenu n'est pas déjà en favori.
      loading: () =>
          const SizedBox(width: kMinTouchTarget, height: kMinTouchTarget),
      error: (e, _) => const SizedBox.shrink(),
      data: (isFavorite) => IconButton(
        tooltip: isFavorite ? 'Retirer de mes favoris' : 'Mettre de côté',
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? MboaColors.erreur : idle,
        ),
        onPressed: () async {
          try {
            await ref
                .read(cultureRepositoryProvider)
                .toggleFavorite(type, id, add: !isFavorite);
            ref.invalidate(isFavoriteProvider(key));
            ref.invalidate(favoritesProvider);
          } on ApiException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            }
          }
        },
      ),
    );
  }
}
/// Mes favoris (lot 9, écran 8).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(favoritesProvider),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              MboaGradientHeader(
                section: MboaSection.culture,
                title: 'Mes favoris',
                subtitle: data.isEmpty
                    ? 'Rien de mis de côté pour l’instant'
                    : '${data.total} élément${data.total > 1 ? 's' : ''} mis de côté',
                leading: const MboaHeaderBack(),
              ),
              Padding(
                padding: const EdgeInsets.all(MboaSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.isEmpty)
                      const CultureEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'Rien de mis de côté',
                        text:
                            'Le cœur, sur une fiche ou un enregistrement, la '
                            'range ici.',
                      )
                    else ...[
                      if (data.contents.isNotEmpty) ...[
                        const CultureSectionTitle(
                          title: 'Fiches',
                          subtitle: 'Ce que vous ouvrez depuis le patrimoine',
                        ),
                        const SizedBox(height: MboaSpace.md),
                        for (final content in data.contents)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: MboaSpace.md,
                            ),
                            child: _FavoriteContent(content: content),
                          ),
                        const SizedBox(height: MboaSpace.lg),
                      ],
                      if (data.recordings.isNotEmpty) ...[
                        const CultureSectionTitle(
                          title: 'Enregistrements',
                          subtitle: 'Les voix que vous gardez',
                        ),
                        const SizedBox(height: MboaSpace.md),
                        for (final recording in data.recordings)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: MboaSpace.md,
                            ),
                            child: RecordingCard(recording: recording),
                          ),
                      ],
                    ],
                    const SizedBox(height: MboaSpace.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteContent extends StatelessWidget {
  const _FavoriteContent({required this.content});

  final CultureSummary content;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/culture/${content.id}'),
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.categoryName,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      content.title,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              FavoriteButton(type: 'CULTURAL_CONTENT', id: content.id),
            ],
          ),
        ),
      ),
    );
  }
}
