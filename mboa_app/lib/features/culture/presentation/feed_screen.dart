import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/audio_button.dart';
import '../../../design/widgets/mboa_header.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../../social/presentation/comments_section.dart';
import '../data/culture_repository.dart';
import '../domain/feed_models.dart';
import 'culture_widgets.dart';
import 'media_screens.dart' show FavoriteButton;

/// Le fil du patrimoine.
///
/// Les maquettes demandent un fil à la façon d'un réseau social. La forme est
/// reprise — cartes pleine largeur, média en tête, réactions dessous — parce
/// qu'elle se parcourt bien et qu'elle donne envie d'ouvrir.
///
/// Ce qui la remplit ne suit pas la même règle. Un fil social montre ce que
/// n'importe qui poste ; celui-ci ne montre que ce qui est passé par la
/// validation. Chaque carte porte donc ce qui l'établit : la source d'une
/// fiche, l'attribution d'un enregistrement.
///
/// Et quand il n'y a rien, le fil le dit. Le bandeau [_Gaps] annonce
/// l'absence de vidéo et de chant plutôt que de meubler avec une image
/// d'ambiance — un mot du vocabulaire présenté comme de la musique
/// traditionnelle serait faux, et personne ne pourrait plus démêler le vrai.
class CultureFeedScreen extends ConsumerWidget {
  const CultureFeedScreen({super.key, this.regionId});

  final String? regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(cultureFeedProvider(regionId));

