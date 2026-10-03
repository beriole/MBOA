import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_header.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../data/culture_repository.dart';
import '../domain/models.dart';
import 'culture_widgets.dart';

/// Exploration du patrimoine par région (lot 9, écrans 2 et 3).
///
/// Les dix régions sont toujours listées, y compris celles où rien n'est encore
/// documenté : cette liste est autant une carte du patrimoine qu'une carte du
/// travail qui reste à faire.
class RegionsScreen extends ConsumerWidget {
  const RegionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions = ref.watch(cultureRegionsProvider);

    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: regions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final documentees = list.where((r) => !r.isEmpty).length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cultureRegionsProvider),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                MboaGradientHeader(
                  section: MboaSection.culture,
                  title: 'Régions culturelles',
                  subtitle: '${list.length} régions, $documentees documentée'
                      '${documentees > 1 ? 's' : ''}',
                  leading: const MboaHeaderBack(),
                ),
                Padding(
                  padding: const EdgeInsets.all(MboaSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CultureSectionTitle(
                        title: 'La carte du patrimoine',
                        subtitle: 'Une région vide est une région qui attend '
                            'des contributeurs',
                      ),
                      const SizedBox(height: MboaSpace.md),
                      for (final region in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: MboaSpace.md),
                          child: _RegionCard(region: region),
                        ),
                      const SizedBox(height: MboaSpace.xxl),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final CultureRegion region;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = region.isEmpty ? MboaTileTone.indigo : MboaTileTone.vert;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/culture/region/${region.id}'),
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Row(
            children: [
              MboaIconTile(icon: Icons.place_outlined, tone: tone),
              const SizedBox(width: MboaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(region.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      region.isEmpty
                          ? 'Rien de publié pour l’instant'
                          : '${region.fiches} fiche${region.fiches > 1 ? 's' : ''}'
                                '${region.langues > 0 ? ' · ${region.langues} langue${region.langues > 1 ? 's' : ''}' : ''}',
                      style: text.bodySmall?.copyWith(
                        color: region.isEmpty
                            ? MboaColors.encre400
                            : MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MboaSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: region.isEmpty
                      ? MboaColors.sable100
                      : tone.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${region.fiches}',
                  style: text.titleMedium?.copyWith(
                    color: region.isEmpty
                        ? MboaColors.encre400
                        : tone.icon,
                  ),
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

/// Détail d'une région : ses chiffres, ses rubriques et ses fiches.
class RegionDetailScreen extends ConsumerWidget {
  const RegionDetailScreen({super.key, required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(cultureRegionProvider(regionId));

    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => ListView(
          padding: EdgeInsets.zero,
          children: [
            MboaGradientHeader(
              section: MboaSection.culture,
              title: data.region.name,
              subtitle: 'Région du Cameroun',
              leading: const MboaHeaderBack(),
              child: Row(
                children: [
                  Expanded(
                    child: MboaStat(
                      value: '${data.counts['fiches'] ?? 0}',
                      label: 'fiches publiées',
                      icon: Icons.article_outlined,
                      onLight: true,
                    ),
                  ),
                  const SizedBox(width: MboaSpace.sm),
                  Expanded(
                    child: MboaStat(
                      value: '${data.counts['langues'] ?? 0}',
                      label: 'langues',
                      icon: Icons.record_voice_over_outlined,
                      onLight: true,
                    ),
                  ),
                  const SizedBox(width: MboaSpace.sm),
                  Expanded(
                    child: MboaStat(
                      value:
                          '${data.mediaCount('AUDIO') + data.mediaCount('VIDEO')}',
                      label: 'médias',
                      icon: Icons.play_circle_outline_rounded,
                      onLight: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MboaSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/culture/region/$regionId/media'),
                    icon: const Icon(Icons.headphones_rounded, size: 20),
                    label: const Text('Écouter la région'),
                  ),
                  const SizedBox(height: MboaSpace.xl),
                  if (data.topics.isNotEmpty) ...[
                    const CultureSectionTitle(
                      title: 'Rubriques',
                      subtitle: 'Ce qui est documenté ici',
                    ),
                    const SizedBox(height: MboaSpace.md),
                    Wrap(
                      spacing: MboaSpace.sm,
                      runSpacing: MboaSpace.sm,
                      children: [
                        for (final topic in data.topics)
                          CultureMetaChip(
                            label: '${topic.name} · ${topic.fiches}',
                            background: Colors.white,
                            foreground: MboaColors.encre900,
                          ),
                      ],
                    ),
                    const SizedBox(height: MboaSpace.xl),
                  ],
                  CultureSectionTitle(
                    title: 'Les fiches',
                    subtitle: data.contents.isEmpty
                        ? 'Rien de publié dans cette région'
                        : '${data.contents.length} fiche'
                              '${data.contents.length > 1 ? 's' : ''} à lire',
                  ),
                  const SizedBox(height: MboaSpace.md),
                  if (data.contents.isEmpty)
                    _EmptyRegion(name: data.region.name)
                  else
                    for (final fiche in data.contents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: MboaSpace.md),
                        child: _FicheCard(fiche: fiche),
                      ),
                  const SizedBox(height: MboaSpace.lg),
                  _MediaNotice(media: data.media),
                  const SizedBox(height: MboaSpace.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _FicheCard extends StatelessWidget {
  const _FicheCard({required this.fiche});

  final CultureSummary fiche;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = toneForCategory(fiche.categoryName);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/culture/${fiche.id}'),
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: CultureMetaChip(
                      label: fiche.categoryName,
                      background: tone.background,
                      foreground: tone.icon,
                    ),
                  ),
                  const SizedBox(width: MboaSpace.sm),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: MboaColors.encre400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${fiche.readingMinutes} min',
                    style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                  ),
                ],
              ),
              const SizedBox(height: MboaSpace.md),
              Text(fiche.title, style: text.titleLarge),
              const SizedBox(height: MboaSpace.xs),
              Text(
                fiche.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les maquettes prévoient vidéos, audios et galerie par région.
///
/// On affiche ce qui existe. Un onglet « Vidéos » vide serait plus honnête
/// qu'une vidéo d'illustration sans provenance — et la phrase le dit.
class _MediaNotice extends StatelessWidget {
  const _MediaNotice({required this.media});
  final Map<String, int> media;

  @override
  Widget build(BuildContext context) {
    final total = media.values.fold(0, (sum, v) => sum + v);
    if (total > 0) {
      return MboaNoteBox(
        icon: Icons.perm_media_outlined,
        tone: MboaTileTone.bleu,
        title: 'Médias de la région',
        text: media.entries
            .map((e) => '${e.value} ${e.key.toLowerCase()}')
            .join(' · '),
      );
    }
    return const MboaNoteBox(
      icon: Icons.videocam_off_outlined,
      tone: MboaTileTone.indigo,
      title: 'Ni vidéo ni enregistrement pour l’instant',
      text:
          'MBOA ne diffusera que des médias dont la provenance et la licence '
          'sont établies. Aucune illustration de remplissage.',
    );
  }
}
class _EmptyRegion extends StatelessWidget {
  const _EmptyRegion({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => CultureEmptyState(
    icon: Icons.explore_off_outlined,
    title: 'Rien de publié sur $name',
    text:
        'Cette région attend des contributeurs. MBOA préfère une page vide '
        'à un contenu que personne n’a vérifié.',
    action: OutlinedButton.icon(
      onPressed: () => context.push('/become-specialist'),
      icon: const Icon(Icons.edit_note_rounded, size: 20),
      label: const Text('Proposer une fiche'),
    ),
  );
}
