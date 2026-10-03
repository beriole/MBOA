import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// Le choix du règlement, au moment de commander.
///
/// Deux options sont ouvertes, et **aucune des deux ne fait transiter d'argent
/// par MBOA**. La plateforme n'a ni entité juridique ni compte marchand : elle
/// ne peut pas encaisser, et ne prétend pas le faire. Le mobile money et la
/// carte sont refusés par le serveur tant qu'ils ne sont pas réellement
/// raccordés — un moyen de paiement affiché mais non branché ferait perdre de
/// l'argent à quelqu'un.
///
/// La caisse de démonstration existe pour qu'on puisse parcourir l'achat d'un
/// bout à l'autre sans rien payer. Elle est nommée en toutes lettres plutôt que
/// derrière un mot flou comme « test », et l'avertissement reste affiché tant
/// qu'elle est sélectionnée : l'artisan qui reçoit la commande voit la même
/// mention, puisque c'est lui qui préparerait le colis.
class PaymentChoice extends StatelessWidget {
  const PaymentChoice({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const cashOnDelivery = 'CASH_ON_DELIVERY';
  static const simulation = 'SIMULATION';

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // `RadioGroup` porte la valeur et le changement pour tout le groupe :
    // depuis Flutter 3.32, les passer tuile par tuile est déprécié.
    return RadioGroup<String>(
      groupValue: value,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(
        children: [
          RadioListTile<String>(
            value: cashOnDelivery,
            contentPadding: EdgeInsets.zero,
            title: const Text('Espèces à la livraison'),
            subtitle: Text(
              'Vous payez le livreur à la remise. MBOA n’encaisse rien et ne '
              'demande aucune donnée bancaire.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ),
          RadioListTile<String>(
            value: simulation,
            contentPadding: EdgeInsets.zero,
            title: const Text('Paiement simulé (démonstration)'),
            subtitle: Text(
              'Pour essayer le parcours d’achat sans rien payer. Aucun argent '
              'n’est échangé, et la commande porte cette mention jusqu’au bout.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ),
          if (value == simulation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MboaSpace.md),
              decoration: BoxDecoration(
                color: MboaColors.terre100,
                borderRadius: BorderRadius.circular(MboaRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.science_outlined,
                    size: 18,
                    color: MboaColors.terre700,
                  ),
                  const SizedBox(width: MboaSpace.sm),
                  Expanded(
                    child: Text(
                      'L’artisan verra que cette commande est une démonstration et '
                      'ne préparera pas d’envoi réel.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
