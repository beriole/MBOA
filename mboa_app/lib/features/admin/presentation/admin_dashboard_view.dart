import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import 'admin_widgets.dart';

/// Tableau de bord (SS44).
///
/// L'intégrité passe avant l'activité : la première chose qu'on voit n'est pas
/// le nombre d'utilisateurs, c'est de savoir si un contenu publié échappe aux
/// règles. Un nombre d'inscrits flatteur au-dessus d'un corpus non sourcé
/// serait un tableau de bord mensonger.
class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminDashboardProvider),
      child: dashboard.when(
        loading: () => const AdminLoading(),
        error: (e, _) => AdminError(
          message: '$e',
          onRetry: () => ref.invalidate(adminDashboardProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            _IntegrityPanel(dashboard: data),
            const SizedBox(height: MboaSpace.lg),
            AdminPanel(
              title: 'À traiter',
              subtitle: data.pendingDecisions == 0
                  ? 'Aucune file d’attente.'
                  : '${data.pendingDecisions} élément(s) attendent une décision '
                        'humaine.',
              icon: Icons.pending_actions_rounded,
              child: _WorkloadGrid(workload: data.workload),
            ),
            const SizedBox(height: MboaSpace.lg),
            AdminPanel(
              title: 'Corpus par langue',
              icon: Icons.translate_rounded,
              child: data.languages.isEmpty
                  ? const _Nothing(
                      'Aucune langue ne contient encore de corpus.',
                    )
                  : Column(
                      children: [
                        for (final lang in data.languages)
                          _LanguageRow(corpus: lang),
                      ],
                    ),
            ),
            const SizedBox(height: MboaSpace.lg),
            AdminPanel(
              title: 'Licences du contenu diffusé',
              subtitle:
                  'Sous quelles conditions MBOA rediffuse, et qui créditer.',
              icon: Icons.copyright_rounded,
              child: Column(
                children: [
                  for (final line in data.licences) _LicenceRow(line: line),
                ],
              ),
            ),
            const SizedBox(height: MboaSpace.lg),
            AdminPanel(
              title: 'Comptes et usage',
              icon: Icons.bar_chart_rounded,
              child: _UsageGrid(dashboard: data),
            ),
            const SizedBox(height: MboaSpace.lg),
            AdminPanel(
              title: 'Ce qui n’est pas encore administrable',
              subtitle:
                  'Une console qui prétend tout gérer se découvre en réunion. '
                  'Ces modules ne sont pas branchés, et voici pourquoi.',
              icon: Icons.construction_rounded,
              child: Column(
                children: [
                  for (final item in data.openWork) _OpenWorkRow(item: item),
                ],
              ),
            ),
            const SizedBox(height: MboaSpace.xxl),
          ],
        ),
      ),
    );
  }
}

/// Le verdict d'intégrité, en tête et en grand.
///
/// Les contrôles ne sont plus une liste de petites lignes grises : chacun est
/// une ligne cadrée, avec son compteur à droite, et le fond change selon que
/// tout tient ou non.
class _IntegrityPanel extends StatelessWidget {
  const _IntegrityPanel({required this.dashboard});
  final AdminDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clean = dashboard.isClean;

