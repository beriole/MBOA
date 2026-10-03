/// Modèles de la place de marché (SS45 à SS48).
///
/// Deux choses que ces objets portent explicitement, parce qu'elles ne doivent
/// jamais se perdre entre le serveur et l'écran : le statut d'une affirmation
/// culturelle, et le fait que MBOA n'encaisse rien.
library;

/// Ce qu'un objet est dit être, et ce qui appuie cette affirmation.
enum CulturalClaim {
  /// Aucune affirmation culturelle : un objet est un objet.
  none,

  /// L'artisan l'affirme. MBOA ne l'endosse pas.
  artisanDeclaration,

  /// Rattachée à une fiche du Culture Hub, donc sourcée et validée.
  linkedToSource;

  static CulturalClaim parse(String? value) => switch (value) {
    'ARTISAN_DECLARATION' => CulturalClaim.artisanDeclaration,
    'LINKED_TO_SOURCE' => CulturalClaim.linkedToSource,
    _ => CulturalClaim.none,
  };

  String get label => switch (this) {
    CulturalClaim.artisanDeclaration => 'Déclaration de l’artisan',
    CulturalClaim.linkedToSource => 'Documenté par une fiche MBOA',
    CulturalClaim.none => '',
  };

  /// La version courte, pour une vignette de grille. Elle garde la
  /// distinction qui compte : documenté par MBOA, ou affirmé par le vendeur.
  String get shortLabel => switch (this) {
    CulturalClaim.artisanDeclaration => 'Dit par le vendeur',
    CulturalClaim.linkedToSource => 'Documenté',
    CulturalClaim.none => '',
  };

