import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../data/market_repository.dart';
import '../domain/models.dart';

const Map<String, String> kVehicleLabels = {
  'ON_FOOT': 'À pied',
  'BICYCLE': 'Vélo',
  'MOTORCYCLE': 'Moto',
  'CAR': 'Voiture',
  'VAN': 'Camionnette',
};

const Map<String, IconData> kVehicleIcons = {
  'ON_FOOT': Icons.directions_walk_rounded,
  'BICYCLE': Icons.directions_bike_rounded,
  'MOTORCYCLE': Icons.two_wheeler_rounded,
  'CAR': Icons.directions_car_rounded,
  'VAN': Icons.airport_shuttle_rounded,
};

const List<String> kAvailableCities = [
  'Douala',
  'Yaoundé',
  'Bafoussam',
  'Garoua',
  'Kribi',
  'Bamenda',
  'Buea',
];

/// Espace livreur (SS48) : interface de livraison haute définition avec navigation basse & suite d'excellence.
class CourierScreen extends ConsumerStatefulWidget {
  const CourierScreen({super.key});

  @override
  ConsumerState<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends ConsumerState<CourierScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final availableAsync = ref.watch(availableDeliveriesProvider);
    final myDeliveriesAsync = ref.watch(myDeliveriesProvider);

    final availableCount = availableAsync.value?.items.length ?? 0;
    final activeCount =
        myDeliveriesAsync.value?.where((d) => d.nextStatus != null).length ?? 0;

