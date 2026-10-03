import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_header.dart';
import '../data/market_repository.dart';
import '../domain/models.dart';
import 'claim_badge.dart';
import 'product_photo.dart';

const Map<String, String> kCategoryLabels = {
  'TEXTILE': 'Textile',
  'VANNERIE': 'Vannerie',
  'POTERIE': 'Poterie',
  'SCULPTURE': 'Sculpture',
  'BIJOUX': 'Bijoux',
  'INSTRUMENT': 'Instruments',
  'PEINTURE': 'Peinture',
  'GASTRONOMIE': 'Gastronomie',
  'AUTRE': 'Autre',
};

const Map<String, IconData> kCategoryIcons = {
  'TEXTILE': Icons.checkroom_rounded,
  'VANNERIE': Icons.shopping_basket_rounded,
  'POTERIE': Icons.coffee_rounded,
  'SCULPTURE': Icons.architecture_rounded,
  'BIJOUX': Icons.diamond_rounded,
  'INSTRUMENT': Icons.music_note_rounded,
  'PEINTURE': Icons.palette_rounded,
  'GASTRONOMIE': Icons.restaurant_rounded,
  'AUTRE': Icons.category_rounded,
};

const Map<String, String> kSortLabels = {
  'RECENT': 'Les plus récents',
  'PRICE_ASC': 'Prix croissant',
  'PRICE_DESC': 'Prix décroissant',
  'RATING': 'Les mieux notés',
};

