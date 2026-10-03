import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/market_repository.dart';
import '../domain/models.dart';
import '../../social/presentation/comments_section.dart';
import 'claim_badge.dart';
import 'market_screen.dart' show kCategoryLabels, DemoTag;
import 'payment_choice.dart';
import 'product_gallery.dart';

/// Fiche d'un objet, et commande (SS45, SS47).
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(productDetailProvider(productId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Objet')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final product = data.product;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(
                  MboaSpace.lg,
                  MboaSpace.lg,
                  MboaSpace.lg,
                  100, // Space for sticky bottom bar
                ),
                children: [
                  ProductGallery(product: product),
                  const SizedBox(height: MboaSpace.lg),
                  Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.category_outlined, size: 16),
                        label: Text(
                          kCategoryLabels[product.category] ?? product.category,
                        ),
                      ),
                      const Spacer(),
                      if (product.rating != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: MboaColors.or,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.rating!.toStringAsFixed(1)} (${product.reviews} avis)',
                          style: text.titleMedium,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MboaSpace.sm),
                  Text(product.title, style: text.headlineMedium),
                  const SizedBox(height: MboaSpace.md),
                  // Artisan Shop Card
                  Container(
                    padding: const EdgeInsets.all(MboaSpace.md),
                    decoration: BoxDecoration(
                      color: MboaColors.sable100,
                      borderRadius: BorderRadius.circular(MboaRadius.md),
                      border: Border.all(color: MboaColors.contour),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: MboaColors.terre100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: MboaColors.terre700,
                          ),
                        ),
                        const SizedBox(width: MboaSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.shopName, style: text.titleMedium),
                              Text(
                                [
                                  if (product.shopCity != null)
                                    product.shopCity!,
                                  if (product.regionName != null)
                                    product.regionName!,
                                ].join(' · '),
                                style: text.bodySmall?.copyWith(
                                  color: MboaColors.encre500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (product.shopIsDemo) const DemoTag(),
                      ],
                    ),
                  ),
                  const SizedBox(height: MboaSpace.lg),
                  if (product.description != null) ...[
                    Text('Description', style: text.titleLarge),
                    const SizedBox(height: MboaSpace.xs),
                    Text(product.description!, style: text.bodyLarge),
                  ],
                  if (product.culturalClaim != null) ...[
                    const SizedBox(height: MboaSpace.xl),
                    Text(
                      'Ce que le vendeur dit de cet objet',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: MboaSpace.sm),
                    Text(product.culturalClaim!, style: text.bodyLarge),
                    const SizedBox(height: MboaSpace.md),
                    ClaimBadge(claim: product.claim, expanded: true),
                    if (data.source != null) ...[
                      const SizedBox(height: MboaSpace.md),
                      _SourceLink(source: data.source!),
                    ],
                  ],
                  const SizedBox(height: MboaSpace.xl),
                  PaymentNotice(notice: data.notice),
                  const SizedBox(height: MboaSpace.xxl),
                  const Divider(),
                  const SizedBox(height: MboaSpace.lg),
                  CommentsSection(
                    targetType: 'PRODUCT',
                    targetId: product.id,
                    title: 'Avis des acheteurs',
                  ),
                ],
              ),
              // Sticky bottom order bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(MboaSpace.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prix total',
                            style: text.bodySmall?.copyWith(
                              color: MboaColors.encre500,
                            ),
                          ),
                          Text(
                            formatXaf(product.priceXaf),
                            style: text.headlineMedium?.copyWith(
                              color: MboaColors.terre700,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: MboaSpace.lg),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: product.stock > 0
                                ? MboaColors.terre700
                                : MboaColors.sable600,
                          ),
                          onPressed: product.stock > 0
                              ? () => _openOrderSheet(context, ref, product)
                              : null,
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            product.stock > 0 ? 'Commander' : 'Épuisé',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openOrderSheet(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final reference = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OrderSheet(product: product),
    );
    if (reference == null || !context.mounted) return;

    ref.invalidate(productDetailProvider(product.id));
    ref.invalidate(myOrdersProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Commande $reference envoyée à ${product.shopName}.'),
      ),
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.source});
  final ProductSource source;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push('/culture/${source.id}'),
      borderRadius: BorderRadius.circular(MboaRadius.md),
      child: Container(
        padding: const EdgeInsets.all(MboaSpace.md),
        decoration: BoxDecoration(
          color: MboaColors.forest100,
          borderRadius: BorderRadius.circular(MboaRadius.md),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 18,
              color: MboaColors.forest700,
            ),
            const SizedBox(width: MboaSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.title, style: text.titleSmall),
                  if (source.sourceTitle != null)
                    Text(
                      'Source : ${source.sourceTitle}',
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Formulaire de commande. Les informations demandées sont celles dont le
/// livreur a besoin, pas une de plus.
class _OrderSheet extends ConsumerStatefulWidget {
  const _OrderSheet({required this.product});
  final Product product;

  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  int _quantity = 1;
  bool _sending = false;
  String? _error;

  /// Le règlement choisi. Les deux options ouvertes ne font transiter aucun
  /// argent par MBOA : l'une se remet au livreur, l'autre ne déplace rien.
  String _mode = 'CASH_ON_DELIVERY';

  @override
  void dispose() {
    _city.dispose();
    _address.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _city.text.trim().length >= 2 &&
      _address.text.trim().length >= 5 &&
      _phone.text.trim().length >= 6;

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final reference = await ref
          .read(marketRepositoryProvider)
          .order(
            productId: widget.product.id,
            quantity: _quantity,
            city: _city.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            note: _note.text.trim(),
            paymentMode: _mode,
          );
      if (mounted) Navigator.of(context).pop(reference);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = widget.product.priceXaf * _quantity;

    return Padding(
      padding: EdgeInsets.only(
        left: MboaSpace.lg,
        right: MboaSpace.lg,
        top: MboaSpace.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + MboaSpace.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Commander', style: text.titleLarge),
            const SizedBox(height: MboaSpace.md),
            Row(
              children: [
                Expanded(child: Text('Quantité', style: text.bodyLarge)),
                IconButton(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_quantity', style: text.titleMedium),
                IconButton(
                  onPressed: _quantity < widget.product.stock
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: _city,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Ville de livraison',
              ),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: _address,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                helperText: 'Quartier, repère : c’est ce que lira le livreur.',
              ),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: _phone,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Précision (facultatif)',
              ),
            ),
            const SizedBox(height: MboaSpace.lg),
            Row(
              children: [
                Expanded(
                  child: Text('Total à régler', style: text.titleMedium),
                ),
                Text(formatXaf(total), style: text.titleLarge),
              ],
            ),
            const SizedBox(height: MboaSpace.lg),
            Text('Règlement', style: text.titleMedium),
            const SizedBox(height: MboaSpace.sm),
            PaymentChoice(
              value: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            if (_error != null) ...[
              const SizedBox(height: MboaSpace.md),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: MboaColors.erreur),
              ),
            ],
            const SizedBox(height: MboaSpace.lg),
            FilledButton(
              onPressed: _isValid && !_sending ? _submit : null,
              child: Text(_sending ? 'Envoi…' : 'Envoyer la commande'),
            ),
          ],
        ),
      ),
    );
  }
}