  String get explanation => switch (this) {
    CulturalClaim.artisanDeclaration =>
      'Cette description vient du vendeur. MBOA ne l’a pas vérifiée et ne '
          'la présente pas comme un fait établi.',
    CulturalClaim.linkedToSource =>
      'Cette description s’appuie sur une fiche culturelle publiée, qui '
          'cite ses sources.',
    CulturalClaim.none => '',
  };
}

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.priceXaf,
    required this.stock,
    required this.shopId,
    required this.shopName,
    this.description,
    this.imageUrl,
    this.shopCity,
    this.regionName,
    this.culturalClaim,
    this.claim = CulturalClaim.none,
    this.status = 'PUBLISHED',
    this.images = const [],
    this.rating,
    this.reviews = 0,
    this.shopIsDemo = false,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    title: j['title_fr'] as String,
    category: j['category'] as String,
    priceXaf: j['price_xaf'] as int,
    stock: j['stock'] as int,
    shopId: j['shop_id'] as String? ?? '',
    shopName: j['shop_name'] as String? ?? '',
    description: j['description_fr'] as String?,
    imageUrl: j['image_url'] as String?,
    shopCity: j['shop_city'] as String?,
    regionName: j['region_name'] as String?,
    culturalClaim: j['cultural_claim_fr'] as String?,
    claim: CulturalClaim.parse(j['cultural_claim_status'] as String?),
    status: j['status'] as String? ?? 'PUBLISHED',
    images: [
      for (final image in (j['images'] as List? ?? const []))
        ProductImage.fromJson(image as Map<String, dynamic>),
    ],
    rating: (j['note_moyenne'] as num?)?.toDouble(),
    reviews: (j['avis'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String title;
  final String category;
  final int priceXaf;
  final int stock;
  final String shopId;
  final String shopName;
  final String? description;
  final String? imageUrl;
  final String? shopCity;
  final String? regionName;
  final String? culturalClaim;
  final CulturalClaim claim;
  final String status;

  /// Les photos déposées par l'artisan, dans l'ordre qu'il a choisi.
  final List<ProductImage> images;

  /// Moyenne des notes laissées par les acheteurs, quand il y en a.
  final double? rating;
  final int reviews;

  /// Vrai si la boutique est une **démonstration**.
  ///
  /// Le catalogue réel ne comptait qu'un objet ; on ne juge pas une grille de
  /// place de marché sur si peu. Des boutiques de démonstration donnent du
  /// volume — mais un artisan est une personne, et cet objet-là n'est pas en
  /// vente. La carte le dit, et ne laisse pas l'acheteur le découvrir après.
  final bool shopIsDemo;

  bool get isPublished => status == 'PUBLISHED';

  /// La vignette du catalogue.
  ///
  /// `image_url` reste accepté : des produits ont pu être créés avec une
  /// adresse saisie à la main avant que le dépôt de photos existe.
  String? get coverUrl => images.isNotEmpty ? images.first.url : imageUrl;

  /// Rien à montrer. L'écran le dit plutôt que d'afficher une photo d'emprunt :
  /// un objet artisanal est unique, une illustration générique tromperait.
  bool get hasNoPhoto => coverUrl == null;
}

/// Ce que la recherche décrit : l'ensemble du catalogue, indépendamment des
/// filtres appliqués. Un curseur de prix doit garder la même échelle quand on
/// affine, sinon il se dérobe sous le doigt.
class CatalogBounds {
  const CatalogBounds({this.total = 0, this.minPrice, this.maxPrice});

  factory CatalogBounds.fromJson(Map<String, dynamic> j) => CatalogBounds(
    total: (j['total'] as num?)?.toInt() ?? 0,
    minPrice: (j['prix_min'] as num?)?.toInt(),
    maxPrice: (j['prix_max'] as num?)?.toInt(),
  );

  final int total;
  final int? minPrice;
  final int? maxPrice;
}

/// Une page de catalogue : les objets trouvés, et de quoi régler les filtres.
class CatalogPage {
  const CatalogPage({
    required this.items,
    required this.notice,
    this.bounds = const CatalogBounds(),
  });

  factory CatalogPage.fromJson(Map<String, dynamic> j) => CatalogPage(
    items: [
      for (final p in (j['items'] as List? ?? const []))
        Product.fromJson(p as Map<String, dynamic>),
    ],
    notice: j['reglement'] as String? ?? '',
    bounds: CatalogBounds.fromJson(
      (j['catalogue'] as Map<String, dynamic>?) ?? const {},
    ),
  );

  final List<Product> items;
  final String notice;
  final CatalogBounds bounds;

  bool get isEmpty => items.isEmpty;
}

/// Les critères de recherche du catalogue.
class CatalogQuery {
  const CatalogQuery({
    this.category,
    this.text,
    this.minPrice,
    this.maxPrice,
    this.sort = 'RECENT',
  });

  final String? category;
  final String? text;
  final int? minPrice;
  final int? maxPrice;
  final String sort;

  /// Combien de critères sont posés, hors tri : sert à annoncer « 2 filtres »
  /// sur le bouton, pour qu'on sache qu'un résultat est restreint.
  int get activeFilters => [
    category,
    (text != null && text!.trim().isNotEmpty) ? text : null,
    minPrice,
    maxPrice,
  ].where((e) => e != null).length;

  CatalogQuery copyWith({
    String? category,
    String? text,
    int? minPrice,
    int? maxPrice,
    String? sort,
    bool clearCategory = false,
    bool clearPrices = false,
  }) => CatalogQuery(
    category: clearCategory ? null : (category ?? this.category),
    text: text ?? this.text,
    minPrice: clearPrices ? null : (minPrice ?? this.minPrice),
    maxPrice: clearPrices ? null : (maxPrice ?? this.maxPrice),
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery &&
      other.category == category &&
      other.text == text &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(category, text, minPrice, maxPrice, sort);
}

/// Une photo de produit, servie par l'API.
class ProductImage {
  const ProductImage({required this.id, required this.url, this.caption});

  factory ProductImage.fromJson(Map<String, dynamic> j) => ProductImage(
    id: j['id'] as String,
    url: j['url'] as String,
    caption: j['caption'] as String?,
  );

  final String id;
  final String url;
  final String? caption;
}

/// Fiche culturelle citée par un produit, quand elle existe.
class ProductSource {
  const ProductSource({
    required this.id,
    required this.title,
    this.sourceTitle,
  });

  factory ProductSource.fromJson(Map<String, dynamic> j) => ProductSource(
    id: j['id'] as String,
    title: j['title_fr'] as String,
    sourceTitle: j['source_title'] as String?,
  );

  final String id;
  final String title;
  final String? sourceTitle;
}

class ProductDetail {
  const ProductDetail({
    required this.product,
    required this.notice,
    this.source,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
    product: Product.fromJson(j),
    notice: j['reglement'] as String? ?? '',
    source: j['fiche_culturelle'] == null
        ? null
        : ProductSource.fromJson(j['fiche_culturelle'] as Map<String, dynamic>),
  );

  final Product product;

  /// Rappel du mode de règlement, servi par l'API.
  final String notice;
  final ProductSource? source;
}

class OrderLine {
  const OrderLine({
    required this.title,
    required this.unitPriceXaf,
    required this.quantity,
  });

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
    title: j['title_fr'] as String,
    unitPriceXaf: j['unit_price_xaf'] as int,
    quantity: j['quantity'] as int,
  );

  final String title;
  final int unitPriceXaf;
  final int quantity;
}

class DeliveryStep {
  const DeliveryStep({required this.status, required this.at, this.note});

  factory DeliveryStep.fromJson(Map<String, dynamic> j) => DeliveryStep(
    status: j['status'] as String,
    at: DateTime.parse(j['at'] as String),
    note: j['note'] as String?,
  );

  final String status;
  final DateTime at;
  final String? note;
}

class Order {
  const Order({
    required this.id,
    required this.reference,
    required this.status,
    required this.totalXaf,
    required this.shopName,
    required this.deliveryCity,
    required this.createdAt,
    this.lines = const [],
    this.timeline = const [],
    this.deliveryStatus,
    this.courierName,
    this.courierPhone,
    this.cancelReason,
    this.buyerName,
    this.deliveryAddress,
    this.deliveryPhone,
    this.buyerNote,
    this.paymentMode = 'CASH_ON_DELIVERY',
    this.paymentNotice = '',
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as String,
    reference: j['reference'] as String,
    status: j['status'] as String,
    totalXaf: j['total_xaf'] as int,
    shopName: j['shop_name'] as String? ?? '',
    deliveryCity: j['delivery_city'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String),
    lines: ((j['lignes'] ?? const []) as List)
        .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    timeline: ((j['timeline'] ?? const []) as List)
        .map((e) => DeliveryStep.fromJson(e as Map<String, dynamic>))
        .toList(),
    deliveryStatus: j['delivery_status'] as String?,
    courierName: j['courier_name'] as String?,
    courierPhone: j['courier_phone'] as String?,
    cancelReason: j['cancel_reason_fr'] as String?,
    buyerName: j['buyer_name'] as String?,
    deliveryAddress: j['delivery_address_fr'] as String?,
    deliveryPhone: j['delivery_phone'] as String?,
    buyerNote: j['buyer_note_fr'] as String?,
    paymentMode: j['payment_mode'] as String? ?? 'CASH_ON_DELIVERY',
    paymentNotice: j['reglement'] as String? ?? '',
  );

  final String id;
  final String reference;
  final String status;
  final int totalXaf;
  final String shopName;
  final String deliveryCity;
  final DateTime createdAt;
  final List<OrderLine> lines;
  final List<DeliveryStep> timeline;
  final String? deliveryStatus;
  final String? courierName;
  final String? courierPhone;
  final String? cancelReason;

  /// `CASH_ON_DELIVERY` ou `SIMULATION`.
  final String paymentMode;

  /// La mention à afficher, servie par le serveur : elle diffère selon le mode,
  /// et l'écran ne doit pas la reconstituer de son côté.
  final String paymentNotice;

  /// Vrai quand cette commande est une démonstration. Rien n'a été payé, et
  /// l'artisan ne doit préparer aucun envoi réel.
  bool get isSimulated => paymentMode == 'SIMULATION';

  final String? buyerName;
  final String? deliveryAddress;
  final String? deliveryPhone;
  final String? buyerNote;

  bool get isCancellable =>
      status == 'PENDING_CONFIRMATION' || status == 'CONFIRMED';
  bool get isClosed => status == 'DELIVERED' || status == 'CANCELLED';

  static const _labels = {
    'PENDING_CONFIRMATION': 'En attente de confirmation',
    'CONFIRMED': 'Confirmée par l’artisan',
    'PREPARING': 'En préparation',
    'READY_FOR_PICKUP': 'Prête, en attente d’un livreur',
    'IN_DELIVERY': 'En cours de livraison',
    'DELIVERED': 'Livrée',
    'CANCELLED': 'Annulée',
  };

  String get label => _labels[status] ?? status;
}

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.city,
    this.phone,
  });

  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
    id: j['id'] as String,
    name: j['name'] as String,
    status: j['status'] as String,
    description: j['description_fr'] as String?,
    city: j['city'] as String?,
    phone: j['phone'] as String?,
  );

  final String id;
  final String name;
  final String status;
  final String? description;
  final String? city;
  final String? phone;

  bool get isOpen => status == 'OPEN';
}

