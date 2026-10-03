import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/audio_button.dart';
import '../../progress/progress_providers.dart';
import '../data/translation_repository.dart';
import '../domain/models.dart';

/// Traduction par recherche dans le corpus validé.
///
/// L'écran dit toujours d'où vient la réponse, et surtout quand il n'en a pas :
/// « je ne sais pas » vaut mieux qu'une invention plausible (SS41).
class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen> {
  final _input = TextEditingController();
  bool _intoFrench = true;
  bool _busy = false;
  TranslationResult? _result;
  String? _error;
  String? _reported;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _search(String languageId) async {
    final query = _input.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _reported = null;
    });
    try {
      final result = await ref
          .read(translationRepositoryProvider)
          .translate(
            languageId: languageId,
            text: query,
            intoFrench: _intoFrench,
          );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final result = _result;
    if (result == null) return;
    try {
      final message = await ref
          .read(translationRepositoryProvider)
          .report(result.requestId);
      setState(() => _reported = message);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(selectedLanguageProvider);
    final text = Theme.of(context).textTheme;
    final languageName = language.value?.name ?? 'la langue';

    return Scaffold(
      appBar: AppBar(title: const Text('Traduction')),
      body: language.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (selected) {
          if (selected == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(MboaSpace.xl),
                child: Text('Choisis d’abord une langue dans ton parcours.'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(MboaSpace.lg),
            children: [
              _DirectionSwitch(
                languageName: selected.name,
                intoFrench: _intoFrench,
                onChanged: (value) => setState(() {
                  _intoFrench = value;
                  _result = null;
                }),
              ),
              const SizedBox(height: MboaSpace.lg),
              TextField(
                controller: _input,
                style: _intoFrench ? lexemeStyle(context, size: 22) : null,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(selected.id),
                decoration: InputDecoration(
                  hintText: _intoFrench
                      ? 'Un mot en ${selected.name}'
                      : 'Un mot en français',
                  suffixIcon: IconButton(
                    tooltip: 'Chercher',
                    onPressed: _busy ? null : () => _search(selected.id),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: MboaSpace.sm),
              Text(
                'Les diacritiques ne sont pas obligatoires : MBOA retrouve le mot '
                'et vous signale l’écriture exacte.',
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
              const SizedBox(height: MboaSpace.lg),
              FilledButton(
                onPressed: _busy ? null : () => _search(selected.id),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Chercher'),
              ),
              if (_error != null) ...[
                const SizedBox(height: MboaSpace.lg),
                Text(_error!, style: const TextStyle(color: MboaColors.erreur)),
              ],
              if (_result != null) ...[
                const SizedBox(height: MboaSpace.xl),
                _ResultHeader(result: _result!),
                const SizedBox(height: MboaSpace.md),
                for (final match in _result!.matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MboaSpace.md),
                    child: _MatchCard(match: match),
                  ),
                if (_result!.isEmpty) _NoMatch(languageName: languageName),
                const SizedBox(height: MboaSpace.md),
                if (_reported == null)
                  TextButton.icon(
                    onPressed: _report,
                    icon: const Icon(Icons.flag_outlined, size: 20),
                    label: const Text('Signaler un résultat douteux'),
                  )
                else
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: MboaColors.succes,
                        size: 20,
                      ),
                      const SizedBox(width: MboaSpace.sm),
                      Expanded(child: Text(_reported!, style: text.bodyMedium)),
                    ],
                  ),
                const SizedBox(height: MboaSpace.lg),
                _Disclaimer(text: _result!.disclaimer),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DirectionSwitch extends StatelessWidget {
  const _DirectionSwitch({
    required this.languageName,
    required this.intoFrench,
    required this.onChanged,
  });

  final String languageName;
  final bool intoFrench;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text('$languageName → FR')),
            ButtonSegment(value: false, label: Text('FR → $languageName')),
          ],
          selected: {intoFrench},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    ],
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.result});
  final TranslationResult result;

  @override
  Widget build(BuildContext context) {
    final best = result.matches.isEmpty ? null : result.matches.first.kind;
    final (color, icon) = switch (best) {
      MatchKind.exact => (
        MboaColors.succes,
        Icons.check_circle_outline_rounded,
      ),
      MatchKind.toneless ||
      MatchKind.folded => (MboaColors.ocre500, Icons.info_outline_rounded),
      MatchKind.fuzzy => (MboaColors.terre700, Icons.help_outline_rounded),
      null => (MboaColors.encre500, Icons.search_off_rounded),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: MboaSpace.sm),
        Expanded(
          child: Text(
            result.message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});
  final TranslationMatch match;

  static const _kindLabels = {
    MatchKind.exact: 'correspondance exacte',
    MatchKind.toneless: 'tons ignorés',
    MatchKind.folded: 'lettres spéciales rétablies',
    MatchKind.fuzzy: 'forme proche',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    match.lemma,
                    style: lexemeStyle(context, size: 26),
                  ),
                ),
                if (match.audioUrl != null)
                  AudioButton(url: match.audioUrl!, size: 48),
              ],
            ),
            const SizedBox(height: MboaSpace.xs),
            Text(
              match.meaningFr ?? 'traduction pas encore validée',
              style: text.bodyLarge?.copyWith(
                color: match.awaitsGloss
                    ? MboaColors.terre700
                    : MboaColors.encre900,
                fontStyle: match.awaitsGloss
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
            const SizedBox(height: MboaSpace.sm),
            Wrap(
              spacing: MboaSpace.sm,
              runSpacing: MboaSpace.xs,
              children: [
                _Tag(label: _kindLabels[match.kind]!),
                if (match.sourceLicense != null)
                  _Tag(label: match.sourceLicense!),
              ],
            ),
            if (match.examples.isNotEmpty) ...[
              const SizedBox(height: MboaSpace.md),
              Text('Exemples attestés', style: text.labelLarge),
              for (final example in match.examples)
                Padding(
                  padding: const EdgeInsets.only(top: MboaSpace.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(example.text, style: lexemeStyle(context, size: 16)),
                      if (example.translationFr != null)
                        Text(
                          example.translationFr!,
                          style: text.bodySmall?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            if (match.sourceTitle != null) ...[
              const SizedBox(height: MboaSpace.sm),
              Text(
                'Source : ${match.sourceTitle}',
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
            ],
            if (match.audioAttribution != null)
              Text(
                'Voix : ${match.audioAttribution}',
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: MboaColors.sable100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.languageName});
  final String languageName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: MboaColors.sable100,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce mot n’est pas encore dans le corpus',
            style: text.titleLarge,
          ),
          const SizedBox(height: MboaSpace.xs),
          Text(
            'Cela ne veut pas dire qu’il n’existe pas : le corpus $languageName est '
            'en cours de constitution par des locuteurs. Un mot n’y entre qu’une fois '
            'vérifié.',
            style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(
        Icons.info_outline_rounded,
        size: 18,
        color: MboaColors.encre400,
      ),
      const SizedBox(width: MboaSpace.sm),
      Expanded(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: MboaColors.encre500),
        ),
      ),
    ],
  );
}
