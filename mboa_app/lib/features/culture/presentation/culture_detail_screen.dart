import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_header.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../data/culture_repository.dart';
import '../domain/models.dart';
import 'culture_widgets.dart';
import 'media_screens.dart' show FavoriteButton;

/// Une fiche du patrimoine, avec ses sources en pied de page.
///
/// Les sources ne sont pas un détail technique : ce sont elles qui distinguent
/// une fiche MBOA d'une affirmation trouvée au hasard d'une recherche. Elles
/// sont donc traitées comme une partie de la fiche, pas comme un pied de page
/// technique.
///
/// L'écran suit la grammaire des autres pages de la section : en-tête dégradé
/// pour le patrimoine, contenu sur fond teinté. Le titre et la rubrique montent
/// dans le dégradé, le reste se lit sur le fond calme.
class CultureDetailScreen extends ConsumerWidget {
  const CultureDetailScreen({super.key, required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(cultureContentProvider(contentId));

    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (data) => _Content(data: data),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.data});

  final CultureContent data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tone = toneForCategory(data.categoryName);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cultureContentProvider(data.id)),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          MboaGradientHeader(
            section: MboaSection.culture,
            title: data.title,
            subtitle: data.categoryName,
            leading: const MboaHeaderBack(),
            actions: [
              FavoriteButton(
                type: 'CULTURAL_CONTENT',
                id: data.id,
                onLight: true,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(MboaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: MboaSpace.sm,
                  runSpacing: MboaSpace.sm,
                  children: [
                    if (data.regionName != null)
                      CultureMetaChip(
                        label: data.regionName!,
                        icon: Icons.place_outlined,
                        background: tone.background,
                        foreground: tone.icon,
                      ),
                    if (data.languageName != null)
                      CultureMetaChip(
                        label: data.languageName!,
                        icon: Icons.record_voice_over_outlined,
                      ),
                    CultureMetaChip(
                      label: '${data.readingMinutes} min de lecture',
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: MboaSpace.lg),
                // Le résumé à part : c'est ce qu'on lit avant de décider de
                // poursuivre, et il ne devrait pas se confondre avec le corps.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(MboaSpace.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(MboaRadius.lg),
                    border: Border(
                      left: BorderSide(color: tone.icon, width: 4),
                    ),
                    boxShadow: kMboaCardShadow,
                  ),
                  child: Text(
                    data.summary,
                    style: text.bodyLarge?.copyWith(
                      color: MboaColors.forest700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: MboaSpace.xl),
                for (final paragraph in data.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MboaSpace.lg),
                    child: Text(
                      paragraph,
                      style: text.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ),
                _Sources(sources: data.sources, validatedBy: data.validatedBy),
                if (data.related.isNotEmpty) ...[
                  const SizedBox(height: MboaSpace.xl),
                  const CultureSectionTitle(
                    title: 'À découvrir aussi',
                    subtitle: 'Des fiches du même patrimoine',
                  ),
                  const SizedBox(height: MboaSpace.md),
                  for (final related in data.related)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MboaSpace.sm),
                      child: _RelatedCard(related: related),
                    ),
                ],
                const SizedBox(height: MboaSpace.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.related});

  final CultureSummary related;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/culture/${related.id}'),
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      related.categoryName,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      related.title,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MboaSpace.sm),
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

class _Sources extends StatelessWidget {
  const _Sources({required this.sources, required this.validatedBy});

  final List<CultureSource> sources;
  final String? validatedBy;

  @override
  Widget build(BuildContext context) {
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
                icon: Icons.fact_check_outlined,
                tone: MboaTileTone.vert,
                size: 36,
              ),
              const SizedBox(width: MboaSpace.md),
              Expanded(
                child: Text(
                  'D’où viennent ces informations',
                  style: text.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: MboaSpace.md),
          if (sources.isEmpty)
            Text(
              'Aucune source enregistrée.',
              style: text.bodyMedium?.copyWith(color: MboaColors.erreur),
            )
          else
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: MboaSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.citation, style: text.bodyMedium),
                    if (source.locator != null)
                      Text(
                        source.locator!,
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                    if (source.license != null)
                      Text(
                        'Licence : ${source.license}',
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                  ],
                ),
              ),
          if (validatedBy != null) ...[
            const Divider(height: MboaSpace.xl),
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: MboaColors.forest700,
                ),
                const SizedBox(width: MboaSpace.sm),
                Expanded(
                  child: Text(
                    'Relu et validé par : $validatedBy',
                    style: text.bodySmall?.copyWith(
                      color: MboaColors.forest900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      MboaGradientHeader(
        section: MboaSection.culture,
        title: 'Patrimoine',
        leading: const MboaHeaderBack(),
      ),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MboaSpace.xl),
            child: CultureEmptyState(
              icon: Icons.cloud_off_rounded,
              tone: MboaTileTone.orange,
              title: 'Fiche indisponible',
              text: message,
              action: OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Revenir à la culture'),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
