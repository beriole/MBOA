import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/market_repository.dart';
import '../domain/models.dart';
import 'product_photo.dart';

/// Le bandeau de photos d'un objet, côté artisan.
///
/// C'est le seul endroit d'où viennent les images de la boutique. MBOA n'en
/// fournit aucune : sans photo déposée par le vendeur, la fiche reste sans
/// photo, et le catalogue le dit. Une image générique rendrait la grille plus
/// avenante et ferait croire à l'acheteur qu'il a vu l'objet — un objet
/// artisanal est unique.
///
/// Les octets sont lus en mémoire puis envoyés : sur le web, il n'y a pas de
/// chemin de fichier à passer, et le même code doit servir les deux plateformes.
class ProductPhotosEditor extends ConsumerStatefulWidget {
  const ProductPhotosEditor({super.key, required this.product});

  final Product product;

  /// Au-delà, personne ne regarde. Le serveur applique la même limite.
  static const maxImages = 6;

  @override
  ConsumerState<ProductPhotosEditor> createState() =>
      _ProductPhotosEditorState();
}

class _ProductPhotosEditorState extends ConsumerState<ProductPhotosEditor> {
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    final fichier = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // On réduit avant l'envoi : une photo de téléphone dépasse la limite du
      // serveur, et la pleine résolution n'apporte rien sur une vignette.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (fichier == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(marketRepositoryProvider)
          .uploadProductImage(
            widget.product.id,
            bytes: await fichier.readAsBytes(),
            filename: fichier.name,
          );
      ref.invalidate(shopProductsProvider);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ProductImage image) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(marketRepositoryProvider)
          .deleteProductImage(widget.product.id, image.id);
      ref.invalidate(shopProductsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.images;
    final text = Theme.of(context).textTheme;
    final complet = images.length >= ProductPhotosEditor.maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Photos', style: text.labelLarge),
            const SizedBox(width: MboaSpace.sm),
            Text(
              '${images.length}/${ProductPhotosEditor.maxImages}',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy || complet ? null : _add,
              icon: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        if (images.isEmpty)
          Text(
            'Sans photo, votre objet s’affiche avec un cadre vide. MBOA n’en '
            'ajoute aucune à votre place : une image d’illustration ne serait '
            'pas la vôtre.',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          )
        else
          SizedBox(
            // 96 et non 88 : la vignette fait 88, et la croix de retrait doit
            // tenir *dans* la liste. Posée en débord, elle était dessinée mais
            // ne recevait aucun toucher.
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: MboaSpace.sm),
              itemBuilder: (context, i) => _Thumb(
                image: images[i],
                title: widget.product.title,
                isCover: i == 0,
                onRemove: _busy ? null : () => _remove(images[i]),
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: MboaSpace.sm),
          Text(
            _error!,
            style: text.bodySmall?.copyWith(color: MboaColors.erreur),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.image,
    required this.title,
    required this.isCover,
    required this.onRemove,
  });

  final ProductImage image;
  final String title;
  final bool isCover;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MboaRadius.sm),
              child: SizedBox(
                width: 88,
                height: 88,
                child: ProductPhoto(url: image.url, title: title),
              ),
            ),
          ),
          if (isCover)
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: MboaColors.indigo600,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(MboaRadius.sm),
                    bottomLeft: Radius.circular(MboaRadius.sm),
                  ),
                ),
                child: const Text(
                  'Vignette',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Retirer cette photo',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: kMinTouchTarget,
                height: kMinTouchTarget,
              ),
              onPressed: onRemove,
              icon: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: MboaColors.erreur,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
