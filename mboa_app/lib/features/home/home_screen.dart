import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/tokens.dart';
import '../../design/widgets/mboa_header.dart';
import '../../design/widgets/mboa_tiles.dart';
import '../auth/auth_controller.dart';
import '../learning/data/learning_repository.dart';
import '../learning/domain/models.dart';
import '../progress/progress_providers.dart';
import 'home_carousels.dart';

/// Accueil apprenant (SS22), d'après la planche « Lot 4 ».
///
/// La maquette pose un en-tête dégradé qui salue la personne et porte ses
/// compteurs, puis une carte de reprise, l'objectif du jour, les révisions et
/// des accès rapides. On garde cette structure, avec nos données réelles : ni
/// recommandation inventée, ni module annoncé qui n'existe pas.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final progress = ref.watch(progressProvider);
    final path = ref.watch(pathProvider);
    final language = ref.watch(selectedLanguageProvider);
    final snapshot = progress.value;

    return Scaffold(
      // Le fond porte la teinte de la section : sans elle, toutes les
      // pages se ressemblaient, uniformément blanches.
      backgroundColor: MboaSection.accueil.fond,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressProvider);
          ref.invalidate(pathProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            MboaGradientHeader(
              title:
                  'Bonjour${session.displayName == null ? '' : ' ${session.displayName}'}',
              subtitle: snapshot == null
                  ? 'Bienvenue dans MBOA'
                  : 'Continuons notre apprentissage',
              leading: _Avatar(name: session.displayName ?? ''),
              actions: [
                MboaHeaderAction(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Les notifications ne sont pas encore branchées.',
                      ),
                    ),
                  ),
                ),
              ],
              child: snapshot == null
                  ? null
                  : Row(
                      children: [
                        Expanded(
                          child: MboaStat(
                            value: '${snapshot.streakDays}',
                            label: 'jours de suite',
                            icon: Icons.local_fire_department_rounded,
                            onLight: true,
                          ),
                        ),
                        const SizedBox(width: MboaSpace.sm),
                        Expanded(
                          child: MboaStat(
                            value: '${snapshot.totalXp}',
                            label: 'XP',
                            icon: Icons.star_rounded,
                            onLight: true,
                          ),
                        ),
                        const SizedBox(width: MboaSpace.sm),
                        Expanded(
                          child: MboaStat(
                            value: '${snapshot.lessonsCompleted}',
                            label: 'leçons',
                            icon: Icons.school_rounded,
                            onLight: true,
                          ),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(MboaSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  path.when(
                    loading: () => const _CardSkeleton(height: 170),
                    error: (e, _) => _Message(text: '$e'),
                    data: (p) => p == null
                        ? const _Message(
                            text: 'Choisis une langue pour commencer.',
                          )
                        : _ContinueCard(
                            languageName: language.value?.name ?? '',
                            path: p,
                          ),
                  ),
                  const SizedBox(height: MboaSpace.lg),
                  progress.when(
                    loading: () => const _CardSkeleton(height: 110),
                    error: (e, _) => _Message(text: '$e'),
                    data: (p) => _DailyGoalCard(progress: p),
                  ),
                  const SizedBox(height: MboaSpace.lg),
                  progress.maybeWhen(
                    data: (p) => _ReviewCard(progress: p),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: MboaSpace.xl),
                  Text(
                    'Découvrir MBOA',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MboaSpace.md),
                  const _QuickActions(),
                  const SizedBox(height: MboaSpace.xxl),
                  // Ce qui existe ailleurs dans l'application. Chaque bandeau se
                  // tait s'il n'a rien à montrer : promettre du contenu absent
                  // serait pire qu'une section manquante.
                  const HeritageCarousel(),
                  const SizedBox(height: MboaSpace.xxl),
                  const MarketCarousel(),
                  const SizedBox(height: MboaSpace.xxl),
                  const _Footer(),
                  const SizedBox(height: MboaSpace.xxxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 24,
    backgroundColor: Colors.white24,
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: Colors.white),
    ),
  );
}

/// Carte de reprise, verte comme dans la maquette, avec la progression réelle.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.languageName, required this.path});
  final String languageName;
  final LearningPath path;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final next = path.nextLesson;
    final unit = next == null ? null : path.unitOf(next);
    final total = path.allLessons.length;
    final ratio = total == 0 ? 0.0 : path.completedCount / total;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MboaColors.forest900, MboaColors.forest700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(MboaRadius.lg),
      ),
      padding: const EdgeInsets.all(MboaSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTINUER L’APPRENTISSAGE',
            style: text.bodySmall?.copyWith(
              color: MboaColors.forest100,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MboaSpace.sm),
          Text(
            languageName,
            style: text.headlineMedium?.copyWith(color: Colors.white),
          ),
          if (unit != null)
            Text(
              unit.title,
              style: text.bodyLarge?.copyWith(color: MboaColors.forest100),
            ),
          const SizedBox(height: MboaSpace.lg),
          Semantics(
            label: 'Progression : ${(ratio * 100).round()} pour cent',
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MboaRadius.sm),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      color: MboaColors.or,
                    ),
                  ),
                ),
                const SizedBox(width: MboaSpace.sm),
                Text(
                  '${(ratio * 100).round()} %',
                  style: text.labelLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: MboaSpace.lg),
          if (next != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: MboaColors.or,
                foregroundColor: MboaColors.encre900,
              ),
              onPressed: () => context.push('/lesson/${next.id}'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(next.title, overflow: TextOverflow.ellipsis),
            )
          else
            Text(
              'Tu as terminé toutes les leçons publiées. De nouvelles arrivent '
              'après validation.',
              style: text.bodyMedium?.copyWith(color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.progress});
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Row(
          children: [
            Semantics(
              label:
                  'Objectif du jour : ${progress.todayXp} sur ${progress.dailyGoalXp} XP',
              child: SizedBox.square(
                dimension: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress.goalRatio,
                      strokeWidth: 7,
                      backgroundColor: MboaColors.sable100,
                      color: progress.goalReached
                          ? MboaColors.succes
                          : MboaColors.ocre500,
                    ),
                    Center(
                      child: Icon(
                        progress.goalReached
                            ? Icons.check_rounded
                            : Icons.bolt_rounded,
                        color: progress.goalReached
                            ? MboaColors.succes
                            : MboaColors.ocre500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MboaSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Objectif du jour', style: text.titleLarge),
                  Text(
                    progress.goalReached
                        ? 'Atteint : ${progress.todayXp} XP aujourd\'hui.'
                        : '${progress.todayXp} / ${progress.dailyGoalXp} XP',
                    style: text.bodyMedium?.copyWith(
                      color: MboaColors.encre500,
                    ),
                  ),
                  Text(
                    '${progress.totalXp} XP au total',
                    style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.progress});
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final weak = progress.mastery['WEAK'] ?? 0;
    final due = progress.itemsDue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MboaIconTile(
                  icon: Icons.replay_rounded,
                  tone: MboaTileTone.rose,
                  size: 36,
                ),
                const SizedBox(width: MboaSpace.md),
                // Expanded : le titre doit pouvoir passer à la ligne sur un
                // écran étroit ou avec un texte agrandi.
                Expanded(
                  child: Text('À réviser aujourd’hui', style: text.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.sm),
            Text(
              due > 0
                  ? '$due mot(s) à revoir aujourd\'hui, les plus fragiles d\'abord.'
                  : weak > 0
                  ? '$weak mot(s) fragile(s) reviendront demain.'
                  : 'Rien à réviser pour l\'instant.',
              style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
            ),
            const SizedBox(height: MboaSpace.md),
            if (due > 0)
              OutlinedButton(
                onPressed: () => context.push('/review'),
                child: const Text('Réviser maintenant'),
              ),
            // Outil de démonstration : visible seulement en développement.
            if (kDebugMode && due == 0 && weak > 0)
              TextButton.icon(
                onPressed: () async {
                  await ref.read(learningRepositoryProvider).advanceDay();
                  ref.invalidate(progressProvider);
                },
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Démo : passer au lendemain'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grille d'accès rapides, comme la maquette « Découvrir MBOA ».
///
/// Une tuile sans route dit qu'elle n'est pas ouverte plutôt que de disparaître :
/// le périmètre réel de l'application reste lisible.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    (Icons.menu_book_rounded, 'Apprendre', '/learn', MboaTileTone.indigo),
    (Icons.museum_outlined, 'Culture', '/culture', MboaTileTone.ambre),
    (Icons.translate_rounded, 'Traduction', '/translate', MboaTileTone.bleu),
    (Icons.storefront_outlined, 'Boutique', '/shop', MboaTileTone.orange),
    (
      Icons.workspace_premium_outlined,
      'Attestations',
      '/certificates',
      MboaTileTone.vert,
    ),
    (Icons.smart_toy_outlined, 'Assistant', null, MboaTileTone.rose),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: MboaSpace.md,
      crossAxisSpacing: MboaSpace.md,
      childAspectRatio: 0.95,
      children: [
        for (final (icon, label, route, tone) in _actions)
          Semantics(
            button: route != null,
            label: route == null ? '$label, pas encore disponible' : label,
            child: InkWell(
              borderRadius: BorderRadius.circular(MboaRadius.md),
              onTap: route == null ? null : () => context.push(route),
              child: Container(
                padding: const EdgeInsets.all(MboaSpace.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(MboaRadius.md),
                  border: Border.all(color: MboaColors.contour),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MboaIconTile(icon: icon, tone: tone, size: 44),
                    const SizedBox(height: MboaSpace.sm),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: route == null
                            ? MboaColors.encre400
                            : MboaColors.encre900,
                      ),
                    ),
                    if (route == null)
                      Text(
                        'bientôt',
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: MboaColors.sable100,
      borderRadius: BorderRadius.circular(MboaRadius.lg),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(MboaSpace.lg),
      child: Text(text),
    ),
  );
}

/// Le pied de l'accueil : ce que MBOA est, en une phrase.
///
/// L'accueil se terminait sur une grille de raccourcis, sans rien qui rappelle
/// la règle du projet. Elle mérite d'être lisible là où l'on arrive : elle
/// explique pourquoi certaines pages sont volontairement vides.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: MboaColors.forest100,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 20,
                color: MboaColors.forest700,
              ),
              const SizedBox(width: MboaSpace.sm),
              Expanded(
                child: Text(
                  'Ce que vous lisez est sourcé',
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MboaSpace.xs),
          Text(
            'Chaque mot porte une source et une validation humaine. Chaque '
            'enregistrement porte son auteur et sa licence. Là où rien n’a '
            'encore été vérifié, MBOA laisse la page vide plutôt que de la '
            'remplir.',
            style: text.bodySmall?.copyWith(color: MboaColors.forest900),
          ),
        ],
      ),
    );
  }
}