class ShopDashboard {
  const ShopDashboard({
    required this.shop,
    required this.counts,
    required this.notice,
  });

  factory ShopDashboard.fromJson(Map<String, dynamic> j) => ShopDashboard(
    shop: Shop.fromJson(j['boutique'] as Map<String, dynamic>),
    counts: Map<String, int>.from(j['chiffres'] as Map),
    notice: j['reglement'] as String? ?? '',
  );

  final Shop shop;
  final Map<String, int> counts;
  final String notice;
}

class CourierProfile {
  const CourierProfile({
    required this.id,
    required this.displayName,
    required this.vehicle,
    required this.cities,
    required this.isAvailable,
    this.phone,
  });

  factory CourierProfile.fromJson(Map<String, dynamic> j) => CourierProfile(
    id: j['id'] as String,
    displayName: j['display_name'] as String,
    vehicle: j['vehicle'] as String,
    cities: (j['cities'] as List).cast<String>(),
    isAvailable: j['is_available'] as bool,
    phone: j['phone'] as String?,
  );

  final String id;
  final String displayName;
  final String vehicle;
  final List<String> cities;
  final bool isAvailable;
  final String? phone;
}

class CourierDashboard {
  const CourierDashboard({
    required this.profile,
    required this.counts,
    required this.notice,
  });

