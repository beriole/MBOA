import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/tokens.dart';
import '../../design/widgets/audio_button.dart';
import '../../design/widgets/feedback_bar.dart';
import '../culture/presentation/culture_card_view.dart';
import '../exercises/exercise_view.dart';
import '../learning/data/learning_repository.dart';
import '../progress/progress_providers.dart';
import 'lesson_session_controller.dart';

/// Lecteur de leçon (et de révision). Sessions courtes : 3 à 7 minutes (SS11).
class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({super.key, this.lessonId});

  /// Null = mode révision.
  final String? lessonId;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  late final LessonSessionController _session;

  /// Conserve a l'initialisation : lire un provider dans `dispose()` est
  /// interdit, le widget etant deja detache de son contexte.
  late final AudioService _audio;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    final repo = ref.read(learningRepositoryProvider);
    _session = widget.lessonId == null
        ? LessonSessionController.review(repo)
        : LessonSessionController.lesson(repo, widget.lessonId!);
    _session.addListener(_onChange);
    _session.load();
  }

  void _onChange() {
    if (!mounted) return;
    if (_session.phase == SessionPhase.done) {
      // La progression a changé côté serveur : on rafraîchit ce qui l'affiche.
      ref.invalidate(progressProvider);
      ref.invalidate(pathProvider);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_onChange);
    _session.dispose();
    _audio.stop();
    super.dispose();
  }

  Future<void> _confirmQuit() async {
    if (_session.phase == SessionPhase.done) return context.pop();
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la leçon ?'),
        content: const Text('Tes réponses déjà données sont enregistrées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (quit == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quitter',
          icon: const Icon(Icons.close_rounded),
          onPressed: _confirmQuit,
        ),
        title:
            s.phase == SessionPhase.intro ||
                s.phase == SessionPhase.done ||
                s.phase == SessionPhase.culture
            ? null
            : _ProgressBar(
                value: s.progress,
                label: '${s.index} sur ${s.exercises.length}',
              ),
      ),
      body: switch (s.phase) {
        SessionPhase.loading || SessionPhase.finishing => const Center(
          child: CircularProgressIndicator(),
        ),
        SessionPhase.error => _ErrorView(
          message: s.errorMessage,
          onRetry: s.load,
        ),
        SessionPhase.intro => _IntroView(session: s),
        SessionPhase.culture => CultureCardView(
          card: s.lesson!.cultureCard!,
          onContinue: s.dismissCulture,
        ),
        SessionPhase.done =>
          s.isReview ? _ReviewDoneView(session: s) : _ResultView(session: s),
        _ => _ExerciseStage(session: s),
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.label});
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progression : $label',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: MboaMotion.standard,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: 12,
          backgroundColor: MboaColors.sable100,
          color: MboaColors.forest500,
        ),
      ),
    ),
  );
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.session});
  final LessonSessionController session;

  @override
  Widget build(BuildContext context) {
    final lesson = session.lesson!;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(MboaSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(
            Icons.headphones_rounded,
            size: 72,
            color: MboaColors.forest500,
          ),
          const SizedBox(height: MboaSpace.xl),
          Text(
            lesson.introTitle,
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (lesson.introSubtitle != null) ...[
            const SizedBox(height: MboaSpace.sm),
            Text(
              lesson.introSubtitle!,
              style: text.bodyLarge?.copyWith(color: MboaColors.encre500),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: MboaSpace.lg),
          Text(
            lesson.unitObjective,
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MboaSpace.sm),
          Text(
            '${session.exercises.length} exercices · ${lesson.xpReward} XP',
            style: text.labelLarge?.copyWith(color: MboaColors.forest700),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            onPressed: session.begin,
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseStage extends StatelessWidget {
  const _ExerciseStage({required this.session});
  final LessonSessionController session;

  @override
  Widget build(BuildContext context) {
    final exercise = session.current!;
    final result = session.result;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              MboaSpace.lg,
              MboaSpace.lg,
              MboaSpace.lg,
              MboaSpace.xl,
            ),
            child: AbsorbPointer(
              absorbing: session.phase == SessionPhase.submitting,
              child: KeyedSubtree(
                key: ValueKey(exercise.id),
                child: buildExerciseView(
                  exercise: exercise,
                  onSubmit: session.submit,
                  result: result,
                  selectedId: session.selectedId,
                ),
              ),
            ),
          ),
        ),
        if (session.errorMessage != null && result == null)
          Padding(
            padding: const EdgeInsets.all(MboaSpace.lg),
            child: Text(
              session.errorMessage!,
              style: const TextStyle(color: MboaColors.erreur),
            ),
          ),
        AnimatedSwitcher(
          duration: MboaMotion.quick,
          transitionBuilder: (child, anim) =>
              SizeTransition(sizeFactor: anim, child: child),
          child: result == null
              ? const SizedBox.shrink()
              : FeedbackBar(
                  key: ValueKey('fb-${exercise.id}'),
                  isCorrect: result.isCorrect,
                  xpDelta: result.xpDelta,
                  correctAnswerLabel: result.isCorrect
                      ? null
                      : correctLabelFor(exercise, result),
                  explanation: result.isCorrect
                      ? null
                      : (result.explanation ?? result.detail),
                  onContinue: session.next,
                ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.session});
  final LessonSessionController session;

  @override
  Widget build(BuildContext context) {
    final summary = session.summary!;
    final text = Theme.of(context).textTheme;
    final percent = (summary.score * 100).round();

    return Padding(
      padding: const EdgeInsets.all(MboaSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: MboaMotion.celebrate,
            curve: Curves.elasticOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 88,
              color: MboaColors.ocre500,
            ),
          ),
          const SizedBox(height: MboaSpace.lg),
          Text(
            'Leçon terminée',
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MboaSpace.xl),
          Row(
            children: [
              _Stat(
                label: 'Réussite',
                value: '$percent %',
                color: MboaColors.forest500,
              ),
              const SizedBox(width: MboaSpace.md),
              _Stat(
                label: 'XP gagnés',
                value: '+${summary.xpAwarded + session.xpEarned}',
                color: MboaColors.ocre500,
              ),
              const SizedBox(width: MboaSpace.md),
              _Stat(
                label: 'Série',
                value: '${summary.streakDays} j',
                color: MboaColors.terre700,
              ),
            ],
          ),
          const SizedBox(height: MboaSpace.xl),
          if (summary.itemsToReview > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(MboaSpace.lg),
                child: Row(
                  children: [
                    const Icon(
                      Icons.replay_rounded,
                      color: MboaColors.forest700,
                    ),
                    const SizedBox(width: MboaSpace.md),
                    Expanded(
                      child: Text(
                        '${summary.itemsToReview} mot(s) à revoir. Ils reviendront dans ta révision de demain : une erreur ne disparaît pas.',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
}

class _ReviewDoneView extends StatelessWidget {
  const _ReviewDoneView({required this.session});
  final LessonSessionController session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final empty = session.exercises.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(MboaSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            empty
                ? Icons.check_circle_outline_rounded
                : Icons.auto_awesome_rounded,
            size: 80,
            color: MboaColors.forest500,
          ),
          const SizedBox(height: MboaSpace.lg),
          Text(
            empty ? 'Rien à réviser pour l\'instant' : 'Révision terminée',
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MboaSpace.sm),
          Text(
            empty
                ? 'Les mots travaillés reviennent au bon moment, selon la répétition espacée.'
                : '${session.correctCount} sur ${session.exercises.length} retrouvés. Les autres reviendront demain.',
            style: text.bodyLarge?.copyWith(color: MboaColors.encre500),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: MboaSpace.lg),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(MboaSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 56,
            color: MboaColors.encre500,
          ),
          const SizedBox(height: MboaSpace.md),
          Text(
            message ?? 'Une erreur est survenue.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MboaSpace.lg),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}
