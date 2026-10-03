import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import 'admin_users_view.dart' show kRoleLabels;
import 'admin_widgets.dart';

/// Journal des actes d'administration (SS44).
///
/// En lecture seule, et c'est le propos : aucun bouton n'efface une ligne. Un
/// journal qu'on peut nettoyer ne prouve rien.
class AdminAuditView extends ConsumerWidget {
  const AdminAuditView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(adminAuditProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminAuditProvider),
      child: entries.when(
        loading: () => const AdminLoading(),
        error: (e, _) => AdminError(
          message: '$e',
          onRetry: () => ref.invalidate(adminAuditProvider),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            const AdminNotice(
              message:
                  'Chaque acte d’administration est inscrit ici avec son '
                  'auteur et son motif. Aucune fonction ne permet d’en '
                  'effacer une ligne.',
            ),
            const SizedBox(height: MboaSpace.lg),
            if (list.isEmpty)
              const AdminEmpty(
                icon: Icons.receipt_long_rounded,
                title: 'Aucun acte enregistré pour l’instant.',
                message:
                    'La première décision prise dans cette console '
                    'apparaîtra ici, avec son motif.',
              )
            else
              // Un filet vertical relie les actes : on lit une chronologie, pas
              // une pile de blocs indépendants.
              for (final (i, entry) in list.indexed)
                _AuditTile(entry: entry, dernier: i == list.length - 1),
            const SizedBox(height: MboaSpace.xxl),
          ],
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry, required this.dernier});
  final AuditEntry entry;
  final bool dernier;

  static String _date(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}h${two(d.minute)}';
  }

  /// Un changement de role s'affiche avec le nom des roles, pas leur code.
  static String _readable(String action, Object value) =>
      action == 'USER_ROLE_CHANGED'
      ? kRoleLabels['$value'] ?? '$value'
      : '$value';

  /// Icône et couleur par famille d'acte.
  ///
  /// Un refus et une habilitation ne se survolent pas de la même façon : le
  /// journal doit se parcourir à l'œil avant de se lire.
  static (IconData, Color) _marque(String action) => switch (action) {
    'APPLICATION_ACCEPTED' => (Icons.verified_user_rounded, MboaColors.succes),
    'APPLICATION_REJECTED' => (Icons.person_off_rounded, MboaColors.erreur),
    'APPLICATION_NEEDS_INFO' => (
      Icons.help_outline_rounded,
      MboaColors.ocre500,
    ),
    'USER_ROLE_CHANGED' => (Icons.swap_horiz_rounded, MboaColors.info),
    'USER_STATUS_CHANGED' => (Icons.toggle_off_rounded, MboaColors.terre700),
    'SETTING_CHANGED' => (Icons.tune_rounded, MboaColors.indigo600),
    'HABILITATION_GRANTED' => (Icons.key_rounded, MboaColors.succes),
    'HABILITATION_REVOKED' => (Icons.key_off_rounded, MboaColors.terre700),
    _ => (Icons.history_rounded, MboaColors.encre500),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final before = entry.details['avant'];
    final after = entry.details['apres'];
    final (icone, couleur) = _marque(entry.action);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: couleur, width: 1.5),
              ),
              child: Icon(icone, size: 17, color: couleur),
            ),
            if (!dernier)
              Container(
                width: 2,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: MboaColors.contour,
              ),
          ],
        ),
        const SizedBox(width: MboaSpace.md),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: MboaSpace.md),
            padding: const EdgeInsets.all(MboaSpace.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MboaRadius.lg),
              border: Border.all(color: MboaColors.contour),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Le libellé et la date se mettent l'un sous l'autre plutôt
                // que de se disputer la ligne : sur un téléphone, la date
                // écrasait le libellé jusqu'à le couper.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: MboaSpace.sm,
                  children: [
                    Text(
                      entry.label,
                      style: text.titleMedium?.copyWith(color: couleur),
                    ),
                    Text(
                      _date(entry.createdAt),
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
                if (entry.targetLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(entry.targetLabel!, style: text.bodySmall),
                  ),
                if (before != null && after != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MboaSpace.sm),
                    // Pas d'icone de fleche : le libelle en contient deja
                    // une, et la pastille affichait « → Apprenant → Admin ».
                    child: AdminTag(
                      '${_readable(entry.action, before)} → '
                      '${_readable(entry.action, after)}',
                    ),
                  ),
                const SizedBox(height: MboaSpace.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(MboaSpace.sm),
                  decoration: BoxDecoration(
                    color: MboaSection.administration.fond,
                    borderRadius: BorderRadius.circular(MboaRadius.sm),
                  ),
                  // Pas d'italique : seule la graisse variable d'Inter est
                  // embarquée, et Flutter en fabriquerait une oblique de
                  // synthèse — un faux italique, plus laid que du droit.
                  child: Text('« ${entry.reason} »', style: text.bodyMedium),
                ),
                const SizedBox(height: MboaSpace.xs),
                Text(
                  'par ${entry.actor}',
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
