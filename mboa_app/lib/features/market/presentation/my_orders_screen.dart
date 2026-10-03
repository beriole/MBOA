import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/market_repository.dart';
import '../domain/models.dart';
import 'claim_badge.dart';

/// Suivi des commandes de l'acheteur (SS47, SS48).
class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  Future<void> _cancel(Order order) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler ${order.reference}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motif',
            helperText: 'L’artisan le verra : il a peut-être déjà commencé.',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Revenir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Annuler la commande'),
          ),
        ],
      ),
    );
    if (reason == null || reason.length < 5 || !mounted) return;

    try {
      await ref.read(marketRepositoryProvider).cancelOrder(order.id, reason);
      ref.invalidate(myOrdersProvider);
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
    final orders = ref.watch(myOrdersProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myOrdersProvider),
          child: ListView(
            padding: const EdgeInsets.all(MboaSpace.lg),
            children: [
              if (list.isEmpty)
                Text(
                  'Aucune commande pour l’instant.',
                  style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
                )
              else
                for (final order in list)
                  _OrderCard(order: order, onCancel: () => _cancel(order)),
              const SizedBox(height: MboaSpace.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onCancel});

  final Order order;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: MboaSpace.md),
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(order.shopName, style: text.titleMedium)),
                Text(formatXaf(order.totalXaf), style: text.titleMedium),
              ],
            ),
            Text(
              order.reference,
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            const SizedBox(height: MboaSpace.sm),
            for (final line in order.lines)
              Text('${line.quantity} × ${line.title}', style: text.bodyMedium),
            const SizedBox(height: MboaSpace.sm),
            _StatusChip(order: order),
            // Une commande de démonstration doit se voir d'emblée, pas
            // seulement une fois livrée : rien n'a été payé, et rien ne le sera.
            if (order.isSimulated) ...[
              const SizedBox(height: MboaSpace.sm),
              const _SimulationTag(),
            ],
            if (order.cancelReason != null) ...[
              const SizedBox(height: MboaSpace.sm),
              Text(
                '« ${order.cancelReason!} »',
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
            ],
            if (order.timeline.isNotEmpty) ...[
              const SizedBox(height: MboaSpace.md),
              _Timeline(steps: order.timeline),
            ],
            if (order.courierName != null) ...[
              const SizedBox(height: MboaSpace.sm),
              Text(
                'Livreur : ${order.courierName}'
                '${order.courierPhone == null ? '' : ' · ${order.courierPhone}'}',
                style: text.bodySmall,
              ),
            ],
            if (order.isCancellable) ...[
              const SizedBox(height: MboaSpace.md),
              OutlinedButton(onPressed: onCancel, child: const Text('Annuler')),
            ],
            if (order.status == 'DELIVERED') ...[
              const SizedBox(height: MboaSpace.md),
              PaymentNotice(
                // La mention vient du serveur quand il la fournit : elle
                // diffère selon le règlement, et la recomposer ici risquerait
                // d'annoncer des espèces là où rien n'a été payé.
                notice: order.paymentNotice.isNotEmpty
                    ? order.paymentNotice
                    : 'Le règlement s’est fait en espèces, au livreur. '
                          'MBOA n’a encaissé aucune somme et n’en certifie pas '
                          'le montant.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      'DELIVERED' => MboaColors.succes,
      'CANCELLED' => MboaColors.terre700,
      'IN_DELIVERY' => MboaColors.info,
      _ => MboaColors.encre500,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MboaColors.sable100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

/// Suivi de la course, tel que le livreur l'a renseigné — pas une estimation.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<DeliveryStep> steps;

  static const _labels = {
    'ASSIGNED': 'Course acceptée par un livreur',
    'PICKED_UP': 'Colis récupéré chez l’artisan',
    'IN_TRANSIT': 'En route vers vous',
    'DELIVERED': 'Remis',
    'FAILED': 'Course non aboutie',
  };

  static String _time(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}h${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.circle, size: 8, color: MboaColors.forest500),
                const SizedBox(width: MboaSpace.sm),
                Expanded(
                  child: Text(
                    _labels[step.status] ?? step.status,
                    style: text.bodySmall,
                  ),
                ),
                Text(
                  _time(step.at),
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// L'étiquette d'une commande de démonstration.
///
/// Elle est volontairement voyante. Une commande simulée suit exactement le
/// même parcours qu'une vraie ; sans marque visible, un artisan préparerait un
/// colis contre rien.
class _SimulationTag extends StatelessWidget {
  const _SimulationTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MboaColors.terre100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 14,
            color: MboaColors.terre700,
          ),
          const SizedBox(width: 6),
          Text(
            'Paiement simulé — aucun argent échangé',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
