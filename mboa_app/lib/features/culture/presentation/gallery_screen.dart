import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_header.dart';
import '../data/culture_repository.dart';
import '../domain/gallery_models.dart';
import 'culture_widgets.dart';
import 'video_view.dart';

const Map<String, ({String label, IconData icon, MboaTileTone tone})> kThemes =
    {
      'artisanat': (
        label: 'Artisanat',
        icon: Icons.handyman_rounded,
        tone: MboaTileTone.orange,
      ),
      'sculpture': (
        label: 'Sculpture',
        icon: Icons.architecture_rounded,
        tone: MboaTileTone.ambre,
      ),
      'danse': (
        label: 'Danse',
        icon: Icons.music_note_rounded,
        tone: MboaTileTone.rose,
      ),
      'musique': (
        label: 'Musique',
        icon: Icons.piano_rounded,
        tone: MboaTileTone.indigo,
      ),
      'marche': (
        label: 'Marchés',
        icon: Icons.storefront_rounded,
        tone: MboaTileTone.vert,
      ),
      'cuisine': (
        label: 'Cuisine',
        icon: Icons.restaurant_rounded,
        tone: MboaTileTone.orange,
      ),
      'paysage': (
        label: 'Paysages',
        icon: Icons.landscape_rounded,
        tone: MboaTileTone.bleu,
      ),
      'architecture': (
        label: 'Architecture',
        icon: Icons.home_work_rounded,
        tone: MboaTileTone.ambre,
      ),
    };

/// La médiathèque : ce qu'on peut voir du Cameroun, sous licence libre.
///
/// La page culture ne montrait que du texte blanc — rien n'y donnait envie
/// d'entrer. Elle s'ouvre maintenant sur des photographies et des vidéos
/// réelles, rapatriées de Wikimedia Commons avec leur auteur et leur licence.
///
/// Ce que cet écran ne fait pas : décrire ce qu'on voit. Le titre affiché est
/// celui que l'auteur a donné sur Commons ; MBOA n'ajoute aucune légende de son
/// cru, et n'attribue ce qu'on voit à aucun peuple ni à aucune tradition. Cette
/// retenue est le prix d'un catalogue dont on peut se fier au reste.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String? _theme;
  bool _videosOnly = false;

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(
      cultureGalleryProvider((
        theme: _theme,
        kind: _videosOnly ? 'VIDEO' : null,
      )),
    );
    final colonnes = MediaQuery.sizeOf(context).width >= 700 ? 3 : 2;

    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: gallery.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(MboaSpace.xl),
            child: Text('$e'),
          ),
        ),
        data: (data) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MboaGradientHeader(
                section: MboaSection.culture,
                title: 'Médiathèque',
                subtitle: '${data.total} médias, ${data.videos} vidéos',
                leading: const MboaHeaderBack(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MboaSpace.lg,
                  MboaSpace.lg,
                  MboaSpace.lg,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Notice(text: data.notice),
                    const SizedBox(height: MboaSpace.lg),
                    const CultureSectionTitle(
                      title: 'Parcourir',
                      subtitle: 'Chaque média porte son auteur et sa licence',
                    ),
                    const SizedBox(height: MboaSpace.md),
                    _ThemeStrip(
                      themes: data.themes,
                      selected: _theme,
                      onSelected: (code) => setState(() => _theme = code),
                    ),
                    const SizedBox(height: MboaSpace.lg),
                    // Deux filtres qui se répondent, et non deux puces
                    // côte à côte : le thème dit ce qu'on regarde, le second
                    // dit sous quelle forme.
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'TOUS',
                          label: Text('Tout'),
                          icon: Icon(Icons.grid_view_rounded, size: 18),
                        ),
                        ButtonSegment(
                          value: 'VIDEO',
                          label: Text('Vidéos'),
                          icon: Icon(Icons.videocam_rounded, size: 18),
                        ),
                      ],
                      selected: {_videosOnly ? 'VIDEO' : 'TOUS'},
                      onSelectionChanged: (selection) =>
                          setState(() => _videosOnly = selection.first == 'VIDEO'),
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: MboaSection.culture.accent
                            .withValues(alpha: 0.12),
                        selectedForegroundColor: MboaSection.culture.accent,
                        side: const BorderSide(color: MboaColors.contour),
                      ),
                    ),
                    const SizedBox(height: MboaSpace.lg),
                  ],
                ),
              ),
            ),
            if (data.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(MboaSpace.lg),
                  child: CultureEmptyState(
                    icon: Icons.photo_library_outlined,
                    title: _videosOnly
                        ? 'Aucune vidéo dans cette rubrique'
                        : 'Rien dans cette rubrique',
                    text:
                        'MBOA ne diffuse que des médias dont la provenance et '
                        'la licence sont établies. Aucune illustration de '
                        'remplissage.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: MboaSpace.lg),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: colonnes,
                    mainAxisSpacing: MboaSpace.md,
                    crossAxisSpacing: MboaSpace.md,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _MediaTile(
                      media: data.medias[index],
                      onTap: () => _open(data.medias[index]),
                    ),
                    childCount: data.medias.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: MboaSpace.xxxl)),
          ],
        ),
      ),
    );
  }

  void _open(GalleryMedia media) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MediaSheet(media: media),
  );
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.md),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.copyright_outlined,
            size: 18,
            color: MboaColors.encre500,
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

