import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/models.dart';

/// Accès à la place de marché.
///
/// Le libellé du règlement vient du serveur et n'est jamais réécrit ici : une
/// seule source pour ce que la plateforme dit de l'argent.
class MarketRepository {
  MarketRepository(this._api);

  final ApiClient _api;

  // --- catalogue ---------------------------------------------------------
  Future<List<({String code, int count})>> categories() async {
    final data = await _api.get('/market/categories') as List;
    return data
        .map(
          (e) =>
              (code: (e as Map)['code'] as String, count: e['produits'] as int),
        )
        .toList();
  }

  /// Le catalogue, avec recherche, filtres et tri.
  ///
  /// Les bornes de prix renvoyées sont celles du catalogue **entier**, pas du
  /// résultat filtré : un curseur de prix doit garder la même échelle quand on
  /// affine, sinon il se dérobe sous le doigt.
  Future<CatalogPage> products({
    String? category,
    String? query,
    int? minPrice,
    int? maxPrice,
    String sort = 'RECENT',
  }) async {
    final params = <String, String>{
      if (category != null) 'category': category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (minPrice != null) 'min_price': '$minPrice',
      if (maxPrice != null) 'max_price': '$maxPrice',
      'sort': sort,
    };
    final suffix = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return CatalogPage.fromJson(
      await _api.get('/market/products?$suffix') as Map<String, dynamic>,
    );
  }

  Future<ProductDetail> product(String id) async => ProductDetail.fromJson(
    await _api.get('/market/products/$id') as Map<String, dynamic>,
  );

  // --- acheteur ----------------------------------------------------------
  Future<String> order({
    required String productId,
    required int quantity,
    required String city,
    required String address,
    required String phone,
    String? note,

    /// `CASH_ON_DELIVERY` ou `SIMULATION`. Aucun des deux ne fait transiter
    /// d'argent par MBOA ; les autres modes sont refusés par le serveur.
    String paymentMode = 'CASH_ON_DELIVERY',
  }) async {
    final data = await _api.post('/me/orders', {
      'product_id': productId,
      'quantity': quantity,
      'delivery_city': city,
      'delivery_address_fr': address,
      'delivery_phone': phone,
      'payment_mode': paymentMode,
      if (note != null && note.isNotEmpty) 'buyer_note_fr': note,
    });
    return data['reference'] as String;
  }

  /// Dépose une photo sur un produit de sa propre boutique.
  ///
  /// Le serveur vérifie le format dans les octets eux-mêmes et refuse ce qui
  /// n'est pas une image : le nom du fichier ne fait pas foi.
  Future<String> uploadProductImage(
    String productId, {
    required List<int> bytes,
    required String filename,
  }) async {
    final data = await _api.upload(
      '/shop/products/$productId/images',
      bytes: bytes,
      filename: filename,
    );
    return (data as Map<String, dynamic>)['url'] as String;
  }

  /// Retire une photo d'un produit de sa propre boutique.
  Future<void> deleteProductImage(String productId, String imageId) =>
      _api.delete('/shop/products/$productId/images/$imageId');

  /// Les produits de sa boutique, avec leurs photos.
  Future<Product> shopProduct(String productId) async {
    final items = await shopProducts();
    return items.firstWhere((p) => p.id == productId);
  }

