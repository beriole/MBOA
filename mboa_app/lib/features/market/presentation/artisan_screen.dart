import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../data/market_repository.dart';
import '../domain/models.dart';
import 'claim_badge.dart';
import 'market_screen.dart' show kCategoryLabels;
import 'product_photos_editor.dart';

/// Espace artisan (SS46) : la boutique, les objets, les commandes reçues.
class ArtisanScreen extends ConsumerStatefulWidget {
  const ArtisanScreen({super.key});

  @override
  ConsumerState<ArtisanScreen> createState() => _ArtisanScreenState();
}

class _ArtisanScreenState extends ConsumerState<ArtisanScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopProvider);
    final productsAsync = ref.watch(shopProductsProvider);
    final ordersAsync = ref.watch(shopOrdersProvider);

    final publishedCount =
        shopAsync.value?.counts['produits_publies'] ??
        productsAsync.value?.length ??
        0;
    final pendingOrdersCount =
        shopAsync.value?.counts['commandes_a_traiter'] ??
        ordersAsync.value
            ?.where(
              (o) =>
                  o.status == 'PENDING_CONFIRMATION' ||
                  o.status == 'CONFIRMED' ||
                  o.status == 'PREPARING',
            )
            .length ??
        0;

    return Scaffold(
      backgroundColor: MboaSection.boutique.fond,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            _ShopTab(),
            _ProductsTab(),
            _OrdersTab(),
            _ArtisanGuideTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: MboaColors.encre900.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          indicatorColor: MboaColors.sable100,
          elevation: 0,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(
                Icons.storefront_rounded,
                color: MboaColors.terre700,
              ),
              label: 'Boutique',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: publishedCount > 0,
                label: Text('$publishedCount'),
                child: const Icon(Icons.inventory_2_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: publishedCount > 0,
                label: Text('$publishedCount'),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: MboaColors.terre700,
                ),
              ),
              label: 'Mes Objets',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: pendingOrdersCount > 0,
                label: Text('$pendingOrdersCount'),
                child: const Icon(Icons.receipt_long_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: pendingOrdersCount > 0,
                label: Text('$pendingOrdersCount'),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: MboaColors.terre700,
                ),
              ),
              label: 'Commandes',
            ),
            const NavigationDestination(
              icon: Icon(Icons.lightbulb_outline_rounded),
              selectedIcon: Icon(
                Icons.lightbulb_rounded,
                color: MboaColors.terre700,
              ),
              label: 'Conseils',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 0 : Boutique
// ---------------------------------------------------------------------------
class _ShopTab extends ConsumerStatefulWidget {
  const _ShopTab();

  @override
  ConsumerState<_ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends ConsumerState<_ShopTab> {
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(shopProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _edit(Shop shop) async {
    final name = TextEditingController(text: shop.name);
    final description = TextEditingController(text: shop.description ?? '');
    final city = TextEditingController(text: shop.city ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: MboaSpace.lg,
          right: MboaSpace.lg,
          top: MboaSpace.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + MboaSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modifier ma boutique',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nom de la boutique',
              ),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description / Atelier',
                helperText:
                    'Présentez votre savoir-faire artisanal aux acheteurs.',
              ),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: city,
              decoration: const InputDecoration(
                labelText: 'Ville de l’atelier (ex: Douala, Foumban)',
              ),
            ),
            const SizedBox(height: MboaSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MboaColors.terre700,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Enregistrer les modifications',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    await _run(
      () => ref
          .read(marketRepositoryProvider)
          .editShop(
            name: name.text.trim(),
            description: description.text.trim(),
            city: city.text.trim(),
          ),
    );
  }

  void _previewShopAsBuyer(Shop shop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.remove_red_eye_rounded,
              color: MboaColors.terre700,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Aperçu : ${shop.name}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voici comment votre boutique apparaît aux acheteurs sur la place de marché MBOA :',
              style: TextStyle(color: MboaColors.encre500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MboaColors.sable100,
                borderRadius: BorderRadius.circular(MboaRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (shop.city != null)
                    Text(
                      '📍 Atelier à ${shop.city}',
                      style: const TextStyle(color: MboaColors.terre700),
                    ),
                  if (shop.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      shop.description!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: MboaColors.terre700),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Lien de la boutique copié dans le presse-papier !',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('Partager ma boutique'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(shopProvider);
    final text = Theme.of(context).textTheme;

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.xl),
          child: Text('$e'),
        ),
      ),
      data: (data) {
        final shop = data.shop;
        final ordersList = ref.watch(shopOrdersProvider).value ?? [];
        final totalRevenue = ordersList
            .where(
              (o) =>
                  o.status == 'DELIVERED' ||
                  o.status == 'IN_DELIVERY' ||
                  o.status == 'READY_FOR_PICKUP',
            )
            .fold<int>(0, (sum, o) => sum + o.totalXaf);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(shopProvider);
            ref.invalidate(shopOrdersProvider);
            ref.invalidate(shopProductsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(MboaSpace.lg),
            children: [
              // Hero Studio Banner
              Container(
                padding: const EdgeInsets.all(MboaSpace.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MboaSection.boutique.debut,
                      MboaSection.boutique.fin,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(MboaRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: MboaSection.boutique.debut.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(MboaSpace.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.brush_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: MboaSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop.name,
                                style: text.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (shop.city != null)
                                Text(
                                  'Atelier · ${shop.city}',
                                  style: text.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: shop.isOpen ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: shop.isOpen
                                      ? Colors.green
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                shop.isOpen ? 'OUVERTE' : 'FERMÉE',
                                style: text.labelSmall?.copyWith(
                                  color: shop.isOpen
                                      ? MboaColors.terre700
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (shop.description != null &&
                        shop.description!.isNotEmpty) ...[
                      const SizedBox(height: MboaSpace.md),
                      Text(
                        shop.description!,
                        style: text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: MboaSpace.lg),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: MboaSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                            onPressed: () => _edit(shop),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Modifier'),
                          ),
                        ),
                        const SizedBox(width: MboaSpace.sm),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: MboaColors.terre700,
                            ),
                            onPressed: () => _previewShopAsBuyer(shop),
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Aperçu Client',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MboaSpace.xl),

              // Open / Close Shop Toggle Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MboaSpace.lg,
                  vertical: MboaSpace.md,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(MboaRadius.md),
                  border: Border.all(color: MboaColors.contour),
                ),
                child: Row(
                  children: [
                    Icon(
                      shop.isOpen
                          ? Icons.storefront_rounded
                          : Icons.store_outlined,
                      color: shop.isOpen
                          ? MboaColors.forest700
                          : MboaColors.terre700,
                    ),
                    const SizedBox(width: MboaSpace.md),
                    Expanded(
                      child: Text(
                        shop.isOpen
                            ? 'Votre boutique est visible sur la place de marché'
                            : 'Boutique fermée : vos objets ne sont pas visibles',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: shop.isOpen,
                      activeTrackColor: MboaColors.terre700,
                      onChanged: (_) {
                        if (shop.isOpen) {
                          _run(ref.read(marketRepositoryProvider).closeShop);
                        } else {
                          _run(ref.read(marketRepositoryProvider).openShop);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MboaSpace.xl),

              Text(
                'Tableau de Bord Ventes & Objets',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: MboaSpace.md),

              // Sales Analytics Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: MboaSpace.md,
                mainAxisSpacing: MboaSpace.md,
                childAspectRatio: 1.4,
                children: [
                  _ArtisanStatCard(
                    value: '${data.counts['produits_publies'] ?? 0}',
                    label: 'En vente',
                    icon: Icons.shopping_bag_outlined,
                    color: MboaColors.forest700,
                    backgroundColor: MboaColors.forest100,
                  ),
                  _ArtisanStatCard(
                    value: '${data.counts['commandes_a_traiter'] ?? 0}',
                    label: 'À traiter',
                    icon: Icons.pending_actions_rounded,
                    color: MboaColors.terre700,
                    backgroundColor: MboaColors.terre100,
                  ),
                  _ArtisanStatCard(
                    value: '${data.counts['commandes'] ?? 0}',
                    label: 'Commandes reçues',
                    icon: Icons.receipt_long_rounded,
                    color: MboaColors.indigo700,
                    backgroundColor: MboaColors.indigo100,
                  ),
                  _ArtisanStatCard(
                    value: formatXaf(totalRevenue),
                    label: 'Ventes cumulées',
                    icon: Icons.payments_rounded,
                    color: MboaColors.ocre500,
                    backgroundColor: MboaColors.sable100,
                  ),
                ],
              ),
              const SizedBox(height: MboaSpace.xl),

              // Payment Notice Box
              MboaNoteBox(
                icon: Icons.verified_user_rounded,
                tone: MboaTileTone.vert,
                title: 'Déclaration MBOA',
                text: data.notice.isNotEmpty
                    ? data.notice
                    : 'MBOA ne touche aucune commission sur les ventes. Vous recevez 100% du prix fixé.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArtisanStatCard extends StatelessWidget {
  const _ArtisanStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.md),
        border: Border.all(color: MboaColors.contour),
        boxShadow: [
          BoxShadow(
            color: MboaColors.encre900.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: MboaSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: MboaColors.encre900,
              ),
            ),
          ),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1 : Objets / Catalogue
// ---------------------------------------------------------------------------
class _ProductsTab extends ConsumerStatefulWidget {
  const _ProductsTab();

  @override
  ConsumerState<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<_ProductsTab> {
  String? _selectedCategory;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(shopProductsProvider);
      ref.invalidate(shopProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MboaRadius.xl),
        ),
      ),
      builder: (_) => const _ProductSheet(),
    );
    if (created == true) {
      ref.invalidate(shopProductsProvider);
      ref.invalidate(shopProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(shopProductsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MboaSection.boutique.fond,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MboaColors.terre700,
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nouvel objet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final filteredList = _selectedCategory == null
              ? list
              : list.where((p) => p.category == _selectedCategory).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(shopProductsProvider),
            child: ListView(
              padding: const EdgeInsets.all(MboaSpace.lg),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mes Créations (${list.length})',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MboaSpace.md),

                // Category Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedCategory == null,
                        label: const Text('Tous'),
                        selectedColor: MboaColors.terre100,
                        labelStyle: TextStyle(
                          color: _selectedCategory == null
                              ? MboaColors.terre700
                              : MboaColors.encre900,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      for (final entry in kCategoryLabels.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _selectedCategory == entry.key,
                            label: Text(entry.value),
                            selectedColor: MboaColors.terre100,
                            labelStyle: TextStyle(
                              color: _selectedCategory == entry.key
                                  ? MboaColors.terre700
                                  : MboaColors.encre900,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) => setState(
                              () => _selectedCategory = val ? entry.key : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: MboaSpace.lg),

                if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: MboaSpace.xxl,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: MboaColors.encre400,
                        ),
                        const SizedBox(height: MboaSpace.md),
                        Text(
                          'Aucun objet dans cette catégorie',
                          style: text.titleMedium?.copyWith(
                            color: MboaColors.encre900,
                          ),
                        ),
                        const SizedBox(height: MboaSpace.xs),
                        Text(
                          'Cliquez sur « Nouvel objet » pour ajouter vos créations artisanales.',
                          style: text.bodySmall?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final product in filteredList)
                    _ArtisanProductCard(
                      product: product,
                      onTogglePublish: () => _run(
                        () => product.isPublished
                            ? ref
                                  .read(marketRepositoryProvider)
                                  .withdrawProduct(product.id)
                            : ref
                                  .read(marketRepositoryProvider)
                                  .publishProduct(product.id),
                      ),
                    ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArtisanProductCard extends StatelessWidget {
  const _ArtisanProductCard({
    required this.product,
    required this.onTogglePublish,
  });

  final Product product;
  final VoidCallback onTogglePublish;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: MboaSpace.lg),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        side: const BorderSide(color: MboaColors.contour),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(MboaRadius.md),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: MboaColors.sable100,
                    child: product.coverUrl != null
                        ? Image.network(
                            product.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_not_supported_rounded,
                              color: MboaColors.encre400,
                            ),
                          )
                        : const Icon(
                            Icons.photo_camera_rounded,
                            color: MboaColors.encre400,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            formatXaf(product.priceXaf),
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: MboaColors.terre700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${kCategoryLabels[product.category] ?? product.category} · Stock : ${product.stock}',
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: product.isPublished
                              ? MboaColors.forest100
                              : MboaColors.sable100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          product.isPublished ? 'EN VENTE' : 'HORS LIGNE',
                          style: text.labelSmall?.copyWith(
                            color: product.isPublished
                                ? MboaColors.forest700
                                : MboaColors.encre500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (product.claim != CulturalClaim.none) ...[
              const SizedBox(height: MboaSpace.md),
              ClaimBadge(claim: product.claim),
            ],
            const SizedBox(height: MboaSpace.md),
            // Photos Editor Integration
            ProductPhotosEditor(product: product),
            const SizedBox(height: MboaSpace.md),
            SizedBox(
              width: double.infinity,
              child: product.isPublished
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: MboaColors.encre400),
                      ),
                      onPressed: onTogglePublish,
                      icon: const Icon(Icons.visibility_off_rounded, size: 18),
                      label: const Text('Retirer de la vente'),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: MboaColors.forest700,
                      ),
                      onPressed: onTogglePublish,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Mettre en vente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet Création d'un objet
class _ProductSheet extends ConsumerStatefulWidget {
  const _ProductSheet();

  @override
  ConsumerState<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<_ProductSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '1');
  final _claim = TextEditingController();
  String _category = 'VANNERIE';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _claim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = int.tryParse(_price.text.trim());
    final stock = int.tryParse(_stock.text.trim());
    if (price == null || price <= 0 || stock == null || stock < 0) {
      setState(
        () => _error = 'Le prix et le stock doivent être des nombres valides.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(marketRepositoryProvider)
          .createProduct(
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category,
            priceXaf: price,
            stock: stock,
            culturalClaim: _claim.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
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
            Text(
              'Nouvel objet artisanal',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Nom de l’objet'),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description / Matières utilisées',
              ),
            ),
            const SizedBox(height: MboaSpace.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                for (final entry in kCategoryLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: MboaSpace.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prix (FCFA)'),
                  ),
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: TextField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock initial',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.lg),
            Text(
              'Affirmation culturelle (optionnel)',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MboaSpace.xs),
            Text(
              'Indiquez l’histoire ou la tradition associée à cet objet.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            const SizedBox(height: MboaSpace.sm),
            TextField(
              controller: _claim,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Signification, origine ou rituel',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: MboaSpace.md),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: MboaColors.erreur),
              ),
            ],
            const SizedBox(height: MboaSpace.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MboaColors.terre700,
                  padding: const EdgeInsets.symmetric(vertical: MboaSpace.md),
                ),
                onPressed: _sending ? null : _submit,
                child: Text(
                  _sending ? 'Enregistrement…' : 'Créer l’objet',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2 : Commandes reçues
// ---------------------------------------------------------------------------
class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab();

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(shopOrdersProvider);
      ref.invalidate(shopProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _contactBuyer(BuildContext context, String? phone, String buyerName) {
    final target = phone ?? '+237 690 000 000';
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contacter $buyerName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.phone_rounded,
                color: MboaColors.forest700,
              ),
              title: Text('Appeler $target'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Appel vers $target...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              title: const Text('Envoyer un message WhatsApp'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ouverture de WhatsApp avec $target...'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(shopOrdersProvider);
    final text = Theme.of(context).textTheme;
    final repo = ref.read(marketRepositoryProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(shopOrdersProvider),
        child: ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            Text(
              'Commandes Reçues (${list.length})',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MboaSpace.md),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MboaSpace.xxl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: MboaColors.encre400,
                    ),
                    const SizedBox(height: MboaSpace.md),
                    Text(
                      'Aucune commande pour l’instant',
                      style: text.titleMedium?.copyWith(
                        color: MboaColors.encre900,
                      ),
                    ),
                    const SizedBox(height: MboaSpace.xs),
                    Text(
                      'Dès qu’un acheteur passe commande, elle apparaîtra immédiatement ici.',
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final order in list)
                Card(
                  margin: const EdgeInsets.only(bottom: MboaSpace.lg),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MboaRadius.lg),
                    side: const BorderSide(color: MboaColors.contour),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(MboaSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.buyerName ?? 'Acheteur',
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              formatXaf(order.totalXaf),
                              style: text.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: MboaColors.terre700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Réf : ${order.reference}',
                          style: text.bodySmall?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),
                        const SizedBox(height: MboaSpace.sm),

                        if (order.isSimulated) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(MboaSpace.sm),
                            decoration: BoxDecoration(
                              color: MboaColors.terre100,
                              borderRadius: BorderRadius.circular(
                                MboaRadius.sm,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.science_outlined,
                                  size: 16,
                                  color: MboaColors.terre700,
                                ),
                                const SizedBox(width: MboaSpace.sm),
                                Expanded(
                                  child: Text(
                                    order.paymentNotice.isNotEmpty
                                        ? order.paymentNotice
                                        : 'Paiement simulé : aucun argent n’a été échangé.',
                                    style: text.bodySmall?.copyWith(
                                      color: MboaColors.terre700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: MboaSpace.sm),
                        ],

                        // Order Lines
                        for (final line in order.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: MboaColors.terre700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${line.quantity} × ${line.title}',
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: MboaSpace.sm),

                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: MboaColors.encre500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${order.deliveryCity} — ${order.deliveryAddress ?? ""}',
                                style: text.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        if (order.buyerNote != null) ...[
                          const SizedBox(height: MboaSpace.xs),
                          Text(
                            'Consigne : « ${order.buyerNote!} »',
                            style: text.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: MboaSpace.md),

                        // Contact Action Row
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: MboaColors.forest700,
                                ),
                              ),
                              onPressed: () => _contactBuyer(
                                context,
                                order.deliveryPhone,
                                order.buyerName ?? 'Acheteur',
                              ),
                              icon: const Icon(
                                Icons.phone_rounded,
                                size: 16,
                                color: MboaColors.forest700,
                              ),
                              label: const Text(
                                'Contacter acheteur',
                                style: TextStyle(color: MboaColors.forest700),
                              ),
                            ),
                            if (order.courierName != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Livreur : ${order.courierName}',
                                  style: text.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: MboaColors.indigo700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: MboaSpace.md),

                        // State Action Buttons
                        if (order.status == 'PENDING_CONFIRMATION')
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MboaColors.forest700,
                              ),
                              onPressed: () =>
                                  _run(() => repo.confirmOrder(order.id)),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                              label: const Text(
                                'Je confirme cette commande',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (order.status == 'CONFIRMED' ||
                            order.status == 'PREPARING') ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MboaColors.terre700,
                              ),
                              onPressed: () =>
                                  _run(() => repo.orderReady(order.id)),
                              icon: const Icon(Icons.inventory_2_rounded),
                              label: const Text(
                                'Le colis est prêt pour le livreur',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: MboaSpace.xxl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 3 : Conseils MBOA pour Artisans
// ---------------------------------------------------------------------------
class _ArtisanGuideTab extends StatelessWidget {
  const _ArtisanGuideTab();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(MboaSpace.lg),
      children: [
        Text(
          'Guide & Conseils MBOA',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: MboaSpace.xs),
        Text(
          'Valorisez votre savoir-faire artisanal auprès d’acheteurs passionnés.',
          style: text.bodySmall?.copyWith(color: MboaColors.encre500),
        ),
        const SizedBox(height: MboaSpace.lg),

        const MboaNoteBox(
          icon: Icons.camera_alt_rounded,
          tone: MboaTileTone.orange,
          title: '1. Des photos lumineuses',
          text:
              'Prenez vos créations en lumière naturelle. Montrez les détails du travail à la main (sculpture, couture, tissage).',
        ),
        const SizedBox(height: MboaSpace.md),

        const MboaNoteBox(
          icon: Icons.history_edu_rounded,
          tone: MboaTileTone.indigo,
          title: '2. Racontez l’histoire de l’objet',
          text:
              'Remplissez le champ « Ce que cet objet représente ». Les acheteurs recherchent l’authenticité et la mémoire culturelle.',
        ),
        const SizedBox(height: MboaSpace.md),

        const MboaNoteBox(
          icon: Icons.local_shipping_rounded,
          tone: MboaTileTone.vert,
          title: '3. Emballage soigné',
          text:
              'Protégez bien l’objet avant la remise au livreur. Un colis bien emballé garantit des avis 5 étoiles sur MBOA.',
        ),
      ],
    );
  }
}
