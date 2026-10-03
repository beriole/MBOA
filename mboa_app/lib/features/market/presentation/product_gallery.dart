import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../domain/models.dart';
import 'product_photo.dart';

/// La galerie de photos d'un objet.
///
/// Une seule vue suffit rarement pour un objet artisanal : on veut voir le
/// dessous d'un panier, le revers d'un tissu. Les photos défilent, et le point
/// courant est marqué.
///
/// Quand il n'y en a aucune, [ProductPhoto] affiche le cadre qui le dit. C'est
/// volontaire : une image d'illustration rendrait la fiche plus attirante et
/// ferait croire à l'acheteur qu'il a vu l'objet.
class ProductGallery extends StatefulWidget {
  const ProductGallery({super.key, required this.product});
  final Product product;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.images;

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ProductPhoto(
            url: widget.product.coverUrl,
            title: widget.product.title,
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(MboaRadius.lg),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: images.length,
              itemBuilder: (context, i) => ProductPhoto(
                url: images[i].url,
                title: widget.product.title,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: MboaSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index
                        ? MboaColors.indigo600
                        : MboaColors.contour,
                  ),
                ),
            ],
          ),
        ],
        if (images[_index].caption != null) ...[
          const SizedBox(height: MboaSpace.xs),
          Text(
            images[_index].caption!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
        ],
      ],
    );
  }
}