  factory CourierDashboard.fromJson(Map<String, dynamic> j) => CourierDashboard(
    profile: CourierProfile.fromJson(j['livreur'] as Map<String, dynamic>),
    counts: Map<String, int>.from(
      (j['chiffres'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
    ),
    notice: j['note'] as String? ?? '',
  );

  final CourierProfile profile;
  final Map<String, int> counts;
  final String notice;
}

/// Une course, vue par le livreur.
class Delivery {
  const Delivery({
    required this.id,
    required this.reference,
    required this.totalXaf,
    required this.dropoffCity,
    required this.address,
    required this.shopName,
    this.status,
    this.pickupCity,
    this.shopPhone,
    this.deliveryPhone,
    this.cashDeclaredXaf,
    this.timeline = const [],
  });

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
    id: j['id'] as String,
    reference: j['reference'] as String,
    totalXaf: j['total_xaf'] as int,
    dropoffCity: j['dropoff_city'] as String? ?? '',
    address: j['delivery_address_fr'] as String? ?? '',
    shopName: j['shop_name'] as String? ?? '',
    status: j['status'] as String?,
    pickupCity: j['pickup_city'] as String?,
    shopPhone: j['shop_phone'] as String?,
    deliveryPhone: j['delivery_phone'] as String?,
    cashDeclaredXaf: j['cash_declared_xaf'] as int?,
    timeline: ((j['timeline'] ?? const []) as List)
        .map((e) => DeliveryStep.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String reference;
  final int totalXaf;
  final String dropoffCity;
  final String address;
  final String shopName;
  final String? status;
  final String? pickupCity;
  final String? shopPhone;
  final String? deliveryPhone;
  final int? cashDeclaredXaf;
  final List<DeliveryStep> timeline;

  static const _labels = {
    'UNASSIGNED': 'À prendre',
    'ASSIGNED': 'Acceptée',
    'PICKED_UP': 'Colis récupéré',
    'IN_TRANSIT': 'En route',
    'DELIVERED': 'Remise',
    'FAILED': 'Non aboutie',
  };

  String get label => _labels[status] ?? status ?? '';

  /// L'étape suivante possible, ou `null` si la course est close.
  String? get nextStatus => switch (status) {
    'ASSIGNED' => 'PICKED_UP',
    'PICKED_UP' => 'IN_TRANSIT',
    'IN_TRANSIT' => 'DELIVERED',
    _ => null,
  };

  String? get nextLabel => switch (nextStatus) {
    'PICKED_UP' => 'J’ai récupéré le colis',
    'IN_TRANSIT' => 'Je suis en route',
    'DELIVERED' => 'J’ai remis le colis',
    _ => null,
  };
}

/// Prix en francs CFA, avec séparateur de milliers.
String formatXaf(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer FCFA';
}
