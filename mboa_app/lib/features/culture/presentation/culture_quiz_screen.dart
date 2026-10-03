import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/audio_button.dart';
import '../../../design/widgets/mboa_header.dart';
import '../../../design/widgets/mboa_tiles.dart';
import '../data/culture_repository.dart';
import '../domain/models.dart';
import 'culture_widgets.dart';

/// Quiz culturel (lot 9, écran 10).
///
/// Chaque question est tirée d'une fiche publiée, donc sourcée et validée ; la
/// correction vient du serveur et renvoie la fiche et sa source, pour qu'on
/// puisse vérifier l'affirmation plutôt que de la croire.
class CultureQuizScreen extends ConsumerStatefulWidget {
  const CultureQuizScreen({super.key});

  @override
  ConsumerState<CultureQuizScreen> createState() => _CultureQuizScreenState();
}

class _CultureQuizScreenState extends ConsumerState<CultureQuizScreen> {
  int _index = 0;
  int _correct = 0;
  String? _selected;
  QuizVerdict? _verdict;
  bool _checking = false;

  Future<void> _answer(QuizQuestion question, QuizChoice choice) async {
    if (_verdict != null || _checking) return;
    setState(() {
      _selected = choice.id;
      _checking = true;
    });
    try {
      final verdict = await ref
          .read(cultureRepositoryProvider)
          .answer(question.id, choice.id);
      setState(() {
        _verdict = verdict;
        if (verdict.isCorrect) _correct++;
      });
    } on ApiException catch (e) {
      setState(() => _selected = null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _next(int total) {
    setState(() {
      _index++;
      _selected = null;
      _verdict = null;
    });
    if (_index >= total) return;
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correct = 0;
      _selected = null;
      _verdict = null;
    });
    ref.invalidate(cultureQuizProvider);
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(cultureQuizProvider);

    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: quiz.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          if (data.isEmpty) return _NoQuestion(message: data.message);
          if (_index >= data.questions.length) {
            return _Result(
              correct: _correct,
              total: data.questions.length,
              onRestart: _restart,
            );
          }
          return _Question(
            question: data.questions[_index],
            index: _index,
            total: data.questions.length,
            message: data.message,
            selected: _selected,
            verdict: _verdict,
            checking: _checking,
            onChoose: (choice) => _answer(data.questions[_index], choice),
            onNext: () => _next(data.questions.length),
          );
        },
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.question,
    required this.index,
    required this.total,
    required this.message,
    required this.selected,
    required this.verdict,
    required this.checking,
    required this.onChoose,
    required this.onNext,
  });

  final QuizQuestion question;
  final int index;
  final int total;
  final String message;
  final String? selected;
  final QuizVerdict? verdict;
  final bool checking;
  final ValueChanged<QuizChoice> onChoose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        MboaGradientHeader(
          section: MboaSection.culture,
          title: 'Quiz culturel',
          subtitle: 'Question ${index + 1} sur $total',
          leading: const MboaHeaderBack(),
          child: Semantics(
            label: 'Progression : ${index + 1} sur $total',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MboaRadius.sm),
              child: LinearProgressIndicator(
                value: (index + 1) / total,
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: MboaColors.or,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.prompt, style: text.headlineMedium),
              if (question.audioUrl != null) ...[
                const SizedBox(height: MboaSpace.lg),
                Container(
                  padding: const EdgeInsets.all(MboaSpace.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(MboaRadius.lg),
                    border: Border.all(color: MboaColors.contour),
                  ),
                  child: Row(
                    children: [
                      AudioButton(url: question.audioUrl!, size: 64),
                      const SizedBox(width: MboaSpace.md),
                      Expanded(
                        child: Text(
                          'Écoutez, puis choisissez le mot. Vous pouvez '
                          'réécouter autant de fois que nécessaire.',
                          style: text.bodySmall?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: MboaSpace.lg),
              for (var i = 0; i < question.choices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: MboaSpace.md),
                  child: _ChoiceTile(
                    choice: question.choices[i],
                    letter: String.fromCharCode(65 + i),
                    selected: selected == question.choices[i].id,
                    // Tant qu'aucune réponse n'est donnée, aucune proposition n'est
                    // marquée : la bonne réponse n'est pas connue du client.
                    revealed: verdict != null,
                    isCorrect: verdict != null && verdict!.correctId == question.choices[i].id,
                    enabled: verdict == null && !checking,
                    onTap: () => onChoose(question.choices[i]),
                  ),
                ),
              if (verdict != null) ...[
                const SizedBox(height: MboaSpace.md),
                _Verdict(verdict: verdict!),
                const SizedBox(height: MboaSpace.lg),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text(
                    index + 1 >= total ? 'Voir mon résultat' : 'Question suivante',
                  ),
                ),
              ],
              const SizedBox(height: MboaSpace.lg),
              Text(
                message,
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
              const SizedBox(height: MboaSpace.xxl),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.choice,
    required this.letter,
    required this.selected,
    required this.revealed,
    required this.isCorrect,
    required this.enabled,
    required this.onTap,
  });

  final QuizChoice choice;

  /// La lettre de la proposition. Sans elle, quatre pavés de texte se
  /// ressemblent et l'œil ne sait pas où poser la réponse.
  final String letter;

  final bool selected;
  final bool revealed;
  final bool isCorrect;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Color border = MboaColors.contour;
    Color background = Colors.white;
    Color badge = MboaColors.sable100;
    Color badgeText = MboaColors.encre500;
    IconData? icon;
    Color? iconColor;

    if (revealed && isCorrect) {
      border = MboaColors.succes;
      background = MboaColors.forest100;
      badge = MboaColors.succes;
      badgeText = Colors.white;
      icon = Icons.check_circle_rounded;
      iconColor = MboaColors.succes;
    } else if (revealed && selected) {
      border = MboaColors.erreur;
      background = const Color(0xFFFBE9E7);
      badge = MboaColors.erreur;
      badgeText = Colors.white;
      icon = Icons.cancel_rounded;
      iconColor = MboaColors.erreur;
    } else if (selected) {
      border = MboaSection.culture.accent;
      background = MboaSection.culture.accent.withValues(alpha: 0.1);
      badge = MboaSection.culture.accent;
      badgeText = Colors.white;
    }

    return Semantics(
      button: enabled,
      selected: selected,
      label: 'Proposition $letter',
      child: InkWell(
        borderRadius: BorderRadius.circular(MboaRadius.md),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: MboaMotion.quick,
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          padding: const EdgeInsets.all(MboaSpace.md),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(MboaRadius.md),
            border: Border.all(
              color: border,
              width: selected || isCorrect ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badge,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  letter,
                  style: text.labelLarge?.copyWith(color: badgeText),
                ),
              ),
              const SizedBox(width: MboaSpace.md),
              // Sur une question où ce sont les propositions qui s'écoutent,
              // le libellé est neutre : c'est la piste qui porte l'information.
              if (choice.audioUrl != null) ...[
                AudioButton(url: choice.audioUrl!, size: 40),
                const SizedBox(width: MboaSpace.md),
              ],
              Expanded(child: Text(choice.label, style: text.bodyLarge)),
              if (icon != null) Icon(icon, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// La correction, avec la fiche et sa source : l'affirmation est vérifiable.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.verdict});
  final QuizVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: verdict.isCorrect ? MboaColors.forest100 : MboaColors.sable100,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            verdict.isCorrect
                ? 'Bonne réponse'
                : 'Réponse : ${verdict.correctLabel}',
            style: text.titleMedium?.copyWith(
              color: verdict.isCorrect
                  ? MboaColors.forest900
                  : MboaColors.encre900,
            ),
          ),
          const SizedBox(height: MboaSpace.xs),
          Text(verdict.explanation, style: text.bodyMedium),
          if (verdict.sourceTitle != null) ...[
            const SizedBox(height: MboaSpace.sm),
            Text(
              'Source : ${verdict.sourceTitle}',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ],
          const SizedBox(height: MboaSpace.sm),
          // Une question d'écoute n'a pas de fiche derrière elle : c'est
          // l'attribution de l'enregistrement qui répond de la réponse, et
          // elle est déjà affichée au-dessus. On propose alors de réécouter.
          if (verdict.hasContent)
            TextButton.icon(
              onPressed: () => context.push('/culture/${verdict.contentId}'),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('Lire la fiche'),
            )
          else if (verdict.audioUrl != null)
            Row(
              children: [
                AudioButton(url: verdict.audioUrl!, size: 44),
                const SizedBox(width: MboaSpace.sm),
                Text(
                  'Réécouter la bonne réponse',
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.correct,
    required this.total,
    required this.onRestart,
  });

  final int correct;
  final int total;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : correct / total;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const MboaGradientHeader(
          section: MboaSection.culture,
          title: 'Votre résultat',
          subtitle: 'Quiz culturel',
          leading: MboaHeaderBack(),
        ),
        Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Column(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 12,
                      backgroundColor: Colors.white,
                      color: MboaSection.culture.accent,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$correct/$total',
                            style: text.headlineMedium?.copyWith(
                              color: MboaSection.culture.accent,
                            ),
                          ),
                          Text('bonnes réponses', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MboaSpace.xl),
              Text(
                _headline(ratio),
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
              const SizedBox(height: MboaSpace.md),
              Text(
                'Ce quiz teste ce que vous avez retenu des fiches du Culture '
                'Hub. Ce n’est pas une évaluation de niveau.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
              ),
              const SizedBox(height: MboaSpace.xl),
              FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Recommencer'),
              ),
              const SizedBox(height: MboaSpace.md),
              OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.menu_book_outlined, size: 20),
                label: const Text('Revenir à la culture'),
              ),
              const SizedBox(height: MboaSpace.xxl),
            ],
          ),
        ),
      ],
    );
  }

  /// Un mot, plutôt qu'un pourcentage : « 3 bonnes réponses sur 5 » se lit
  /// mieux qu'un score, et ne donne pas l'impression d'une note.
  String _headline(double ratio) {
    if (ratio == 1) return 'Sans faute';
    if (ratio >= 0.6) return 'Bien joué';
    if (ratio >= 0.3) return 'Bonne base';
    return 'À revoir';
  }
}

class _NoQuestion extends StatelessWidget {
  const _NoQuestion({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MboaSection.culture.fond,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CultureEmptyState(
                icon: Icons.quiz_outlined,
                title: 'Pas encore de quiz',
                text: message,
                action: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Revenir à la culture'),
                ),
              ),
              const SizedBox(height: MboaSpace.md),
              const MboaNoteBox(
                text:
                    'Les questions sont tirées des fiches publiées. Aucune n’est '
                    'écrite à la main : le quiz grandit avec le Culture Hub.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
