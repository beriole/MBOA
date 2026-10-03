import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_header.dart';
import '../data/culture_repository.dart';
import '../domain/models.dart';
import 'culture_widgets.dart';

/// Culture Hub (SS20) : les rubriques du patrimoine et les fiches publiées.
///
/// La page était une liste à plat : cinq tuiles de large empilées les unes
/// sous les autres, dont trois tassées dans une rangée si étroite qu'elles
/// devenaient illisibles sur un téléphone étroit, puis les filtres, puis les
/// fiches. On n'y voyait pas ce qui est l'entrée principale et ce qui est un
/// détour.
///
/// Elle s'organise désormais en trois temps : **découvrir** (le fil, mis en
/// avant parce que c'est là qu'on tombe sur ce qu'on ne cherchait pas),
/// **explorer** (les quatre autres destinations, en grille de deux colonnes),
/// puis **lire** (les fiches, avec leurs filtres).
///
/// Les rubriques vides restent visibles : un Culture Hub à moitié rempli mais
/// honnête vaut mieux qu'un Culture Hub rempli de généralités.
class CultureHubScreen extends ConsumerStatefulWidget {
  const CultureHubScreen({super.key});

  @override
  ConsumerState<CultureHubScreen> createState() => _CultureHubScreenState();
}

class _CultureHubScreenState extends ConsumerState<CultureHubScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(cultureCategoriesProvider);
    final contents = ref.watch(cultureContentsProvider(_category));

    return Scaffold(
      // Le fond porte la teinte de la section : sans elle, toutes les
      // pages se ressemblaient, uniformément blanches.
      backgroundColor: MboaSection.culture.fond,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cultureCategoriesProvider);
          ref.invalidate(cultureContentsProvider(_category));
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const MboaGradientHeader(
              section: MboaSection.culture,
              title: 'Culture',
              subtitle: 'Le patrimoine camerounais, sourcé et validé.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MboaSpace.lg,
                MboaSpace.xl,
                MboaSpace.lg,
                MboaSpace.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FeedSpotlight(),
                  const SizedBox(height: MboaSpace.xl),
                  const CultureSectionTitle(
                    title: 'Explorer',
                    subtitle: 'Quatre autres façons d’entrer dans le patrimoine',
                  ),
                  const SizedBox(height: MboaSpace.md),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: MboaSpace.md,
                    crossAxisSpacing: MboaSpace.md,
                    childAspectRatio: 1.05,
                    children: [
                      CultureEntryCard(
                        icon: Icons.photo_library_rounded,
                        tone: MboaTileTone.rose,
                        title: 'Médiathèque',
                        subtitle: 'Photos et vidéos libres',
                        onTap: () => context.push('/culture/mediatheque'),
                      ),
                      CultureEntryCard(
                        icon: Icons.map_outlined,
                        tone: MboaTileTone.vert,
                        title: 'Par région',
                        subtitle: 'Les dix régions du pays',
                        onTap: () => context.push('/culture/regions'),
                      ),
                      CultureEntryCard(
                        icon: Icons.quiz_outlined,
                        tone: MboaTileTone.ambre,
                        title: 'Quiz',
                        subtitle: 'Vérifie ce que tu as retenu',
                        onTap: () => context.push('/culture/quiz'),
                      ),
                      CultureEntryCard(
                        icon: Icons.favorite_border_rounded,
                        tone: MboaTileTone.indigo,
                        title: 'Favoris',
                        subtitle: 'Ce que tu as mis de côté',
                        onTap: () => context.push('/culture/favoris'),
                      ),
                    ],
                  ),
                  const SizedBox(height: MboaSpace.xxl),
                  CultureSectionTitle(
                    title: 'Les fiches',
                    subtitle: _category == null
                        ? 'Chaque fiche cite ses sources'
                        : 'Filtrées par rubrique',
                  ),
                  const SizedBox(height: MboaSpace.md),
                  categories.when(
                    loading: () => const SizedBox(
                      height: 44,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => _Message(text: '$e'),
                    data: (list) => _CategoryStrip(
                      categories: list,
                      selected: _category,
                      onSelected: (code) => setState(() => _category = code),
                    ),
                  ),
                  const SizedBox(height: MboaSpace.lg),
                  contents.when(
                    loading: () => const Column(
                      children: [
                        CultureCardSkeleton(),
                        SizedBox(height: MboaSpace.md),
                        CultureCardSkeleton(),
                      ],
                    ),
                    error: (e, _) => _Message(text: '$e'),
                    data: (items) => items.isEmpty
                        ? const _EmptyCategory()
                        : Column(
                            children: [
                              for (final item in items)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: MboaSpace.md,
                                  ),
                                  child: _ContentCard(item: item),
                                ),
                            ],
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

/// Le fil, mis en avant : c'est l'entrée par laquelle on découvre sans savoir
/// ce qu'on cherche. Les quatre autres destinations servent à revenir vers ce
/// qu'on a déjà repéré, et n'ont pas la même place dans la page.
class _FeedSpotlight extends StatelessWidget {
  const _FeedSpotlight();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/culture/fil'),
        borderRadius: BorderRadius.circular(MboaRadius.xl),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: MboaSection.culture.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(MboaRadius.xl),
            boxShadow: [
              BoxShadow(
                color: MboaSection.culture.debut.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(MboaSpace.lg),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(MboaRadius.md),
                  ),
                  child: const Icon(
                    Icons.dynamic_feed_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Le fil du patrimoine',
                        style: text.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fiches, enregistrements et commentaires, au fil des '
                        'validations.',
                        style: text.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MboaSpace.sm),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: MboaSection.culture.debut,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<CultureCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          CultureFilterPill(
            label: 'Toutes',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(left: MboaSpace.sm),
              child: CultureFilterPill(
                label: category.name,
                count: category.publishedCount,
                selected: selected == category.code,
                tone: toneForCategory(category.code),
                muted: category.isEmpty,
                onTap: () => onSelected(category.code),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item});

  final CultureSummary item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = toneForCategory(item.categoryName);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/culture/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: CultureMetaChip(
                      label: item.categoryName,
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
                    '${item.readingMinutes} min',
                    style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                  ),
                ],
              ),
              const SizedBox(height: MboaSpace.md),
              Text(item.title, style: text.titleLarge),
              const SizedBox(height: MboaSpace.xs),
              Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
              ),
              if (item.regionName != null || item.languageName != null) ...[
                const SizedBox(height: MboaSpace.md),
                const Divider(height: 1),
                const SizedBox(height: MboaSpace.md),
                Wrap(
                  spacing: MboaSpace.md,
                  runSpacing: MboaSpace.xs,
                  children: [
                    if (item.regionName != null)
                      CultureMetaChip(
                        label: item.regionName!,
                        icon: Icons.place_outlined,
                        background: Colors.transparent,
                        foreground: MboaColors.encre500,
                      ),
                    if (item.languageName != null)
                      CultureMetaChip(
                        label: item.languageName!,
                        icon: Icons.record_voice_over_outlined,
                        background: Colors.transparent,
                        foreground: MboaColors.encre500,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory();

  @override
  Widget build(BuildContext context) => const CultureEmptyState(
    icon: Icons.hourglass_empty_rounded,
    tone: MboaTileTone.orange,
    title: 'Rien à lire ici pour l’instant',
    text:
        'Cette rubrique attend des contributions. MBOA préfère une page vide '
        'à un contenu que personne n’a vérifié.',
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: MboaSpace.lg),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: MboaColors.erreur),
    ),
  );
}