    return Scaffold(
      // Le fond porte la teinte de la section : sans elle, toutes les
      // pages se ressemblaient, uniformément blanches.
      backgroundColor: MboaSection.culture.fond,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cultureFeedProvider(regionId)),
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(MboaSpace.xl),
                child: Text('$e'),
              ),
            ],
          ),
          data: (data) => ListView(
            padding: EdgeInsets.zero,
            children: [
              MboaGradientHeader(
                section: MboaSection.culture,
                title: 'Patrimoine',
                subtitle: 'Ce qui est documenté, et par qui.',
                leading: regionId == null ? null : const MboaHeaderBack(),
                child: _Counters(counts: data.counts),
              ),
              Padding(
                padding: const EdgeInsets.all(MboaSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RegionFilterBar(currentRegionId: regionId),
                    const SizedBox(height: MboaSpace.md),
                    _Notice(text: data.notice),
                    const SizedBox(height: MboaSpace.lg),
                    if (data.isEmpty)
                      const _EmptyFeed()
                    else ...[
                      const CultureSectionTitle(
                        title: 'Publications',
                        subtitle: 'Ce qui est passé par la validation',
                      ),
                      const SizedBox(height: MboaSpace.md),
                      for (final post in data.posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: MboaSpace.lg),
                          child: FeedCard(post: post),
                        ),
                    ],
                    const SizedBox(height: MboaSpace.md),
                    _Gaps(gaps: data.gaps),
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

class _Counters extends StatelessWidget {
  const _Counters({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MboaStat(
            value: '${counts['fiches'] ?? 0}',
            label: 'fiches',
            icon: Icons.article_outlined,
            onLight: true,
          ),
        ),
        const SizedBox(width: MboaSpace.sm),
        Expanded(
          child: MboaStat(
            value: '${counts['enregistrements'] ?? 0}',
            label: 'enregistrements',
            icon: Icons.graphic_eq_rounded,
            onLight: true,
          ),
        ),
        const SizedBox(width: MboaSpace.sm),
        Expanded(
          child: MboaStat(
            value: '${counts['videos'] ?? 0}',
            label: 'vidéos',
            icon: Icons.videocam_outlined,
            onLight: true,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(MboaSpace.md),
      decoration: BoxDecoration(
        color: MboaColors.forest100,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 18,
            color: MboaColors.forest700,
          ),
          const SizedBox(width: MboaSpace.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Une publication du fil.
class FeedCard extends ConsumerStatefulWidget {
  const FeedCard({super.key, required this.post});
  final FeedPost post;

  @override
  ConsumerState<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<FeedCard> {
  bool _showComments = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.image != null) _Illustration(media: post.image!),
          Padding(
            padding: const EdgeInsets.all(MboaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(post: post),
                const SizedBox(height: MboaSpace.md),
                Text(post.title, style: text.titleLarge),
                if (post.text != null) ...[
                  const SizedBox(height: MboaSpace.xs),
                  Text(
                    post.text!,
                    style: text.bodyMedium?.copyWith(
                      color: MboaColors.encre500,
                    ),
                  ),
                ] else if (post.isRecording) ...[
                  const SizedBox(height: MboaSpace.xs),
                  // La glose manque réellement. On le dit ; on ne la devine pas.
                  Text(
                    'Sens non renseigné',
                    style: text.bodySmall?.copyWith(
                      color: MboaColors.encre400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (post.audioUrl != null) ...[
                  const SizedBox(height: MboaSpace.md),
                  _Listen(post: post),
                ],
                const SizedBox(height: MboaSpace.md),
                _Attribution(post: post),
                const SizedBox(height: MboaSpace.sm),
                _Actions(
                  post: post,
                  showComments: _showComments,
                  onToggleComments: () =>
                      setState(() => _showComments = !_showComments),
                ),
                if (_showComments) ...[
                  const SizedBox(height: MboaSpace.lg),
                  CommentsSection(
                    targetType: post.targetType,
                    targetId: post.id,
                    title: 'Ce qu’en disent les gens',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post});
  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final recording = post.isRecording;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: recording
              ? MboaColors.forest100
              : MboaColors.indigo100,
          child: Icon(
            recording ? Icons.graphic_eq_rounded : Icons.menu_book_rounded,
            size: 18,
            color: recording ? MboaColors.forest700 : MboaColors.indigo700,
          ),
        ),
        const SizedBox(width: MboaSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.category ?? 'Patrimoine', style: text.labelLarge),
              Text(
                [
                  if (post.region != null) post.region!,
                  if (post.language != null) post.language!,
                  if (post.date != null) _date(post.date!),
                ].join(' · '),
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
            ],
          ),
        ),
        if (post.minutes != null)
          Text(
            '${post.minutes} min',
            style: text.bodySmall?.copyWith(color: MboaColors.encre400),
          ),
      ],
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.media});
  final FeedMedia media;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            media.url.startsWith('/') ? '$kApiBase${media.url}' : media.url,
            fit: BoxFit.cover,
            // Un fond neutre pendant le chargement : sans cela, la carte
            // clignote à chaque apparition d'une publication.
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const ColoredBox(color: MboaColors.sable100),
            errorBuilder: (context, error, stack) => const ColoredBox(
              color: MboaColors.sable100,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: MboaColors.encre400,
                ),
              ),
            ),
          ),
        ),
        // Le crédit et la licence voyagent avec l'image, jamais séparément :
        // c'est ce qui rend sa republication licite.
        if (media.credit != null || media.license != null)
          Container(
            width: double.infinity,
            color: MboaColors.sable100,
            padding: const EdgeInsets.symmetric(
              horizontal: MboaSpace.md,
              vertical: MboaSpace.xs,
            ),
            child: Text(
              [
                media.caption,
                media.credit,
                media.license,
              ].where((e) => e != null && e.isNotEmpty).join(' — '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ),
      ],
    );
  }
}

class _Listen extends StatelessWidget {
  const _Listen({required this.post});
  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.md),
      decoration: BoxDecoration(
        color: MboaColors.forest100,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Row(
        children: [
          AudioButton(url: post.audioUrl!),
          const SizedBox(width: MboaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title, style: text.titleMedium),
                if (post.speaker != null)
                  Text(
                    'Locuteur ${post.speaker}',
                    style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ce qui répond de la publication : sa source, ou l'attribution de la piste.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.post});
  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final source = post.source;
    if (source == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.link_rounded, size: 16, color: MboaColors.encre400),
        const SizedBox(width: MboaSpace.sm),
        Expanded(
          child: Text(
            source.citation,
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.post,
    required this.showComments,
    required this.onToggleComments,
  });

  final FeedPost post;
  final bool showComments;
  final VoidCallback onToggleComments;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Un Wrap et non un Row : à trois actions, un Row déborde déjà sur un
    // téléphone étroit, et il déborde franchement dès que le texte est grossi.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MboaSpace.xs),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MboaColors.contour)),
      ),
      child: Wrap(
        spacing: MboaSpace.sm,
        runSpacing: MboaSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FavoriteButton(type: post.targetType, id: post.id),
              if (post.favorites > 0)
                Text(
                  '${post.favorites}',
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
            ],
          ),
          TextButton.icon(
            onPressed: onToggleComments,
            icon: Icon(
              showComments
                  ? Icons.mode_comment_rounded
                  : Icons.mode_comment_outlined,
              size: 18,
            ),
            label: Text(post.comments == 0 ? 'Commenter' : '${post.comments}'),
          ),
          if (!post.isRecording)
            TextButton.icon(
              onPressed: () => context.push('/culture/${post.id}'),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('Lire'),
            ),
        ],
      ),
    );
  }
}