/// Le catalogue de la place de marché (SS45).
///
/// La liste d'origine est devenue une grille avec recherche, filtres et tri :
/// sur une place de marché on cherche, on compare, on trie. Sans cela, trouver
/// un objet parmi trente-cinq demandait de faire défiler la page entière.
///
/// Ce que la grille ne fait pas : combler les vides. Un produit sans photo reçoit
/// un cadre qui le dit, jamais une image d'emprunt. Et une boutique de
/// **démonstration** porte son étiquette sur chaque carte : l'objet n'est pas en
/// vente, et l'acheteur ne doit pas l'apprendre au moment de commander.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  CatalogQuery _query = const CatalogQuery();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// La recherche attend qu'on ait fini de taper.
  ///
  /// Interroger le serveur à chaque lettre enverrait sept requêtes pour
  /// « raphia », et la dernière arrivée gagnerait — pas forcément la bonne.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = _query.copyWith(text: value));
    });
  }

  Future<void> _openFilters(CatalogBounds bounds) async {
    final resultat = await showModalBottomSheet<CatalogQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(query: _query, bounds: bounds),
    );
    if (resultat != null && mounted) setState(() => _query = resultat);
  }

  static int _columns(double width, double textScale) {
    final utile = width / textScale;
    if (utile >= 1100) return 5;
    if (utile >= 840) return 4;
    if (utile >= 600) return 3;
    if (utile >= 320) return 2;
    return 1;
  }

  /// Hauteur à réserver sous la photo, pour le titre, le prix et le reste.
  ///
  /// Un rapport largeur/hauteur fixe ne marche pas : le texte grossit avec le
  /// réglage système, la photo non. À 200 %, une proportion calée sur 100 %
  /// fait déborder la vignette.
  static double _contentHeight(BuildContext context) {
    final styles = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);

    double lignes(TextStyle? style, [int nombre = 1]) {
      final taille = style?.fontSize ?? 14;
      final interligne = style?.height ?? 1.45;
      return scaler.scale(taille) * interligne * nombre;
    }

    final contenu =
        lignes(styles.bodyMedium, 2) + // titre
        lignes(styles.titleMedium) + // prix
        lignes(styles.bodySmall) + // note
        lignes(styles.bodySmall) + // boutique et ville
        lignes(styles.bodySmall) + // pastille
        8 +
        MboaSpace.xs * 4 +
        MboaSpace.sm * 2;

    // Le coefficient est serré au plus près : le bloc de texte occupe
    // exactement cette hauteur, si bien que tout excédent se voit comme du
    // blanc en bas de la carte. Mesuré par essais successifs — 1,12 déborde,
    // 1,18 tient. On garde une petite réserve au-dessus du seuil, parce qu'un
    // changement de typographie déplacerait la limite.
    //
    // Les deux pixels sont la bordure de la carte, en haut et en bas : elle
    // mange sur la hauteur réservée, et l'oublier faisait manquer la mesure
    // d'exactement cette épaisseur.
    return contenu * 1.22 + 2;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(marketCategoriesProvider);
    final page = ref.watch(marketProductsProvider(_query));
    final largeur = MediaQuery.sizeOf(context).width;
    final echelle = MediaQuery.textScalerOf(context).scale(1);
    final colonnes = _columns(largeur, echelle);
    final largeurVignette =
        ((largeur - MboaSpace.lg * 2 - MboaSpace.md * (colonnes - 1)) /
                colonnes)
            .clamp(1.0, double.infinity);

    return Scaffold(
      backgroundColor: MboaSection.boutique.fond,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(marketCategoriesProvider);
          ref.invalidate(marketProductsProvider(_query));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MboaGradientHeader(
                section: MboaSection.boutique,
                title: 'Boutique',
                subtitle: 'Des objets faits par des artisans, vendus par eux.',
                actions: [
                  MboaHeaderAction(
                    icon: Icons.receipt_long_outlined,
                    tooltip: 'Mes commandes',
                    onPressed: () => context.push('/orders'),
                  ),
                ],
                child: _SearchField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  onClear: () {
                    _search.clear();
                    setState(() => _query = _query.copyWith(text: ''));
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MboaSpace.lg,
                  MboaSpace.lg,
                  MboaSpace.lg,
                  MboaSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    categories.when(
                      loading: () => const SizedBox(height: 92),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (list) => _CategoryStrip(
                        categories: list,
                        selected: _query.category,
                        onSelected: (code) => setState(
                          () => _query = code == null
                              ? _query.copyWith(clearCategory: true)
                              : _query.copyWith(category: code),
                        ),
                      ),
                    ),
                    const SizedBox(height: MboaSpace.md),
                    Text(
                      'MBOA met en relation et n’achète rien.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                    const SizedBox(height: MboaSpace.md),
                    page.maybeWhen(
                      data: (data) => _Toolbar(
                        found: data.items.length,
                        total: data.bounds.total,
                        query: _query,
                        onFilters: () => _openFilters(data.bounds),
                        onSort: (sort) => setState(
                          () => _query = _query.copyWith(sort: sort),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            page.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(MboaSpace.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(MboaSpace.lg),
                  child: Text('$e'),
                ),
              ),
              data: (data) => data.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(MboaSpace.lg),
                        child: _Empty(
                          filtered: _query.activeFilters > 0,
                          onReset: () {
                            _search.clear();
                            setState(() => _query = const CatalogQuery());
                          },
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MboaSpace.lg,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: colonnes,
                          mainAxisSpacing: MboaSpace.md,
                          crossAxisSpacing: MboaSpace.md,
                          childAspectRatio:
                              largeurVignette /
                              (largeurVignette + _contentHeight(context)),
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              ProductTile(product: data.items[index]),
                          childCount: data.items.length,
                        ),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(MboaSpace.lg),
                child: Column(
                  children: [
                    page.maybeWhen(
                      data: (data) => PaymentNotice(notice: data.notice),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: MboaSpace.xxxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le champ de recherche, posé dans le dégradé de l'en-tête.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(MboaRadius.xl),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Chercher un objet, une matière, une ville…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MboaRadius.xl),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MboaSpace.lg,
          vertical: MboaSpace.md,
        ),
      ),
    ),
  );
}

/// Le bandeau de catégories : une pastille colorée par famille d'objets.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<({String code, int count})> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _tones = [
    MboaTileTone.indigo,
    MboaTileTone.vert,
    MboaTileTone.orange,
    MboaTileTone.ambre,
    MboaTileTone.rose,
    MboaTileTone.bleu,
  ];

  @override
  Widget build(BuildContext context) {
    // Les familles vides ne sont pas affichées : une pastille qui ne mène à
    // rien n'aide personne à trouver.
    final visibles = categories.where((c) => c.count > 0).toList();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibles.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: MboaSpace.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChip(
              icon: Icons.grid_view_rounded,
              label: 'Tout',
              count: visibles.fold(0, (a, c) => a + c.count),
              tone: MboaTileTone.indigo,
              selected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final categorie = visibles[index - 1];
          return _CategoryChip(
            icon: kCategoryIcons[categorie.code] ?? Icons.category_rounded,
            label: kCategoryLabels[categorie.code] ?? categorie.code,
            count: categorie.count,
            tone: _tones[index % _tones.length],
            selected: selected == categorie.code,
            onTap: () => onSelected(categorie.code),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final MboaTileTone tone;
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
          width: 84,
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
                '$count',
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

/// Ce qu'on a trouvé, et les deux commandes pour affiner.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.found,
    required this.total,
    required this.query,
    required this.onFilters,
    required this.onSort,
  });

  final int found;
  final int total;
  final CatalogQuery query;
  final VoidCallback onFilters;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final filtres = query.activeFilters;

    return Wrap(
      spacing: MboaSpace.sm,
      runSpacing: MboaSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          filtres == 0
              ? '$total objet${total > 1 ? 's' : ''}'
              : '$found sur $total',
          style: text.titleMedium,
        ),
        OutlinedButton.icon(
          onPressed: onFilters,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(filtres == 0 ? 'Filtrer' : 'Filtres ($filtres)'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, kMinTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: MboaSpace.md),
          ),
        ),
        PopupMenuButton<String>(
          initialValue: query.sort,
          onSelected: onSort,
          tooltip: 'Trier',
          itemBuilder: (_) => [
            for (final entry in kSortLabels.entries)
              PopupMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          child: Container(
            // Une hauteur fixe rognerait le libellé dès que le texte grossit,
            // et une largeur libre le ferait déborder de la ligne : on borne
            // la largeur et on laisse la hauteur suivre.
            constraints: const BoxConstraints(
              minHeight: kMinTouchTarget,
              maxWidth: 240,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MboaSpace.md,
              vertical: MboaSpace.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: MboaColors.sable600),
              borderRadius: BorderRadius.circular(MboaRadius.xl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 18),
                const SizedBox(width: MboaSpace.xs),
                Flexible(
                  child: Text(
                    kSortLabels[query.sort] ?? 'Trier',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// La feuille de filtres : prix et famille d'objets.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.query, required this.bounds});
  final CatalogQuery query;
  final CatalogBounds bounds;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RangeValues _prix;
  String? _categorie;

  double get _mini => (widget.bounds.minPrice ?? 0).toDouble();
  double get _maxi =>
      (widget.bounds.maxPrice ?? 100000).toDouble().clamp(_mini + 1, 1e9);

  @override
  void initState() {
    super.initState();
    _categorie = widget.query.category;
    _prix = RangeValues(
      (widget.query.minPrice ?? widget.bounds.minPrice ?? 0).toDouble().clamp(
        _mini,
        _maxi,
      ),
      (widget.query.maxPrice ?? widget.bounds.maxPrice ?? 100000)
          .toDouble()
          .clamp(_mini, _maxi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        MboaSpace.lg,
        0,
        MboaSpace.lg,
        MediaQuery.viewInsetsOf(context).bottom + MboaSpace.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filtrer', style: text.headlineMedium),
            const SizedBox(height: MboaSpace.lg),
            Text('Prix', style: text.titleMedium),
            Text(
              '${formatXaf(_prix.start.round())} — ${formatXaf(_prix.end.round())}',
              style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
            ),
            RangeSlider(
              values: _prix,
              min: _mini,
              max: _maxi,
              divisions: 20,
              labels: RangeLabels(
                formatXaf(_prix.start.round()),
                formatXaf(_prix.end.round()),
              ),
              onChanged: (v) => setState(() => _prix = v),
            ),
            const SizedBox(height: MboaSpace.md),
            Text('Famille d’objets', style: text.titleMedium),
            const SizedBox(height: MboaSpace.sm),
            Wrap(
              spacing: MboaSpace.sm,
              runSpacing: MboaSpace.sm,
              children: [
                ChoiceChip(
                  label: const Text('Toutes'),
                  selected: _categorie == null,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _categorie = null),
                ),
                for (final entry in kCategoryLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _categorie == entry.key,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => setState(() => _categorie = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: MboaSpace.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(
                      CatalogQuery(
                        text: widget.query.text,
                        sort: widget.query.sort,
                      ),
                    ),
                    child: const Text('Tout effacer'),
                  ),
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      CatalogQuery(
                        category: _categorie,
                        text: widget.query.text,
                        sort: widget.query.sort,
                        // On ne transmet une borne que si elle restreint
                        // vraiment : sinon le compteur de filtres annoncerait
                        // une restriction qui n'en est pas une.
                        minPrice: _prix.start > _mini
                            ? _prix.start.round()
                            : null,
                        maxPrice: _prix.end < _maxi ? _prix.end.round() : null,
                      ),
                    ),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Une vignette de la grille.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(color: MboaColors.contour),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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
                      top: MboaSpace.sm,
                      left: MboaSpace.sm,
                      child: DemoTag(),
                    ),
                  if (product.rating != null)
                    Positioned(
                      top: MboaSpace.sm,
                      right: MboaSpace.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: MboaColors.or,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              // Le nombre d'avis fait partie de la note : 4,5
                              // sur deux avis et 4,5 sur deux cents ne disent
                              // pas la même chose. L'afficher seul laisserait
                              // croire à une moyenne établie.
                              '${product.rating!.toStringAsFixed(1)} '
                              '(${product.reviews})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Hauteur fixe pour le bloc de texte : sans elle, une carte qui
            // porte une pastille d'affirmation rogne sa photo, et les
            // vignettes d'une même rangée n'ont plus la même image. C'est
            // exactement la hauteur que la grille a déjà réservée.
            SizedBox(
              height: _MarketScreenState._contentHeight(context),
              child: Padding(
                padding: const EdgeInsets.all(MboaSpace.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: MboaSpace.xs),
                    // Un Wrap, pas un Row : le prix est l'information qu'on
                    // vient chercher, et il était tronqué en « 12 000 F… » dès
                    // que la pastille de stock lui disputait la ligne. Ici, la
                    // pastille passe à la ligne suivante plutôt que de rogner le
                    // prix.
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatXaf(product.priceXaf),
                          style: text.titleMedium?.copyWith(
                            color: MboaColors.terre700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.stock > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MboaColors.forest100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'En stock',
                              style: text.bodySmall?.copyWith(
                                fontSize: 10,
                                color: MboaColors.forest900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: MboaSpace.xs),
                    Text(
                      product.shopCity == null
                          ? product.shopName
                          : '${product.shopName} · ${product.shopCity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                        fontSize: 12,
                      ),
                    ),
                    if (product.claim != CulturalClaim.none) ...[
                      const SizedBox(height: MboaSpace.xs),
                      ClaimBadge(claim: product.claim, compact: true),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'étiquette d'un objet de démonstration.
///
/// Elle est posée **sur la photo**, en haut à gauche : c'est le premier endroit
/// où le regard se pose sur une grille. Un acheteur ne doit pas découvrir au
/// moment de commander que l'objet n'existe pas.
class DemoTag extends StatelessWidget {
  const DemoTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: MboaColors.encre900.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.science_outlined, size: 12, color: Colors.white),
        SizedBox(width: 4),
        Text(
          'démo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, required this.onReset});
  final bool filtered;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.search_off_rounded : Icons.storefront_outlined,
            size: 40,
            color: MboaColors.encre400,
          ),
          const SizedBox(height: MboaSpace.md),
          Text(
            filtered ? 'Rien ne correspond' : 'Aucun objet en vente ici',
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MboaSpace.xs),
          Text(
            filtered
                ? 'Essayez d’élargir le prix, ou de changer de famille d’objets.'
                : 'Les boutiques ouvrent au fur et à mesure que les dossiers '
                      'd’artisans sont vérifiés.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
          if (filtered) ...[
            const SizedBox(height: MboaSpace.lg),
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Effacer la recherche'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Accès de test à la hauteur réservée sous une vignette.
///
/// Elle est calculée, pas devinée : un test doit pouvoir vérifier que le calcul
/// couvre bien la hauteur réelle, à tous les grossissements de texte.
abstract final class MarketScreenProbe {
  static double contentHeight(BuildContext context) =>
      _MarketScreenState._contentHeight(context);

  /// Le nombre de colonnes que la grille retiendrait.
  ///
  /// Exposé pour que les tests mesurent une vignette à la largeur qu'elle a
  /// réellement : à fort grossissement, la grille passe à une colonne, et
  /// vérifier une vignette étroite à 200 % reviendrait à tester une mise en
  /// page que personne ne voit.
  static int columns(double width, double textScale) =>
      _MarketScreenState._columns(width, textScale);

  /// La largeur d'une vignette sur un écran de [width] points.
  static double tileWidth(double width, double textScale) {
    final colonnes = columns(width, textScale);
    return (width - MboaSpace.lg * 2 - MboaSpace.md * (colonnes - 1)) /
        colonnes;
  }
}