class _ThemeStrip extends StatelessWidget {
  const _ThemeStrip({
    required this.themes,
    required this.selected,
    required this.onSelected,
  });

  final List<GalleryTheme> themes;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: MboaSpace.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ThemeChip(
              label: 'Tout',
              icon: Icons.grid_view_rounded,
              tone: MboaTileTone.indigo,
              total: themes.fold(0, (a, t) => a + t.total),
              selected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final theme = themes[index - 1];
          final meta = kThemes[theme.code];
          return _ThemeChip(
            label: meta?.label ?? theme.code,
            icon: meta?.icon ?? Icons.photo_rounded,
            tone: meta?.tone ?? MboaTileTone.bleu,
            total: theme.total,
            videos: theme.videos,
            selected: selected == theme.code,
            onTap: () => onSelected(theme.code),
          );
        },
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.tone,
    required this.total,
    required this.selected,
    required this.onTap,
    this.videos = 0,
  });

  final String label;
  final IconData icon;
  final MboaTileTone tone;
  final int total;
  final int videos;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MboaRadius.md),
        child: AnimatedContainer(
          duration: MboaMotion.quick,
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: MboaSpace.sm),
          decoration: BoxDecoration(
            color: selected ? tone.background : Colors.white,
            borderRadius: BorderRadius.circular(MboaRadius.md),
            border: Border.all(
              color: selected ? tone.icon : MboaColors.contour,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tone.icon, size: 24),
              const SizedBox(height: MboaSpace.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                videos > 0 ? '$total · $videos ▶' : '$total',
                style: text.bodySmall?.copyWith(
                  fontSize: 11,
                  color: MboaColors.encre500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une vignette de la médiathèque.
///
/// Le crédit est **sur la vignette**, pas seulement dans la fiche : quelqu'un
/// qui parcourt la grille sans rien ouvrir doit déjà voir de qui vient l'image.
class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.media, required this.onTap});
  final GalleryMedia media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.isVideo)
                    const ColoredBox(
                      color: MboaColors.encre900,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                          size: 44,
                        ),
                      ),
                    )
                  else
                    Image.network(
                      resolveMedia(media.url),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const ColoredBox(
                              color: MboaColors.sable100,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                      errorBuilder: (context, error, stack) => const ColoredBox(
                        color: MboaColors.sable100,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: MboaColors.encre400,
                          ),
                        ),
                      ),
                    ),
                  if (media.isVideo)
                    Positioned(
                      top: MboaSpace.sm,
                      right: MboaSpace.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: MboaColors.encre900.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'vidéo',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MboaSpace.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    media.credit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontSize: 11,
                      color: MboaColors.encre500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Résout une adresse relative servie par l'API.
String resolveMedia(String url) => url.startsWith('/') ? '$kApiBase$url' : url;
