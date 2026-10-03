import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_header.dart';
import '../../../design/widgets/mboa_header_tabs.dart';
import '../../auth/auth_controller.dart';
import '../data/admin_repository.dart';
import 'admin_applications_view.dart';
import 'admin_audit_view.dart';
import 'admin_dashboard_view.dart';
import 'admin_settings_view.dart';
import 'admin_users_view.dart';

/// Console d'administration (SS43, SS44).
///
/// L'accès est refusé côté serveur à tout compte non administrateur ; le garde
/// posé ici évite seulement d'afficher une coquille vide à quelqu'un qui
/// arriverait sur l'adresse par hasard.
///
/// **Pourquoi la console n'a qu'une couleur.** Les cinq onglets de
/// l'application publique en ont chacun une, parce qu'elles disent où l'on se
/// trouve dans un parcours. La console était restée sans aucune : elle héritait
/// de l'`AppBar` grise de Material sur un fond blanc, ce qui en faisait le seul
/// endroit de l'application à ne ressembler à rien. Elle porte désormais le
/// même indigo profond sur ses cinq onglets — un espace, une couleur — et
/// cette couleur est plus sombre que toutes les autres pour qu'on sache, au
/// premier coup d'œil, qu'on n'est plus du côté de l'apprenant.
class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen>
    with SingleTickerProviderStateMixin {
  static const _section = MboaSection.administration;
  static const _nombreOnglets = 5;

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _nombreOnglets, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(sessionProvider).isAdmin) return const _Forbidden();

    // Le tableau de bord est déjà chargé par son propre onglet : on se greffe
    // sur le même fournisseur pour poser les compteurs sur les pastilles, sans
    // seconde requête. Tant qu'il charge, les pastilles n'affichent rien —
    // mieux vaut pas de nombre qu'un zéro qui dirait « rien à faire ».
    final tableau = ref.watch(adminDashboardProvider).value;
    final aRelire = tableau == null
        ? null
        : (tableau.workload['mots_a_relire'] as int? ?? 0) +
              (tableau.workload['exercices_a_relire'] as int? ?? 0) +
              (tableau.workload['fiches_a_relire'] as int? ?? 0);
    final demandes = tableau?.workload['demandes_habilitation'] as int?;

    return Scaffold(
      backgroundColor: _section.fond,
      body: Column(
        children: [
          MboaGradientHeader(
            title: 'Administration',
            subtitle: tableau == null
                ? 'Comptes, habilitations, intégrité du corpus'
                : '${tableau.pendingDecisions} décision(s) en attente',
            section: _section,
            leading: const MboaHeaderBack(),
            actions: [
              MboaHeaderAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Recharger les données de la console',
                onPressed: () {
                  ref
                    ..invalidate(adminDashboardProvider)
                    ..invalidate(adminUsersProvider)
                    ..invalidate(adminApplicationsProvider)
                    ..invalidate(adminSettingsProvider)
                    ..invalidate(adminAuditProvider);
                },
              ),
            ],
            child: MboaHeaderTabs(
              controller: _tabs,
              section: _section,
              tabs: [
                MboaHeaderTab(
                  icon: Icons.insights_rounded,
                  label: 'Tableau de bord',
                  badge: aRelire,
                ),
                const MboaHeaderTab(
                  icon: Icons.people_alt_rounded,
                  label: 'Comptes',
                ),
                MboaHeaderTab(
                  icon: Icons.how_to_reg_rounded,
                  label: 'Demandes',
                  badge: demandes,
                ),
                const MboaHeaderTab(
                  icon: Icons.tune_rounded,
                  label: 'Paramètres',
                ),
                const MboaHeaderTab(
                  icon: Icons.receipt_long_rounded,
                  label: 'Journal',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                AdminDashboardView(),
                AdminUsersView(),
                AdminApplicationsView(),
                AdminSettingsView(),
                AdminAuditView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Forbidden extends StatelessWidget {
  const _Forbidden();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MboaSection.administration.fond,
      body: Column(
        children: [
          const MboaGradientHeader(
            title: 'Administration',
            section: MboaSection.administration,
            leading: MboaHeaderBack(),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(MboaSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: MboaColors.encre400,
                    ),
                    const SizedBox(height: MboaSpace.md),
                    Text(
                      'Cet espace est réservé aux administrateurs.',
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: MboaSpace.xs),
                    Text(
                      'Le serveur refuse de toute façon ces données à un '
                      'compte qui n’a pas le rôle : cet écran ne fait que le '
                      'dire plus clairement.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