    return AdminNotice(
      tone: clean ? AdminNoticeTone.bon : AdminNoticeTone.alerte,
      title: clean
          ? 'Aucun contenu publié n’échappe aux règles'
          : '${dashboard.anomalies} contenu(s) hors règles',
      message:
          'Ces contrôles interrogent la base directement. Les règles sont '
          'posées par des déclencheurs PostgreSQL : cet écran vérifie qu’ils '
          'tiennent.',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MboaRadius.md),
          border: Border.all(color: MboaColors.contour),
        ),
        child: Column(
          children: [
            for (final (i, check) in dashboard.checks.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MboaSpace.md,
                  vertical: MboaSpace.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      check.isClean
                          ? Icons.check_circle_rounded
                          : Icons.priority_high_rounded,
                      size: 18,
                      color: check.isClean
                          ? MboaColors.succes
                          : MboaColors.erreur,
                    ),
                    const SizedBox(width: MboaSpace.md),
                    Expanded(child: Text(check.label, style: text.bodyMedium)),
                    const SizedBox(width: MboaSpace.sm),
                    Text(
                      '${check.anomalies}',
                      style: text.labelLarge?.copyWith(
                        color: check.isClean
                            ? MboaColors.encre500
                            : MboaColors.erreur,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkloadGrid extends StatelessWidget {
  const _WorkloadGrid({required this.workload});
  final Map<String, dynamic> workload;

  /// Libellé, icône, et si un compteur non nul signale un retard.
  ///
  /// Les habilitations actives ne sont pas une file d'attente : c'est un état,
  /// et il ne passe donc jamais en rouge.
  static const _lignes = [
    (
      key: 'mots_a_relire',
      label: 'Mots à relire',
      icon: Icons.spellcheck_rounded,
      file: true,
    ),
    (
      key: 'exercices_a_relire',
      label: 'Exercices à relire',
      icon: Icons.quiz_outlined,
      file: true,
    ),
    (
      key: 'fiches_a_relire',
      label: 'Fiches à relire',
      icon: Icons.article_outlined,
      file: true,
    ),
    (
      key: 'demandes_habilitation',
      label: 'Demandes d’habilitation',
      icon: Icons.how_to_reg_rounded,
      file: true,
    ),
    (
      key: 'habilitations_actives',
      label: 'Habilitations actives',
      icon: Icons.verified_user_outlined,
      file: false,
    ),
  ];

  @override
  Widget build(BuildContext context) => AdminStatGrid(
    children: [
      for (final ligne in _lignes)
        AdminStat(
          value: '${workload[ligne.key] ?? 0}',
          label: ligne.label,
          icon: ligne.icon,
          alert: ligne.file && (workload[ligne.key] as int? ?? 0) > 0,
        ),
    ],
  );
}

class _UsageGrid extends StatelessWidget {
  const _UsageGrid({required this.dashboard});
  final AdminDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final activity = dashboard.activity;
    final content = dashboard.content;
    return AdminStatGrid(
      children: [
        AdminStat(
          value: '${dashboard.accounts}',
          label: 'Comptes',
          icon: Icons.people_alt_outlined,
        ),
        AdminStat(
          value: '${dashboard.accountsByRole['CULTURAL_SPECIALIST'] ?? 0}',
          label: 'Spécialistes',
          icon: Icons.school_outlined,
        ),
        AdminStat(
          value: '${content['exercices_publies'] ?? 0}',
          label: 'Exercices publiés',
          icon: Icons.quiz_outlined,
        ),
        AdminStat(
          value: '${content['fiches_publiees'] ?? 0}',
          label: 'Fiches culturelles',
          icon: Icons.museum_outlined,
        ),
        AdminStat(
          value: '${content['rubriques_vides'] ?? 0}',
          label: 'Rubriques encore vides',
          icon: Icons.inbox_outlined,
        ),
        AdminStat(
          value: '${activity['tentatives'] ?? 0}',
          label: 'Réponses d’apprenants',
          icon: Icons.touch_app_outlined,
        ),
        AdminStat(
          value: '${activity['traductions'] ?? 0}',
          label: 'Traductions demandées',
          icon: Icons.g_translate_outlined,
        ),
        AdminStat(
          value: '${activity['traductions_sans_reponse'] ?? 0}',
          label: 'Traductions sans réponse',
          icon: Icons.mark_email_unread_outlined,
          alert: (activity['traductions_sans_reponse'] as int? ?? 0) > 0,
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.corpus});
  final LanguageCorpus corpus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pourcent = (corpus.publishedRatio * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${corpus.name} (${corpus.iso})',
                  style: text.titleMedium,
                ),
              ),
              // Le pourcentage avant le ratio : c'est la grandeur qu'on
              // compare d'une langue à l'autre.
              AdminTag('$pourcent % publié'),
            ],
          ),
          const SizedBox(height: MboaSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(MboaRadius.sm),
            child: LinearProgressIndicator(
              value: corpus.publishedRatio,
              minHeight: 10,
              backgroundColor: MboaColors.sable100,
              color: MboaColors.forest500,
            ),
          ),
          const SizedBox(height: MboaSpace.sm),
          Text(
            '${corpus.published} / ${corpus.total} publiés · '
            '${corpus.pending} en attente de relecture · '
            '${corpus.withoutGloss} sans traduction',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
        ],
      ),
    );
  }
}

class _LicenceRow extends StatelessWidget {
  const _LicenceRow({required this.line});
  final LicenceLine line;

  /// Nom lisible des licences : le code brut ne parle qu'aux initiés.
  static const _labels = {
    'CC0': 'CC0 — domaine public',
    'CC_BY': 'CC BY — attribution',
    'CC_BY_SA': 'CC BY-SA — partage à l’identique',
    'CC_BY_NC': 'CC BY-NC — usage non commercial',
    'PUBLIC_DOMAIN': 'Domaine public',
    'COPYRIGHT_AGREEMENT': 'Sous licence négociée',
    'COPYRIGHT_NO_AGREEMENT': 'Sous droit d’auteur, sans accord',
    'NOODL': 'NOODL — licence ouverte',
    'UNKNOWN': 'Licence inconnue',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Une source sous droit d'auteur sans accord ne peut servir que de
    // référence bibliographique : jamais de matière publiée.
    final restricted =
        line.licence == 'COPYRIGHT_NO_AGREEMENT' || line.licence == 'UNKNOWN';

    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: restricted ? MboaColors.terre100 : MboaColors.forest100,
              borderRadius: BorderRadius.circular(MboaRadius.sm),
            ),
            child: Icon(
              restricted ? Icons.lock_outline_rounded : Icons.public_rounded,
              size: 16,
              color: restricted ? MboaColors.terre700 : MboaColors.forest700,
            ),
          ),
          const SizedBox(width: MboaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labels[line.licence] ?? line.licence,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${line.sources} source(s) · ${line.publishedWords} mots',
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenWorkRow extends StatelessWidget {
  const _OpenWorkRow({required this.item});
  final OpenWork item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.area, style: text.titleMedium),
          const SizedBox(height: MboaSpace.xs),
          // L'état sous le titre, et non à sa droite : « non implémenté » est
          // aussi long que le nom du module, et les deux se disputaient la
          // ligne jusqu'à la faire déborder.
          AdminTag(item.state, color: MboaColors.ocre100),
          const SizedBox(height: MboaSpace.sm),
          Text(
            item.reason,
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
        ],
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: MboaColors.encre500),
  );
}