/// Ce qui manque, annoncé plutôt que comblé.
class _Gaps extends StatelessWidget {
  const _Gaps({required this.gaps});
  final List<FeedGap> gaps;

  @override
  Widget build(BuildContext context) {
    if (gaps.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MboaIconTile(
                icon: Icons.pending_outlined,
                tone: MboaTileTone.ambre,
                size: 36,
              ),
              const SizedBox(width: MboaSpace.md),
              Expanded(
                child: Text('Ce qui manque encore', style: text.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: MboaSpace.sm),
          for (final gap in gaps)
            Padding(
              padding: const EdgeInsets.only(bottom: MboaSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(gap.kind), size: 16, color: MboaColors.encre400),
                  const SizedBox(width: MboaSpace.sm),
                  Expanded(
                    child: Text(
                      gap.message,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _icon(String kind) => switch (kind) {
    'VIDEO' => Icons.videocam_off_outlined,
    'CHANT' => Icons.music_off_outlined,
    'IMAGE' => Icons.image_not_supported_outlined,
    _ => Icons.help_outline_rounded,
  };
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) => const CultureEmptyState(
    icon: Icons.explore_off_outlined,
    title: 'Rien de publié pour l’instant',
    text:
        'MBOA préfère un fil vide à un contenu que personne n’a vérifié. '
        'Les publications arrivent au fil des validations.',
  );
}

/// Barre horizontale de filtres par région pour le fil culturel.
class _RegionFilterBar extends StatelessWidget {
  const _RegionFilterBar({required this.currentRegionId});
  final String? currentRegionId;

  static const _regions = [
    (id: null, name: 'Toutes les régions', icon: Icons.map_outlined),
    (id: 'centre', name: 'Centre', icon: Icons.location_city_rounded),
    (id: 'littoral', name: 'Littoral', icon: Icons.sailing_rounded),
    (id: 'ouest', name: 'Ouest', icon: Icons.terrain_rounded),
    (id: 'nord', name: 'Nord', icon: Icons.wb_sunny_rounded),
    (id: 'sud', name: 'Sud', icon: Icons.forest_rounded),
    (id: 'adamaoua', name: 'Adamaoua', icon: Icons.landscape_rounded),
    (id: 'extreme-nord', name: 'Extrême-Nord', icon: Icons.wb_twilight_rounded),
    (id: 'est', name: 'Est', icon: Icons.park_rounded),
    (id: 'nord-ouest', name: 'Nord-Ouest', icon: Icons.nature_people_rounded),
    (id: 'sud-ouest', name: 'Sud-Ouest', icon: Icons.beach_access_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final r in _regions) ...[
            Builder(
              builder: (context) {
                final selected = currentRegionId == r.id;
                return Padding(
                  padding: const EdgeInsets.only(right: MboaSpace.xs),
                  child: FilterChip(
                    showCheckmark: false,
                    avatar: Icon(
                      r.icon,
                      size: 16,
                      color: selected ? Colors.white : MboaColors.forest700,
                    ),
                    selected: selected,
                    label: Text(r.name),
                    labelStyle: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : MboaColors.encre900,
                    ),
                    selectedColor: MboaColors.forest700,
                    backgroundColor: MboaColors.sable100,
                    side: BorderSide(
                      color: selected ? MboaColors.forest700 : MboaColors.contour,
                    ),
                    onSelected: (_) {
                      if (r.id == null) {
                        context.go('/culture/feed');
                      } else {
                        context.go('/culture/feed?region=${r.id}');
                      }
                    },
                  ),
                );
              }
            ),
          ],
        ],
      ),
    );
  }
}

