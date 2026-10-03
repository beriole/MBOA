import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/mboa_header.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../../progress/progress_providers.dart';
import '../domain/models.dart';

/// Chemin vertical (SS23). L'utilisateur doit toujours savoir où il est,
/// ce qu'il vient de terminer et ce qui vient ensuite.
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(pathProvider);
    final language = ref.watch(selectedLanguageProvider);

    return Scaffold(
      // Le fond porte la teinte de la section : sans elle, toutes les
      // pages se ressemblaient, uniformément blanches.
      backgroundColor: MboaSection.apprendre.fond,
      body: path.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Aucune langue choisie.'));
          }
          final next = p.nextLesson;
          final total = p.allLessons.length;
          final done = p.completedCount;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pathProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: MboaSpace.lg),
              children: [
                // En-tete degrade du lot 5 : la langue, puis ce qui est
                // reellement acquis. Aucun chiffre n'est arrondi a la hausse.
                MboaGradientHeader(
                  section: MboaSection.apprendre,
                  title: language.value?.name ?? 'Apprendre',
                  subtitle: '${p.courseTitle} · niveau ${p.level}',
                  child: Row(
                    children: [
                      Expanded(
                        child: MboaStat(
                          value: '$done / $total',
                          label: 'leçons terminées',
                          icon: Icons.menu_book_rounded,
                          onLight: true,
                        ),
                      ),
                      const SizedBox(width: MboaSpace.sm),
                      Expanded(
                        child: MboaStat(
                          value: '${p.sections.length}',
                          label: 'sections',
                          icon: Icons.flag_rounded,
                          onLight: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MboaSpace.lg),
                for (final (sIndex, section) in p.sections.indexed) ...[
                  _SectionBanner(index: sIndex + 1, section: section),
                  for (final unit in section.units) ...[
                    _UnitHeader(unit: unit),
                    for (final (lIndex, lesson) in unit.lessons.indexed)
                      _PathNodeTile(
                        lesson: lesson,
                        isNext: lesson.id == next?.id,
                        // Léger zigzag : le chemin se lit comme un parcours, pas comme une liste.
                        offset: const [0.0, 0.35, 0.0, -0.35][lIndex % 4],
                        isLast: lIndex == unit.lessons.length - 1,
                      ),
                  ],
                ],
                const _UpcomingNode(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionBanner extends StatelessWidget {
  const _SectionBanner({required this.index, required this.section});
  final int index;
  final SectionNode section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.all(MboaSpace.lg),
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: MboaSection.apprendre.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MboaSection.apprendre.debut.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECTION $index',
            style: text.labelLarge?.copyWith(
              color: MboaColors.forest100,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            section.title,
            style: text.titleLarge?.copyWith(color: Colors.white),
          ),
          if (section.objective != null)
            Text(
              section.objective!,
              style: text.bodyMedium?.copyWith(color: MboaColors.forest100),
            ),
        ],
      ),
    );
  }
}

class _UnitHeader extends StatelessWidget {
  const _UnitHeader({required this.unit});
  final UnitNode unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final faites = unit.lessons
        .where((l) => l.status == NodeStatus.completed)
        .length;
    final total = unit.lessons.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MboaSpace.lg,
        0,
        MboaSpace.lg,
        MboaSpace.lg,
      ),
      child: Container(
        padding: const EdgeInsets.all(MboaSpace.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MboaRadius.lg),
          border: Border.all(color: MboaColors.contour),
          boxShadow: kMboaCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MboaColors.forest100,
                    borderRadius: BorderRadius.circular(MboaRadius.sm),
                  ),
                  child: const Icon(
                    Icons.playlist_play_rounded,
                    color: MboaColors.forest700,
                  ),
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(unit.title, style: text.titleMedium),
                      Text(
                        '$faites leçon${faites > 1 ? 's' : ''} sur $total',
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : faites / total,
                minHeight: 8,
                backgroundColor: MboaColors.sable100,
                valueColor: const AlwaysStoppedAnimation(MboaColors.forest500),
              ),
            ),
            const SizedBox(height: MboaSpace.sm),
            Text(
              unit.objective,
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathNodeTile extends StatelessWidget {
  const _PathNodeTile({
    required this.lesson,
    required this.isNext,
    required this.offset,
    required this.isLast,
  });

  final LessonNode lesson;
  final bool isNext;
  final double offset;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final locked = lesson.status == NodeStatus.locked;
    final done = lesson.status == NodeStatus.completed;

    final (color, icon, statusLabel) = switch (lesson.status) {
      NodeStatus.completed => (
        MboaColors.ocre500,
        Icons.check_rounded,
        'terminée',
      ),
      NodeStatus.locked => (
        MboaColors.sable600,
        Icons.lock_rounded,
        'verrouillée',
      ),
      _ => (
        MboaColors.forest500,
        switch (lesson.kind) {
          'REVIEW' => Icons.star_rounded,
          'CHECKPOINT' => Icons.emoji_events_rounded,
          _ => Icons.headphones_rounded,
        },
        'disponible',
      ),
    };

    return Column(
      children: [
        Align(
          alignment: Alignment(offset, 0),
          child: Semantics(
            button: !locked,
            label:
                'Leçon ${lesson.title}, $statusLabel'
                '${lesson.bestScore != null && done ? ', meilleur score ${(lesson.bestScore! * 100).round()} %' : ''}',
            child: Column(
              children: [
                if (isNext)
                  Container(
                    margin: const EdgeInsets.only(bottom: MboaSpace.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MboaColors.forest500, width: 2),
                    ),
                    child: const Text(
                      'COMMENCER',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: MboaColors.forest700,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isNext)
                        BoxShadow(
                          color: MboaColors.forest500.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 4,
                        )
                      else if (done)
                        BoxShadow(
                          color: MboaColors.ocre500.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Material(
                    color: locked ? MboaColors.sable100 : color,
                    shape: CircleBorder(
                      side: isNext
                          ? const BorderSide(
                              color: MboaColors.forest100,
                              width: 6,
                            )
                          : BorderSide.none,
                    ),
                    elevation: locked ? 0 : 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: locked
                          ? null
                          : () => context.push('/lesson/${lesson.id}'),
                      child: SizedBox.square(
                        dimension: 76,
                        child: Icon(
                          icon,
                          size: 34,
                          color: locked ? MboaColors.sable600 : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MboaSpace.xs),
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  '${lesson.minutes} min · ${lesson.xp} XP',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) const SizedBox(height: MboaSpace.xl),
      ],
    );
  }
}

/// Montre que la suite existe et pourquoi elle n'est pas encore là.
class _UpcomingNode extends StatelessWidget {
  const _UpcomingNode();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(MboaSpace.xl),
    child: Column(
      children: [
        const Icon(Icons.more_vert_rounded, color: MboaColors.sable600),
        const SizedBox(height: MboaSpace.sm),
        Container(
          padding: const EdgeInsets.all(MboaSpace.lg),
          decoration: BoxDecoration(
            color: MboaColors.sable100,
            borderRadius: BorderRadius.circular(MboaRadius.md),
          ),
          child: Text(
            'Les prochaines unités seront publiées dès que leurs contenus auront été validés par des locuteurs natifs.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
        ),
      ],
    ),
  );
}
