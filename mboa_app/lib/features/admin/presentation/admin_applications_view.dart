import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import 'admin_widgets.dart';
import 'reason_dialog.dart';

/// Demandes d'habilitation de spécialiste culturel (SS43).
///
/// C'est l'écran le plus lourd de conséquences de la console : accepter une
/// demande donne le droit de décider qu'un mot est juste. Le dossier est donc
/// affiché en entier — rapport à la langue, affiliation, personnes qui peuvent
/// en répondre — et la décision exige un motif conservé avec lui.
class AdminApplicationsView extends ConsumerStatefulWidget {
  const AdminApplicationsView({super.key});

  @override
  ConsumerState<AdminApplicationsView> createState() =>
      _AdminApplicationsViewState();
}

class _AdminApplicationsViewState extends ConsumerState<AdminApplicationsView> {
  bool _pendingOnly = true;

  Future<void> _decide(
    SpecialistApplication application,
    String decision,
  ) async {
    final reason = await askReason(
      context,
      title: switch (decision) {
        'ACCEPT' => 'Habiliter ${application.displayName}',
        'REJECT' => 'Refuser la demande',
        _ => 'Demander un complément',
      },
      action: switch (decision) {
        'ACCEPT' => 'Habiliter',
        'REJECT' => 'Refuser',
        _ => 'Demander',
      },
      hint: decision == 'ACCEPT'
          ? 'Qu’est-ce qui a été vérifié, et auprès de qui ?'
          : 'Ce motif sera visible par la personne concernée.',
    );
    if (reason == null) return;

    try {
      await ref
          .read(adminRepositoryProvider)
          .decideApplication(
            application.id,
            decision: decision,
            reason: reason,
          );
      ref.invalidate(adminApplicationsProvider);
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

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(
      adminApplicationsProvider(_pendingOnly ? 'PENDING' : null),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MboaSpace.lg,
            MboaSpace.lg,
            MboaSpace.lg,
            MboaSpace.md,
          ),
          child: AdminNotice(
            message:
                'Habiliter, c’est accorder le droit de décider qu’une forme '
                'est juste.',
            // Un `Wrap`, et deux jetons courts sans pastille d'avatar : le
            // `FilterChip` d'avant mesurait 347 px à 200 % de grossissement
            // pour 322 disponibles, et débordait de l'encart. Ici les deux
            // jetons passent simplement à la ligne.
            child: Wrap(
              spacing: MboaSpace.sm,
              runSpacing: MboaSpace.sm,
              children: [
                AdminFilterChip(
                  label: 'En attente',
                  selected: _pendingOnly,
                  onSelected: () => setState(() => _pendingOnly = true),
                ),
                AdminFilterChip(
                  label: 'Toutes',
                  selected: !_pendingOnly,
                  onSelected: () => setState(() => _pendingOnly = false),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: applications.when(
            loading: () => const AdminLoading(),
            error: (e, _) => AdminError(
              message: '$e',
              onRetry: () => ref.invalidate(adminApplicationsProvider),
            ),
            data: (list) => list.isEmpty
                ? AdminEmpty(
                    icon: Icons.how_to_reg_outlined,
                    title: _pendingOnly
                        ? 'Aucune demande en attente'
                        : 'Aucune demande',
                    message:
                        'Les apprenants qui souhaitent valider une langue '
                        'déposent leur candidature depuis leur profil.',
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(adminApplicationsProvider),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MboaSpace.lg,
                      ),
                      children: [
                        for (final application in list)
                          _ApplicationCard(
                            application: application,
                            onDecide: (decision) =>
                                _decide(application, decision),
                          ),
                        const SizedBox(height: MboaSpace.xxl),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onDecide});

  final SpecialistApplication application;
  final ValueChanged<String> onDecide;

  static const _claimedRoles = {
    'NATIVE_SPEAKER': 'Locuteur natif',
    'LINGUIST': 'Linguiste',
    'TEACHER': 'Enseignant',
    'RECORDIST': 'Preneur de son',
    'EDITOR': 'Rédacteur',
  };

  /// Le périmètre demandé, en français : le code brut ne dit rien à un jury.
  static const _scopeLabels = {
    'LEXICON': 'Lexique',
    'GRAMMAR': 'Grammaire',
    'AUDIO': 'Enregistrements',
    'CULTURE': 'Fiches culturelles',
    'EXERCISE': 'Exercices',
  };

  static const _statusLabels = {
    'PENDING': 'En attente',
    'NEEDS_INFO': 'Complément demandé',
    'ACCEPTED': 'Acceptée',
    'REJECTED': 'Refusée',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: MboaSpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Un bandeau teinté porte l'identité du demandeur : la carte ne
          // commence plus par un nom flottant au-dessus d'un mur de champs.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(MboaSpace.lg),
            decoration: const BoxDecoration(
              color: kAdminBandeau,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(MboaRadius.lg),
              ),
              border: Border(bottom: BorderSide(color: MboaColors.contour)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(application.displayName, style: text.titleLarge),
                Text(
                  application.email,
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
                const SizedBox(height: MboaSpace.md),
                Wrap(
                  spacing: MboaSpace.sm,
                  runSpacing: MboaSpace.xs,
                  children: [
                    AdminTag(
                      application.languageName,
                      color: MboaColors.forest100,
                      icon: Icons.translate_rounded,
                    ),
                    AdminTag(
                      _claimedRoles[application.claimedRole] ??
                          application.claimedRole,
                      icon: Icons.person_outline_rounded,
                    ),
                    for (final scope in application.requestedScope)
                      AdminTag(_scopeLabels[scope] ?? scope),
                    if (!application.isPending)
                      AdminTag(
                        _statusLabels[application.status] ?? application.status,
                        color: MboaColors.ocre100,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MboaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  label: 'Rapport à la langue',
                  value: application.relationship,
                ),
                if (application.affiliation != null)
                  _Field(
                    label: 'Rattachement',
                    value: application.affiliation!,
                  ),
                if (application.referees != null)
                  _Field(
                    label: 'Qui peut en répondre',
                    value: application.referees!,
                  ),
                if (application.evidenceUrl != null)
                  _Field(
                    label: 'Pièce fournie',
                    value: application.evidenceUrl!,
                  ),
                if (application.reviewNote != null)
                  _Field(
                    label: 'Motif de la décision',
                    value: application.reviewNote!,
                  ),
                if (application.isPending) ...[
                  const SizedBox(height: MboaSpace.sm),
                  const Divider(height: 1),
                  const SizedBox(height: MboaSpace.lg),
                  // Les trois décisions, dans l'ordre de leur poids : habiliter
                  // en plein, demander un complément en contour, refuser en
                  // texte. Un refus ne doit pas se cliquer par inadvertance.
                  Wrap(
                    spacing: MboaSpace.sm,
                    runSpacing: MboaSpace.sm,
                    children: [
                      FilledButton.icon(
                        onPressed: () => onDecide('ACCEPT'),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Habiliter'),
                      ),
                      OutlinedButton(
                        onPressed: () => onDecide('NEEDS_INFO'),
                        child: const Text('Demander un complément'),
                      ),
                      TextButton(
                        onPressed: () => onDecide('REJECT'),
                        child: const Text('Refuser'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: text.bodySmall?.copyWith(
              color: MboaColors.encre500,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: text.bodyMedium),
        ],
      ),
    );
  }
}
