import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import 'admin_widgets.dart';
import 'reason_dialog.dart';

const Map<String, String> kRoleLabels = {
  'LEARNER': 'Apprenant',
  'CULTURAL_SPECIALIST': 'Spécialiste culturel',
  'ARTISAN': 'Artisan',
  'COURIER': 'Livreur',
  'ADMIN': 'Administrateur',
};

/// Couleur de la pastille d'initiales, par rôle.
///
/// Elle n'ajoute pas d'information que l'étiquette ne donne pas déjà : c'est un
/// repère de balayage dans une longue liste. L'étiquette textuelle reste donc
/// présente sous chaque nom, et rien ne dépend de la seule couleur.
const Map<String, Color> _roleTones = {
  'LEARNER': MboaColors.indigo100,
  'CULTURAL_SPECIALIST': MboaColors.forest100,
  'ARTISAN': MboaColors.terre100,
  'COURIER': MboaColors.ocre100,
  'ADMIN': Color(0xFFE2E8F0),
};

/// Gestion des comptes (SS43).
class AdminUsersView extends ConsumerStatefulWidget {
  const AdminUsersView({super.key});

  @override
  ConsumerState<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends ConsumerState<AdminUsersView> {
  final _controller = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAuditProvider);
      ref.invalidate(adminDashboardProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _changeRole(AdminUser user) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MboaRadius.xl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MboaSpace.lg,
                MboaSpace.lg,
                MboaSpace.lg,
                MboaSpace.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nouveau rôle',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    user.displayName,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: MboaColors.encre500),
                  ),
                ],
              ),
            ),
            for (final entry in kRoleLabels.entries)
              if (entry.key != user.role)
                ListTile(
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _roleTones[entry.key] ?? MboaColors.sable100,
                      shape: BoxShape.circle,
                      border: Border.all(color: MboaColors.contour),
                    ),
                  ),
                  title: Text(entry.value),
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
            const SizedBox(height: MboaSpace.sm),
          ],
        ),
      ),
    );
    if (role == null || !mounted) return;

    final reason = await askReason(
      context,
      title: 'Changer le rôle de ${user.displayName}',
      action: 'Confirmer',
      hint: role == 'CULTURAL_SPECIALIST'
          // Le rôle ne suffit pas : il faut ensuite une habilitation par langue.
          ? 'Sur quel dossier ce compte devient-il spécialiste ?'
          : null,
    );
    if (reason == null) return;
    await _run(
      () => ref
          .read(adminRepositoryProvider)
          .changeRole(user.id, role: role, reason: reason),
    );
  }

  Future<void> _toggleStatus(AdminUser user) async {
    final reason = await askReason(
      context,
      title: user.isActive
          ? 'Désactiver ${user.displayName}'
          : 'Réactiver ${user.displayName}',
      action: user.isActive ? 'Désactiver' : 'Réactiver',
      hint: user.isActive
          ? 'La session en cours sera coupée immédiatement.'
          : null,
    );
    if (reason == null) return;
    await _run(
      () => ref
          .read(adminRepositoryProvider)
          .changeStatus(user.id, isActive: !user.isActive, reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(_query));
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MboaSpace.lg,
            MboaSpace.lg,
            MboaSpace.lg,
            MboaSpace.md,
          ),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => setState(() {
              final q = value.trim();
              _query = q.isEmpty ? null : q;
            }),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Chercher un compte (nom ou e-mail)',
              // Un champ de recherche n'a pas besoin de la hauteur d'un champ
              // de saisie de formulaire : il est le haut de l'écran, pas son
              // contenu.
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: MboaSpace.md,
              ),
              suffixIcon: _query == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Effacer la recherche',
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = null);
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: users.when(
            loading: () => const AdminLoading(),
            error: (e, _) => AdminError(
              message: '$e',
              onRetry: () => ref.invalidate(adminUsersProvider),
            ),
            data: (list) => list.isEmpty
                ? AdminEmpty(
                    icon: Icons.person_search_rounded,
                    title: _query == null
                        ? 'Aucun compte'
                        : 'Aucun compte ne correspond.',
                    message: _query == null
                        ? 'La base ne contient encore aucun compte.'
                        : 'La recherche porte sur le nom affiché et '
                              'l’adresse électronique.',
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(adminUsersProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        MboaSpace.lg,
                        0,
                        MboaSpace.lg,
                        MboaSpace.xxl,
                      ),
                      // Un en-tête de liste plutôt qu'un titre de panneau : il
                      // dit combien de comptes la recherche a ramenés, ce qui
                      // était invisible jusqu'ici.
                      itemCount: list.length + 1,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: MboaSpace.md),
                      itemBuilder: (context, i) => i == 0
                          ? Padding(
                              padding: const EdgeInsets.only(
                                bottom: MboaSpace.xs,
                              ),
                              child: Text(
                                _query == null
                                    ? '${list.length} compte(s)'
                                    : '${list.length} résultat(s) pour « $_query »',
                                style: text.bodySmall?.copyWith(
                                  color: MboaColors.encre500,
                                ),
                              ),
                            )
                          : _UserCard(
                              user: list[i - 1],
                              onChangeRole: () => _changeRole(list[i - 1]),
                              onToggleStatus: () => _toggleStatus(list[i - 1]),
                            ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onChangeRole,
    required this.onToggleStatus,
  });

  final AdminUser user;
  final VoidCallback onChangeRole;
  final VoidCallback onToggleStatus;

  /// Les initiales du nom affiché, deux au plus.
  ///
  /// Le nom peut ne contenir qu'un mot, ou commencer par une espace : on filtre
  /// avant de prendre la première lettre, sinon la pastille affiche du vide.
  static String _initiales(String nom) {
    final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    if (mots.isEmpty) return '?';
    return mots.take(2).map((m) => m.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final actif = user.isActive;

    return Opacity(
      // Un compte désactivé reste lisible, mais recule : il n'est plus une
      // ligne comme les autres.
      opacity: actif ? 1 : 0.72,
      child: Container(
        padding: const EdgeInsets.all(MboaSpace.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MboaRadius.lg),
          border: Border.all(color: MboaColors.contour),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _roleTones[user.role] ?? MboaColors.sable100,
                shape: BoxShape.circle,
                border: Border.all(color: MboaColors.contour),
              ),
              child: Text(
                _initiales(user.displayName),
                style: text.titleMedium?.copyWith(
                  // encre900 mesuré sur les cinq pastilles : de 14,41:1
                  // (ardoise des administrateurs) à 15,95:1 (ocre des
                  // livreurs). Aucune n'approche le seuil.
                  color: MboaColors.encre900,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: MboaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: text.titleMedium),
                  Text(
                    user.email,
                    style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                  ),
                  const SizedBox(height: MboaSpace.sm),
                  Wrap(
                    spacing: MboaSpace.sm,
                    runSpacing: MboaSpace.xs,
                    children: [
                      AdminTag(kRoleLabels[user.role] ?? user.role),
                      if (user.habilitations > 0)
                        AdminTag(
                          '${user.habilitations} langue(s) habilitée(s)',
                          color: MboaColors.forest100,
                          icon: Icons.verified_outlined,
                        ),
                      if (!actif)
                        const AdminTag(
                          'Désactivé',
                          color: MboaColors.terre100,
                          icon: Icons.block_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions sur ce compte',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: MboaColors.encre500,
              ),
              onSelected: (value) =>
                  value == 'role' ? onChangeRole() : onToggleStatus(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'role',
                  child: Text('Changer le rôle'),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: Text(
                    actif ? 'Désactiver le compte' : 'Réactiver le compte',
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
