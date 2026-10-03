import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/tokens.dart';
import '../culture/data/culture_repository.dart';
import '../culture/domain/gallery_models.dart';
import '../culture/presentation/gallery_screen.dart' show resolveMedia;
import '../market/data/market_repository.dart';
import '../market/domain/models.dart';
import '../market/presentation/market_screen.dart' show DemoTag;
import '../market/presentation/product_photo.dart';

/// Les deux aperçus posés au bas de l'accueil.
///
/// L'accueil s'arrêtait après les cartes de reprise : on arrivait au bout en
/// deux gestes, et rien n'invitait à aller voir le reste de l'application. Ces
/// deux bandeaux montrent ce qui existe ailleurs — le patrimoine et la boutique
/// — sans rien inventer pour remplir.
///
/// Chacun se tait quand il n'a rien à montrer. Un bandeau vide serait pire
/// qu'un bandeau absent : il promettrait du contenu qui n'est pas là.

/// Un titre de section, avec son lien « tout voir ».
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onSeeAll, child: const Text('Tout voir')),
      ],
    );
  }
}

/// Un aperçu de la médiathèque.
///
/// Les vignettes portent leur crédit : quelqu'un qui ne fait que passer doit
/// déjà voir de qui vient l'image. C'est ce que la licence exige, et ce n'est
/// pas négociable selon l'écran où l'image apparaît.
class HeritageCarousel extends ConsumerWidget {
  const HeritageCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(
      cultureGalleryProvider((theme: null, kind: 'IMAGE')),
    );

    return gallery.maybeWhen(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final apercu = data.medias.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionTitle(
              title: 'Le patrimoine en images',
              subtitle:
                  '${data.total} médias sous licence libre, auteurs crédités',
              onSeeAll: () => context.push('/culture/mediatheque'),
            ),
            const SizedBox(height: MboaSpace.md),
            SizedBox(
              height: 186,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: apercu.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: MboaSpace.md),
                itemBuilder: (context, i) => _HeritageCard(media: apercu[i]),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _HeritageCard extends StatelessWidget {
  const _HeritageCard({required this.media});
  final GalleryMedia media;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 150,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push('/culture/mediatheque'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Image.network(
                  resolveMedia(media.url),
                  fit: BoxFit.cover,
                  width: double.infinity,
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
              ),
              Padding(
                padding: const EdgeInsets.all(MboaSpace.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
      ),
    );
  }
}

/// Un aperçu de la boutique.
class MarketCarousel extends ConsumerWidget {
  const MarketCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(marketProductsProvider(const CatalogQuery()));

    return page.maybeWhen(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final apercu = data.items.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionTitle(
              title: 'Des objets de nos artisans',
              subtitle: '${data.bounds.total} objets, vendus par leurs auteurs',
              onSeeAll: () => context.go('/shop'),
            ),
            const SizedBox(height: MboaSpace.md),
            SizedBox(
              height: 206,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: apercu.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: MboaSpace.md),
                itemBuilder: (context, i) => _ProductCard(product: apercu[i]),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 150,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push('/shop/${product.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductPhoto(url: product.coverUrl, title: product.title),
                    if (product.shopIsDemo)
                      const Positioned(
                        top: MboaSpace.xs,
                        left: MboaSpace.xs,
                        child: DemoTag(),
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
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatXaf(product.priceXaf),
                      style: text.bodyMedium?.copyWith(
                        color: MboaColors.terre700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