    return Scaffold(
      backgroundColor: MboaSection.boutique.fond,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            _DashboardTab(),
            _AvailableDeliveriesTab(),
            _MyDeliveriesTab(),
            _CourierProfileTab(),
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
          indicatorColor: MboaColors.forest100,
          elevation: 0,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(
                Icons.dashboard_rounded,
                color: MboaColors.forest700,
              ),
              label: 'Tableau de bord',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: availableCount > 0,
                label: Text('$availableCount'),
                child: const Icon(Icons.radar_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: availableCount > 0,
                label: Text('$availableCount'),
                child: const Icon(
                  Icons.radar_rounded,
                  color: MboaColors.forest700,
                ),
              ),
              label: 'Disponibles',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                child: const Icon(Icons.local_shipping_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: MboaColors.forest700,
                ),
              ),
              label: 'Mes courses',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: MboaColors.forest700,
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 0 : Tableau de bord livreur
// -----------------------------------------------------------------------------

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  Future<void> _toggleAvailability(
    WidgetRef ref,
    BuildContext context,
    bool value,
  ) async {
    try {
      await ref.read(marketRepositoryProvider).editCourier(isAvailable: value);
      ref.invalidate(courierProvider);
      ref.invalidate(availableDeliveriesProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(courierProvider);
    final text = Theme.of(context).textTheme;

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Text('$e'),
        ),
      ),
      data: (dashboard) {
        final isAvailable = dashboard.profile.isAvailable;
        final vehicleLabel =
            kVehicleLabels[dashboard.profile.vehicle] ??
            dashboard.profile.vehicle;
        final vehicleIcon =
            kVehicleIcons[dashboard.profile.vehicle] ??
            Icons.directions_bike_rounded;
        final cashDeclared = dashboard.counts['especes_declarees'] ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(courierProvider);
            ref.invalidate(availableDeliveriesProvider);
            ref.invalidate(myDeliveriesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(MboaSpace.lg),
            children: [
              // Hero Header Livreur
              Container(
                padding: const EdgeInsets.all(MboaSpace.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAvailable
                        ? [MboaColors.forest700, MboaColors.forest900]
                        : [MboaColors.encre500, MboaColors.encre900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(MboaRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isAvailable
                                  ? MboaColors.forest700
                                  : MboaColors.encre900)
                              .withValues(alpha: 0.3),
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
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            vehicleIcon,
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
                                dashboard.profile.displayName,
                                style: text.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Livreur Partenaire · $vehicleLabel',
                                style: text.bodySmall?.copyWith(
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
                            color: isAvailable
                                ? const Color(0xFF10B981)
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isAvailable
                                      ? Colors.greenAccent
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAvailable ? 'EN LIGNE' : 'HORS LIGNE',
                                style: text.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MboaSpace.lg),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: MboaSpace.md),
                    // Toggle Switch Card Inside Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isAvailable
                                ? 'Prêt à recevoir des courses à proximité'
                                : 'Passez en ligne pour recevoir des offres',
                            style: text.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: isAvailable,
                          activeTrackColor: MboaColors.or,
                          onChanged: (val) =>
                              _toggleAvailability(ref, context, val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MboaSpace.xl),

              // Bilan de Caisse & Reversement du Jour (Excellence)
              _CashRemittanceCard(cashDeclared: cashDeclared),
              const SizedBox(height: MboaSpace.xl),

              Text(
                'Performances & Statistiques',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: MboaSpace.md),

              // Metric Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: MboaSpace.md,
                mainAxisSpacing: MboaSpace.md,
                childAspectRatio: 1.45,
                children: [
                  _MetricCard(
                    value: '${dashboard.counts['livrees'] ?? 0}',
                    label: 'Courses livrées',
                    icon: Icons.task_alt_rounded,
                    color: MboaColors.forest700,
                    backgroundColor: MboaColors.forest100,
                  ),
                  _MetricCard(
                    value: '${dashboard.counts['en_cours'] ?? 0}',
                    label: 'En cours',
                    icon: Icons.local_shipping_rounded,
                    color: MboaColors.terre700,
                    backgroundColor: MboaColors.terre100,
                  ),
                  _MetricCard(
                    value: '${dashboard.counts['echouees'] ?? 0}',
                    label: 'Non abouties',
                    icon: Icons.cancel_outlined,
                    color: Colors.deepOrange,
                    backgroundColor: Colors.deepOrange.shade50,
                  ),
                  _MetricCard(
                    value: formatXaf(cashDeclared),
                    label: 'Espèces déclarées',
                    icon: Icons.payments_rounded,
                    color: MboaColors.ocre500,
                    backgroundColor: MboaColors.sable100,
                  ),
                ],
              ),
              const SizedBox(height: MboaSpace.xl),

              // Coverage & Guidelines Notice
              MboaNoteBox(
                icon: Icons.verified_user_rounded,
                tone: MboaTileTone.vert,
                title: 'Charte du Livreur MBOA',
                text: dashboard.notice.isNotEmpty
                    ? dashboard.notice
                    : 'Les livraisons s’effectuent en encaissement direct. Déclarez exactement les montants perçus.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CashRemittanceCard extends StatelessWidget {
  const _CashRemittanceCard({required this.cashDeclared});
  final int cashDeclared;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(color: MboaColors.contour),
        boxShadow: [
          BoxShadow(
            color: MboaColors.encre900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MboaColors.sable100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: MboaColors.forest700,
                  size: 22,
                ),
              ),
              const SizedBox(width: MboaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bilan de Caisse du Jour',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Espèces collectées en main propre',
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MboaSpace.md),
          const Divider(height: 1, color: MboaColors.contour),
          const SizedBox(height: MboaSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total perçu :',
                    style: text.bodyMedium?.copyWith(
                      color: MboaColors.encre500,
                    ),
                  ),
                  Text(
                    formatXaf(cashDeclared),
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MboaColors.encre900,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Commission MBOA :',
                    style: text.bodyMedium?.copyWith(
                      color: MboaColors.encre500,
                    ),
                  ),
                  Text(
                    '0 FCFA (100% Livreur)',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MboaColors.forest700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
              style: text.headlineSmall?.copyWith(
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

// -----------------------------------------------------------------------------
// TAB 1 : Courses disponibles (Radar)
// -----------------------------------------------------------------------------

class _AvailableDeliveriesTab extends ConsumerStatefulWidget {
  const _AvailableDeliveriesTab();

  @override
  ConsumerState<_AvailableDeliveriesTab> createState() =>
      _AvailableDeliveriesTabState();
}

class _AvailableDeliveriesTabState
    extends ConsumerState<_AvailableDeliveriesTab> {
  Future<void> _accept(Delivery delivery) async {
    try {
      await ref.read(marketRepositoryProvider).acceptDelivery(delivery.id);
      ref.invalidate(availableDeliveriesProvider);
      ref.invalidate(myDeliveriesProvider);
      ref.invalidate(courierProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course ${delivery.reference} acceptée !'),
            backgroundColor: MboaColors.forest700,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableAsync = ref.watch(availableDeliveriesProvider);
    final courierAsync = ref.watch(courierProvider);
    final isOnline = courierAsync.value?.profile.isAvailable ?? false;
    final text = Theme.of(context).textTheme;

    return availableAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Text('$e'),
        ),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(availableDeliveriesProvider),
        child: ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            // Radar Hero Header with Pulse Animation
            Container(
              padding: const EdgeInsets.all(MboaSpace.lg),
              decoration: BoxDecoration(
                color: MboaColors.forest100,
                borderRadius: BorderRadius.circular(MboaRadius.lg),
                border: Border.all(color: MboaColors.forest300),
              ),
              child: Row(
                children: [
                  _AnimatedRadarPulse(isOnline: isOnline),
                  const SizedBox(width: MboaSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Radar des courses MBOA',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: MboaColors.forest900,
                          ),
                        ),
                        Text(
                          !isOnline
                              ? 'Vous êtes hors ligne. Passez en ligne sur le tableau de bord.'
                              : data.items.isEmpty
                              ? 'Recherche active de colis à proximité...'
                              : '${data.items.length} course(s) disponible(s) à prendre',
                          style: text.bodySmall?.copyWith(
                            color: MboaColors.forest900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (data.message.isNotEmpty) ...[
              const SizedBox(height: MboaSpace.md),
              MboaNoteBox(
                icon: Icons.info_outline_rounded,
                tone: MboaTileTone.orange,
                text: data.message,
              ),
            ],
            const SizedBox(height: MboaSpace.lg),

            if (data.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MboaSpace.xxl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      size: 64,
                      color: MboaColors.forest300,
                    ),
                    const SizedBox(height: MboaSpace.md),
                    Text(
                      'Aucune course dans votre secteur',
                      style: text.titleMedium?.copyWith(
                        color: MboaColors.encre900,
                      ),
                    ),
                    const SizedBox(height: MboaSpace.xs),
                    Text(
                      'Dès qu’un artisan valide une commande prête à expédier, elle s’affichera instantanément ici.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final delivery in data.items)
                _AvailableCard(
                  delivery: delivery,
                  onAccept: () => _accept(delivery),
                ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedRadarPulse extends StatefulWidget {
  const _AnimatedRadarPulse({required this.isOnline});
  final bool isOnline;

  @override
  State<_AnimatedRadarPulse> createState() => _AnimatedRadarPulseState();
}

class _AnimatedRadarPulseState extends State<_AnimatedRadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Créé ici, et non en initialisation paresseuse. `build` sort avant de
    // toucher l'animation lorsque le livreur est hors ligne : le contrôleur
    // n'était alors jamais lu, et c'était `dispose()` qui déclenchait sa
    // création — sur un élément déjà désactivé. Flutter lève alors
    // « Looking up a deactivated widget's ancestor is unsafe », et l'écran
    // devient inutilisable dès qu'on le quitte hors ligne.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isOnline) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimatedRadarPulse ancien) {
    super.didUpdateWidget(ancien);
    // Le battement ne tourne que lorsqu'il se voit : une animation qui tourne
    // sous un écran hors ligne consomme de la batterie pour rien.
    if (widget.isOnline && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isOnline && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white24,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.radar_outlined,
          color: MboaColors.encre500,
          size: 28,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44 + (_controller.value * 16),
              height: 44 + (_controller.value * 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MboaColors.forest700.withValues(
                  alpha: 0.3 * (1 - _controller.value),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: MboaColors.forest700,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({required this.delivery, required this.onAccept});

  final Delivery delivery;
  final VoidCallback onAccept;

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
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MboaColors.sable100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    delivery.reference,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MboaColors.encre900,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatXaf(delivery.totalXaf),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MboaColors.terre700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.md),
            // Route Graphic (Pickup -> Dropoff)
            Row(
              children: [
                Column(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 20,
                      color: MboaColors.forest700,
                    ),
                    Container(width: 2, height: 24, color: MboaColors.contour),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: MboaColors.terre700,
                    ),
                  ],
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${delivery.shopName} (${delivery.pickupCity ?? "Origine"})',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${delivery.address} (${delivery.dropoffCity})',
                        style: text.bodyMedium?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.md),
            // Action Row (GPS / Call)
            _DeliveryActionRow(
              pickupCity: delivery.pickupCity ?? 'Origine',
              dropoffAddress: delivery.address,
              dropoffCity: delivery.dropoffCity,
              phone: delivery.shopPhone ?? delivery.deliveryPhone,
            ),
            const SizedBox(height: MboaSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: MboaColors.forest700,
                  padding: const EdgeInsets.symmetric(vertical: MboaSpace.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MboaRadius.md),
                  ),
                ),
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Accepter cette livraison',
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

// -----------------------------------------------------------------------------
// TAB 2 : Livraisons en cours
// -----------------------------------------------------------------------------

class _MyDeliveriesTab extends ConsumerStatefulWidget {
  const _MyDeliveriesTab();

  @override
  ConsumerState<_MyDeliveriesTab> createState() => _MyDeliveriesTabState();
}

class _MyDeliveriesTabState extends ConsumerState<_MyDeliveriesTab> {
  Future<void> _advance(Delivery delivery) async {
    final next = delivery.nextStatus;
    if (next == null) return;

    int? cash;
    String? note;
    if (next == 'DELIVERED') {
      final result = await showModalBottomSheet<({int cash, String note})>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MboaRadius.xl),
          ),
        ),
        builder: (_) => _HandoverSheet(delivery: delivery),
      );
      if (result == null) return;
      cash = result.cash;
      note = result.note;
    }

    try {
      await ref
          .read(marketRepositoryProvider)
          .advanceDelivery(
            delivery.id,
            status: next,
            cashDeclaredXaf: cash,
            note: note,
          );
      ref.invalidate(myDeliveriesProvider);
      ref.invalidate(courierProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _fail(Delivery delivery) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Course non aboutie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Que s’est-il passé ?',
            helperText: 'L’acheteur et l’artisan recevront votre explication.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Déclarer'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty || !mounted) return;

    try {
      await ref
          .read(marketRepositoryProvider)
          .advanceDelivery(delivery.id, status: 'FAILED', note: note);
      ref.invalidate(myDeliveriesProvider);
      ref.invalidate(courierProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(myDeliveriesProvider);
    final text = Theme.of(context).textTheme;

    return deliveriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Text('$e'),
        ),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(myDeliveriesProvider),
        child: ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            Text(
              'Mes livraisons actives',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MboaSpace.md),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MboaSpace.xxl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: MboaColors.encre400,
                    ),
                    const SizedBox(height: MboaSpace.md),
                    Text(
                      'Aucune course en cours',
                      style: text.titleMedium?.copyWith(
                        color: MboaColors.encre900,
                      ),
                    ),
                    const SizedBox(height: MboaSpace.xs),
                    Text(
                      'Acceptez une course depuis l’onglet « Disponibles » pour démarrer.',
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final delivery in list)
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MboaColors.forest100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                delivery.reference,
                                style: text.labelLarge?.copyWith(
                                  color: MboaColors.forest900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MboaColors.sable100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                delivery.label,
                                style: text.labelSmall?.copyWith(
                                  color: MboaColors.encre900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MboaSpace.md),
                        // Delivery timeline stepper
                        _DeliveryStepper(status: delivery.status ?? 'ASSIGNED'),
                        const SizedBox(height: MboaSpace.md),
                        Text(
                          'Artisan : ${delivery.shopName}',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Adresse : ${delivery.address}',
                          style: text.bodyMedium?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),

                        const SizedBox(height: MboaSpace.md),
                        // Action Row (1-Click GPS, Call & WhatsApp)
                        _DeliveryActionRow(
                          pickupCity: delivery.pickupCity ?? 'Origine',
                          dropoffAddress: delivery.address,
                          dropoffCity: delivery.dropoffCity,
                          phone: delivery.deliveryPhone ?? delivery.shopPhone,
                        ),

                        const SizedBox(height: MboaSpace.md),
                        Container(
                          padding: const EdgeInsets.all(MboaSpace.md),
                          decoration: BoxDecoration(
                            color: MboaColors.sable100,
                            borderRadius: BorderRadius.circular(MboaRadius.md),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total à encaisser :',
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatXaf(delivery.totalXaf),
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: MboaColors.terre700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (delivery.nextLabel != null) ...[
                          const SizedBox(height: MboaSpace.lg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MboaColors.forest700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: MboaSpace.md,
                                ),
                              ),
                              onPressed: () => _advance(delivery),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                delivery.nextLabel!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: MboaSpace.sm),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _fail(delivery),
                              icon: const Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Colors.deepOrange,
                              ),
                              label: const Text(
                                'Déclarer un problème / Non livrable',
                                style: TextStyle(color: Colors.deepOrange),
                              ),
                            ),
                          ),
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

// -----------------------------------------------------------------------------
// Composant d'action 1-Clic (GPS, Appel & WhatsApp)
// -----------------------------------------------------------------------------

class _DeliveryActionRow extends StatelessWidget {
  const _DeliveryActionRow({
    required this.pickupCity,
    required this.dropoffAddress,
    required this.dropoffCity,
    this.phone,
  });

  final String pickupCity;
  final String dropoffAddress;
  final String dropoffCity;
  final String? phone;

  void _launchGps(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.navigation_rounded, color: MboaColors.forest700),
            SizedBox(width: 8),
            Text('Navigation GPS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Point d’enlèvement :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MboaColors.encre900,
              ),
            ),
            Text(
              pickupCity,
              style: const TextStyle(color: MboaColors.encre500),
            ),
            const SizedBox(height: 12),
            Text(
              'Destination de livraison :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MboaColors.encre900,
              ),
            ),
            Text(
              '$dropoffAddress ($dropoffCity)',
              style: const TextStyle(color: MboaColors.encre500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MboaColors.forest700,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Lancement du GPS vers $dropoffAddress...'),
                ),
              );
            },
            icon: const Icon(Icons.map_rounded),
            label: const Text('Lancer Waze / Google Maps'),
          ),
        ],
      ),
    );
  }

  void _launchCall(BuildContext context, String number) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Composition du numéro $number...')));
  }

  void _launchWhatsApp(BuildContext context, String number) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ouverture du chat WhatsApp avec $number...'),
        backgroundColor: const Color(0xFF25D366),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetPhone = phone ?? '+237 690 000 000';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: const BorderSide(color: MboaColors.forest700),
            ),
            onPressed: () => _launchGps(context),
            icon: const Icon(
              Icons.navigation_rounded,
              size: 18,
              color: MboaColors.forest700,
            ),
            label: const Text(
              'GPS',
              style: TextStyle(
                color: MboaColors.forest700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: MboaSpace.xs),
        IconButton.filledTonal(
          style: IconButton.styleFrom(backgroundColor: MboaColors.forest100),
          onPressed: () => _launchCall(context, targetPhone),
          icon: const Icon(
            Icons.phone_rounded,
            color: MboaColors.forest700,
            size: 20,
          ),
          tooltip: 'Appeler',
        ),
        const SizedBox(width: MboaSpace.xs),
        IconButton.filledTonal(
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFDCF8C6)),
          onPressed: () => _launchWhatsApp(context, targetPhone),
          icon: const Icon(
            Icons.chat_rounded,
            color: Color(0xFF075E54),
            size: 20,
          ),
          tooltip: 'WhatsApp',
        ),
      ],
    );
  }
}

class _DeliveryStepper extends StatelessWidget {
  const _DeliveryStepper({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    int currentStep = switch (status) {
      'ASSIGNED' => 1,
      'PICKED_UP' => 2,
      'IN_TRANSIT' => 3,
      'DELIVERED' => 4,
      _ => 1,
    };

    return Row(
      children: [
        _StepCircle(step: 1, current: currentStep, label: 'Accepté'),
        Expanded(
          child: Container(
            height: 3,
            color: currentStep >= 2 ? MboaColors.forest700 : MboaColors.contour,
          ),
        ),
        _StepCircle(step: 2, current: currentStep, label: 'Récupéré'),
        Expanded(
          child: Container(
            height: 3,
            color: currentStep >= 3 ? MboaColors.forest700 : MboaColors.contour,
          ),
        ),
        _StepCircle(step: 3, current: currentStep, label: 'En route'),
        Expanded(
          child: Container(
            height: 3,
            color: currentStep >= 4 ? MboaColors.forest700 : MboaColors.contour,
          ),
        ),
        _StepCircle(step: 4, current: currentStep, label: 'Livré'),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.step,
    required this.current,
    required this.label,
  });
  final int step;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final active = step <= current;
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? MboaColors.forest700 : Colors.white,
            border: Border.all(
              color: active ? MboaColors.forest700 : MboaColors.contour,
              width: 2,
            ),
          ),
          child: Center(
            child: active
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$step',
                    style: const TextStyle(
                      fontSize: 10,
                      color: MboaColors.encre500,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3 : Profil Livreur & Gestion des Zones / Véhicule
// -----------------------------------------------------------------------------

class _CourierProfileTab extends ConsumerWidget {
  const _CourierProfileTab();

  Future<void> _editVehicle(
    BuildContext context,
    WidgetRef ref,
    String currentVehicle,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Changer de véhicule'),
        children: [
          for (final entry in kVehicleLabels.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(entry.key),
              child: Row(
                children: [
                  Icon(
                    kVehicleIcons[entry.key] ?? Icons.directions_bike_rounded,
                    color: MboaColors.forest700,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (entry.key == currentVehicle) ...[
                    const Spacer(),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: MboaColors.forest700,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    if (selected != null && selected != currentVehicle) {
      try {
        await ref.read(marketRepositoryProvider).editCourier(vehicle: selected);
        ref.invalidate(courierProvider);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(courierProvider);
    final text = Theme.of(context).textTheme;

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Text('$e'),
        ),
      ),
      data: (dashboard) {
        final p = dashboard.profile;
        final vehicleLabel = kVehicleLabels[p.vehicle] ?? p.vehicle;
        final vehicleIcon =
            kVehicleIcons[p.vehicle] ?? Icons.directions_bike_rounded;

        return ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            Text(
              'Profil Livreur & Configuration',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MboaSpace.lg),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MboaRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MboaSpace.lg),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: MboaColors.forest100,
                      child: Icon(
                        vehicleIcon,
                        size: 36,
                        color: MboaColors.forest700,
                      ),
                    ),
                    const SizedBox(height: MboaSpace.md),
                    Text(
                      p.displayName,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Livreur vérifié MBOA · $vehicleLabel',
                      style: text.bodyMedium?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                    if (p.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.phone!,
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.forest700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: MboaSpace.md),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: MboaColors.forest700),
                      ),
                      onPressed: () => _editVehicle(context, ref, p.vehicle),
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: MboaColors.forest700,
                      ),
                      label: const Text(
                        'Modifier le véhicule',
                        style: TextStyle(
                          color: MboaColors.forest700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MboaSpace.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Zones de couverture',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vos zones actuelles sont actives.'),
                      ),
                    );
                  },
                  child: const Text(
                    'Gérer les villes',
                    style: TextStyle(color: MboaColors.forest700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.sm),
            Wrap(
              spacing: MboaSpace.sm,
              children: [
                for (final city in p.cities)
                  Chip(
                    avatar: const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: MboaColors.forest700,
                    ),
                    label: Text(city),
                    backgroundColor: MboaColors.sable100,
                  ),
              ],
            ),
            const SizedBox(height: MboaSpace.xl),

            const MboaNoteBox(
              icon: Icons.shield_outlined,
              tone: MboaTileTone.indigo,
              title: 'Engagement Qualité MBOA',
              text:
                  'MBOA garantit la transparence des livraisons d’artisanat local. Chaque remise s’effectue de main à main avec vérification directe.',
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Sheet de remise du colis
// -----------------------------------------------------------------------------

class _HandoverSheet extends StatefulWidget {
  const _HandoverSheet({required this.delivery});
  final Delivery delivery;

  @override
  State<_HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<_HandoverSheet> {
  late final TextEditingController _cash = TextEditingController(
    text: '${widget.delivery.totalXaf}',
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _cash.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_cash.text.trim());
  int? get _gap => _amount == null ? null : _amount! - widget.delivery.totalXaf;

  bool get _isValid {
    if (_amount == null || _amount! < 0) return false;
    if (_gap != 0 && _note.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gap = _gap;

    return Padding(
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
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: MboaColors.forest700,
                size: 28,
              ),
              const SizedBox(width: MboaSpace.sm),
              Text(
                'Remise du colis',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: MboaSpace.xs),
          Text(
            'Indiquez la somme que vous avez reçue de l’acheteur.',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
          const SizedBox(height: MboaSpace.md),
          // Ce que le livreur saisit est une **déclaration**, pas un
          // encaissement. MBOA n'a pas d'entité juridique ni de compte
          // marchand : elle ne touche pas cet argent et n'atteste pas du
          // montant. La mention était tombée lors d'une refonte de cet écran ;
          // sans elle, la saisie ressemble à une caisse, ce qu'elle n'est pas.
          Container(
            padding: const EdgeInsets.all(MboaSpace.md),
            decoration: BoxDecoration(
              color: MboaColors.ocre100,
              borderRadius: BorderRadius.circular(MboaRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: MboaColors.encre900,
                ),
                const SizedBox(width: MboaSpace.sm),
                Expanded(
                  child: Text(
                    'Les espèces déclarées sont ce que vous avez saisi avoir '
                    'reçu. MBOA n’encaisse rien et ne certifie pas ce montant.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MboaSpace.lg),
          Container(
            padding: const EdgeInsets.all(MboaSpace.md),
            decoration: BoxDecoration(
              color: MboaColors.sable100,
              borderRadius: BorderRadius.circular(MboaRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Montant attendu :', style: text.bodyLarge),
                Text(
                  formatXaf(widget.delivery.totalXaf),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MboaColors.terre700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MboaSpace.lg),
          TextField(
            controller: _cash,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Somme reçue (FCFA)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          if (gap != null && gap != 0) ...[
            const SizedBox(height: MboaSpace.sm),
            Text(
              'Écart de ${gap > 0 ? '+' : ''}$gap FCFA — explication requise.',
              style: text.bodyMedium?.copyWith(
                color: MboaColors.terre700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: MboaSpace.sm),
            TextField(
              controller: _note,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Raison de la différence',
                hintText:
                    'Ex: Remise accordée par le vendeur, monnaie restante, etc.',
              ),
            ),
          ],
          const SizedBox(height: MboaSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MboaColors.forest700,
                padding: const EdgeInsets.symmetric(vertical: MboaSpace.md),
              ),
              onPressed: _isValid
                  ? () => Navigator.of(
                      context,
                    ).pop((cash: _amount!, note: _note.text.trim()))
                  : null,
              child: const Text(
                'Confirmer la livraison & la remise',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
