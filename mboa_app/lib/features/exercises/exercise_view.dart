import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/audio_button.dart';
import '../learning/domain/models.dart';

/// Une réponse à soumettre au serveur, et le libellé lisible de la bonne réponse
/// (pour la barre de feedback). Le client ne corrige rien lui-même.
typedef SubmitAnswer = void Function(Map<String, dynamic> answer);

/// Registre des types d'exercices (livrable G). Un type non encore implémenté
/// côté client affiche un message clair plutôt que de planter.
Widget buildExerciseView({
  required Exercise exercise,
  required SubmitAnswer onSubmit,
  required AttemptResult? result,
  required String? selectedId,
}) {
  return switch (exercise.type) {
    'LISTEN_AND_CHOOSE' || 'AUDIO_TO_WORD' => ListenAndChooseView(
      exercise: exercise,
      onSubmit: onSubmit,
      result: result,
      selectedId: selectedId,
    ),
    'WORD_TO_AUDIO' => WordToAudioView(
      exercise: exercise,
      onSubmit: onSubmit,
      result: result,
      selectedId: selectedId,
    ),
    'MULTIPLE_CHOICE' => MultipleChoiceView(
      exercise: exercise,
      onSubmit: onSubmit,
      result: result,
      selectedId: selectedId,
    ),
    'MEMORY_GAME' => MemoryGameView(
      exercise: exercise,
      onSubmit: onSubmit,
      result: result,
    ),
    _ => _UnsupportedView(type: exercise.type, onSubmit: onSubmit),
  };
}

/// Retrouve le libellé de la bonne réponse, pour l'afficher après une erreur.
String? correctLabelFor(Exercise exercise, AttemptResult result) {
  final correctId = result.correctAnswer;
  final choices =
      (exercise.payload['choices'] as List?)?.cast<Map>() ?? const [];
  for (final choice in choices) {
    if (choice['id'] == correctId) {
      if (choice['text'] != null) return choice['text'] as String;
      if (exercise.type == 'WORD_TO_AUDIO') {
        final index = choices.indexOf(choice) + 1;
        return 'Enregistrement $index';
      }
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Écouter puis choisir la forme écrite.
// ---------------------------------------------------------------------------
class ListenAndChooseView extends StatelessWidget {
  const ListenAndChooseView({
    super.key,
    required this.exercise,
    required this.onSubmit,
    required this.result,
    required this.selectedId,
  });

  final Exercise exercise;
  final SubmitAnswer onSubmit;
  final AttemptResult? result;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final audioUrl = exercise.payload['audio_url'] as String;
    final choices = (exercise.payload['choices'] as List).cast<Map>();
    final attribution = exercise.payload['audio_attribution'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: exercise.prompt),
        const SizedBox(height: MboaSpace.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AudioButton(url: audioUrl, size: 88, autoplay: true),
            const SizedBox(width: MboaSpace.lg),
            AudioButton(url: audioUrl, size: 56, slow: true),
          ],
        ),
        if (attribution != null) _Attribution(text: attribution),
        const SizedBox(height: MboaSpace.xl),
        for (final choice in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: MboaSpace.md),
            child: ChoiceTile(
              label: choice['text'] as String,
              isLexeme: true,
              state: _tileState(choice['id'] as String),
              onTap: result == null
                  ? () => onSubmit({'choice_id': choice['id']})
                  : null,
            ),
          ),
      ],
    );
  }

  ChoiceState _tileState(String id) => _stateFor(id, selectedId, result);
}

// ---------------------------------------------------------------------------
// Voir un mot puis reconnaître son enregistrement.
// ---------------------------------------------------------------------------
class WordToAudioView extends StatelessWidget {
  const WordToAudioView({
    super.key,
    required this.exercise,
    required this.onSubmit,
    required this.result,
    required this.selectedId,
  });