  Future<List<Order>> myOrders() async {
    final data = await _api.get('/me/orders');
    return (data['items'] as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancelOrder(String orderId, String reason) =>
      _api.post('/me/orders/$orderId/cancel', {'reason': reason});

  // --- candidature -------------------------------------------------------
  Future<void> apply({
    required String role,
    required String activity,
    required String city,
    required String phone,
    String? vehicle,
  }) => _api.post('/me/market-application', {
    'requested_role': role,
    'activity_fr': activity,
    'city': city,
    'phone': phone,
    if (vehicle != null) 'vehicle': vehicle,
  });

  // --- artisan -----------------------------------------------------------
  Future<ShopDashboard> shop() async => ShopDashboard.fromJson(
    await _api.get('/me/shop') as Map<String, dynamic>,
  );

  Future<void> editShop({
    String? name,
    String? description,
    String? city,
    String? phone,
  }) => _api.patch('/me/shop', {
    if (name != null) 'name': name,
    if (description != null) 'description_fr': description,
    if (city != null) 'city': city,
    if (phone != null) 'phone': phone,
  });

  Future<void> openShop() => _api.post('/me/shop/open');

  Future<void> closeShop() => _api.post('/me/shop/close');

  Future<List<Product>> shopProducts() async {
    final data = await _api.get('/me/shop/products') as List;
    return data
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createProduct({
    required String title,
    required String description,
    required String category,
    required int priceXaf,
    required int stock,
    String? culturalClaim,
  }) => _api.post('/me/shop/products', {
    'title_fr': title,
    'description_fr': description,
    'category': category,
    'price_xaf': priceXaf,
    'stock': stock,
    if (culturalClaim != null && culturalClaim.isNotEmpty)
      'cultural_claim_fr': culturalClaim,
  });

  Future<void> publishProduct(String productId) =>
      _api.post('/me/shop/products/$productId/publish');

  Future<void> withdrawProduct(String productId) =>
      _api.post('/me/shop/products/$productId/withdraw');

  Future<List<Order>> shopOrders() async {
    final data = await _api.get('/me/shop/orders');
    return (data['items'] as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> confirmOrder(String orderId) =>
      _api.post('/me/shop/orders/$orderId/confirm');

  Future<void> orderReady(String orderId) =>
      _api.post('/me/shop/orders/$orderId/ready');

  // --- livreur -----------------------------------------------------------
  Future<CourierDashboard> courier() async => CourierDashboard.fromJson(
    await _api.get('/me/courier') as Map<String, dynamic>,
  );

  Future<void> editCourier({
    bool? isAvailable,
    List<String>? cities,
    String? vehicle,
  }) => _api.patch('/me/courier', {
    if (isAvailable != null) 'is_available': isAvailable,
    if (cities != null) 'cities': cities,
    if (vehicle != null) 'vehicle': vehicle,
  });

  Future<({List<Delivery> items, String message})> availableDeliveries() async {
    final data = await _api.get('/me/courier/available');
    return (
      items: (data['items'] as List)
          .map((e) => Delivery.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: data['message'] as String? ?? '',
    );
  }

  Future<List<Delivery>> myDeliveries() async {
    final data = await _api.get('/me/courier/deliveries') as List;
    return data
        .map((e) => Delivery.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptDelivery(String deliveryId) =>
      _api.post('/me/courier/deliveries/$deliveryId/accept');

  /// Fait avancer une course. `cashDeclaredXaf` est obligatoire à la remise :
  /// c'est une déclaration du livreur, pas un encaissement.
  Future<int?> advanceDelivery(
    String deliveryId, {
    required String status,
    String? note,
    int? cashDeclaredXaf,
  }) async {
    final data = await _api.post('/me/courier/deliveries/$deliveryId/status', {
      'status': status,
      if (note != null && note.isNotEmpty) 'note_fr': note,
      if (cashDeclaredXaf != null) 'cash_declared_xaf': cashDeclaredXaf,
    });
    return data['ecart_xaf'] as int?;
  }
}

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(ref.watch(apiClientProvider)),
);

/// `null` = toutes les catégories.
final marketProductsProvider = FutureProvider.family<CatalogPage, CatalogQuery>(
  (ref, query) => ref
      .watch(marketRepositoryProvider)
      .products(
        category: query.category,
        query: query.text,
        minPrice: query.minPrice,
        maxPrice: query.maxPrice,
        sort: query.sort,
      ),
);

final marketCategoriesProvider =
    FutureProvider<List<({String code, int count})>>(
      (ref) => ref.watch(marketRepositoryProvider).categories(),
    );

final productDetailProvider = FutureProvider.family<ProductDetail, String>(
  (ref, id) => ref.watch(marketRepositoryProvider).product(id),
);

final myOrdersProvider = FutureProvider<List<Order>>(
  (ref) => ref.watch(marketRepositoryProvider).myOrders(),
);

final shopProvider = FutureProvider<ShopDashboard>(
  (ref) => ref.watch(marketRepositoryProvider).shop(),
);

final shopProductsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(marketRepositoryProvider).shopProducts(),
);

final shopOrdersProvider = FutureProvider<List<Order>>(
  (ref) => ref.watch(marketRepositoryProvider).shopOrders(),
);

final courierProvider = FutureProvider<CourierDashboard>(
  (ref) => ref.watch(marketRepositoryProvider).courier(),
);

final availableDeliveriesProvider =
    FutureProvider<({List<Delivery> items, String message})>(
      (ref) => ref.watch(marketRepositoryProvider).availableDeliveries(),
    );

final myDeliveriesProvider = FutureProvider<List<Delivery>>(
  (ref) => ref.watch(marketRepositoryProvider).myDeliveries(),
);