  final Exercise exercise;
  final SubmitAnswer onSubmit;
  final AttemptResult? result;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final choices = (exercise.payload['choices'] as List).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: exercise.prompt),
        const SizedBox(height: MboaSpace.xl),
        Center(
          child: Text(
            exercise.payload['text'] as String,
            style: lexemeStyle(context, size: 36),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: MboaSpace.sm),
        Text(
          'Écoute chaque enregistrement, puis choisis.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: MboaColors.encre500),
        ),
        const SizedBox(height: MboaSpace.xl),
        for (final (index, choice) in choices.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: MboaSpace.md),
            child: Row(
              children: [
                AudioButton(
                  url: choice['audio_url'] as String,
                  size: 52,
                  semanticLabel: 'Écouter l\'enregistrement ${index + 1}',
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: ChoiceTile(
                    label: 'Enregistrement ${index + 1}',
                    state: _stateFor(
                      choice['id'] as String,
                      selectedId,
                      result,
                    ),
                    onTap: result == null
                        ? () => onSubmit({'choice_id': choice['id']})
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Donner le sens (n'apparaît que si le corpus porte des gloses validées).
// ---------------------------------------------------------------------------
class MultipleChoiceView extends StatelessWidget {
  const MultipleChoiceView({
    super.key,
    required this.exercise,
    required this.onSubmit,
    required this.result,
    required this.selectedId,
  });

  final Exercise exercise;
  final SubmitAnswer onSubmit;
  final AttemptResult? result;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final choices = (exercise.payload['choices'] as List).cast<Map>();
    final audio = exercise.payload['audio_url'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: exercise.prompt),
        const SizedBox(height: MboaSpace.lg),
        if (audio != null) Center(child: AudioButton(url: audio, size: 64)),
        const SizedBox(height: MboaSpace.xl),
        for (final choice in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: MboaSpace.md),
            child: ChoiceTile(
              label: choice['text'] as String,
              state: _stateFor(choice['id'] as String, selectedId, result),
              onTap: result == null
                  ? () => onSubmit({'choice_id': choice['id']})
                  : null,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Jeu de paires : mot écrit ↔ enregistrement.
// Seule la première proposition pour chaque mot compte : le jeu reste un
// exercice, pas un simple essai-erreur.
// ---------------------------------------------------------------------------
class MemoryGameView extends StatefulWidget {
  const MemoryGameView({
    super.key,
    required this.exercise,
    required this.onSubmit,
    required this.result,
  });

  final Exercise exercise;
  final SubmitAnswer onSubmit;
  final AttemptResult? result;

  @override
  State<MemoryGameView> createState() => _MemoryGameViewState();
}

class _MemoryGameViewState extends State<MemoryGameView> {
  late final List<Map> _pairs = (widget.exercise.payload['pairs'] as List)
      .cast<Map>();
  late final List<Map> _audioOrder = [..._pairs]..shuffle();

  String? _selectedWord;
  final Set<String> _matched = {};
  final Set<String> _firstTryCorrect = {};
  final Set<String> _attempted = {};
  String? _wrongAudio;

  void _tapAudio(Map pair) {
    final word = _selectedWord;
    if (word == null || _matched.contains(pair['id'])) return;

    final isMatch = pair['id'] == word;
    final firstTry = !_attempted.contains(word);
    _attempted.add(word);

    setState(() {
      if (isMatch) {
        _matched.add(word);
        if (firstTry) _firstTryCorrect.add(word);
        _selectedWord = null;
        _wrongAudio = null;
      } else {
        _wrongAudio = pair['id'] as String;
      }
    });

    if (_matched.length == _pairs.length) {
      widget.onSubmit({'matched_ids': _firstTryCorrect.toList()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: widget.exercise.prompt),
        const SizedBox(height: MboaSpace.sm),
        Text(
          'Touche un mot, puis l\'enregistrement qui lui correspond.',
          style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
        ),
        const SizedBox(height: MboaSpace.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final pair in _pairs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MboaSpace.md),
                      child: ChoiceTile(
                        label: pair['text'] as String,
                        isLexeme: true,
                        compact: true,
                        state: _matched.contains(pair['id'])
                            ? ChoiceState.correct
                            : (_selectedWord == pair['id']
                                  ? ChoiceState.selected
                                  : ChoiceState.idle),
                        onTap:
                            _matched.contains(pair['id']) ||
                                widget.result != null
                            ? null
                            : () => setState(() {
                                _selectedWord = pair['id'] as String;
                                _wrongAudio = null;
                              }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: MboaSpace.md),
            Expanded(
              child: Column(
                children: [
                  for (final (index, pair) in _audioOrder.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MboaSpace.md),
                      child: Row(
                        children: [
                          AudioButton(
                            url: pair['audio_url'] as String,
                            size: 48,
                            semanticLabel: 'Écouter le son ${index + 1}',
                          ),
                          const SizedBox(width: MboaSpace.sm),
                          Expanded(
                            child: ChoiceTile(
                              label: 'Son ${index + 1}',
                              compact: true,
                              state: _matched.contains(pair['id'])
                                  ? ChoiceState.correct
                                  : (_wrongAudio == pair['id']
                                        ? ChoiceState.wrong
                                        : ChoiceState.idle),
                              onTap:
                                  _selectedWord == null || widget.result != null
                                  ? null
                                  : () => _tapAudio(pair),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.type, required this.onSubmit});

  final String type;
  final SubmitAnswer onSubmit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(
        Icons.construction_rounded,
        size: 48,
        color: MboaColors.encre500,
      ),
      const SizedBox(height: MboaSpace.md),
      Text(
        'Ce type d\'exercice ($type) arrive bientôt dans l\'application.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Éléments communs.
// ---------------------------------------------------------------------------
enum ChoiceState { idle, selected, correct, wrong, dimmed }

ChoiceState _stateFor(String id, String? selectedId, AttemptResult? result) {
  if (result == null) {
    return id == selectedId ? ChoiceState.selected : ChoiceState.idle;
  }
  if (id == result.correctAnswer) return ChoiceState.correct;
  if (id == selectedId) return ChoiceState.wrong;
  return ChoiceState.dimmed;
}

class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.isLexeme = false,
    this.compact = false,
  });

  final String label;
  final ChoiceState state;
  final VoidCallback? onTap;
  final bool isLexeme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (border, background, icon) = switch (state) {
      ChoiceState.correct => (
        MboaColors.succes,
        const Color(0xFFE3F2E9),
        Icons.check_rounded,
      ),
      ChoiceState.wrong => (
        MboaColors.erreur,
        const Color(0xFFFBE4E2),
        Icons.close_rounded,
      ),
      ChoiceState.selected => (
        MboaColors.forest500,
        MboaColors.forest100,
        null,
      ),
      ChoiceState.dimmed => (const Color(0xFFE7DCC9), Colors.white, null),
      ChoiceState.idle => (MboaColors.sable600, Colors.white, null),
    };

    final style = isLexeme
        ? lexemeStyle(context, size: compact ? 18 : 22)
        : Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);

    return Semantics(
      button: onTap != null,
      selected: state == ChoiceState.selected,
      // Le libellé contient déjà le texte : sans exclusion, TalkBack le lirait deux fois.
      excludeSemantics: true,
      label: switch (state) {
        ChoiceState.correct => '$label, bonne réponse',
        ChoiceState.wrong => '$label, réponse incorrecte',
        _ => label,
      },
      child: Opacity(
        opacity: state == ChoiceState.dimmed ? 0.55 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(MboaRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(MboaRadius.md),
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                minHeight: compact ? kMinTouchTarget : 60,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: MboaSpace.lg,
                vertical: compact ? MboaSpace.sm : MboaSpace.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MboaRadius.md),
                border: Border.all(
                  color: border,
                  width: state == ChoiceState.idle ? 1 : 2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: style)),
                  if (icon != null) Icon(icon, color: border),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineMedium);
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MboaSpace.sm),
    child: Text(
      'Voix : $text',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: MboaColors.encre500),
    ),
  );
}
