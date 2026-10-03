import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../data/contribution_repository.dart';
import '../domain/models.dart';

/// Espace contributeur : la file des mots à traduire puis à relire.
///
/// L'écran affiche d'abord l'avancement du corpus, parce que c'est lui qui
/// détermine ce que l'application peut proposer aux apprenants.
class ContributionQueueScreen extends ConsumerStatefulWidget {
  const ContributionQueueScreen({super.key});

  @override
  ConsumerState<ContributionQueueScreen> createState() =>
      _ContributionQueueScreenState();
}

class _ContributionQueueScreenState
    extends ConsumerState<ContributionQueueScreen> {
  String? _languageId;

  @override
  Widget build(BuildContext context) {
    final languages = ref.watch(contributorLanguagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Espace contributeur')),
      body: languages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Error(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return const _Error(
              message:
                  "Aucune langue ne vous est confiée pour l'instant.\n"
                  "Un administrateur doit vous habiliter.",
            );
          }
          final selected = _languageId ?? list.first.id;
          return _QueueView(
            languages: list,
            languageId: selected,
            onLanguageChanged: (id) => setState(() => _languageId = id),
          );
        },
      ),
    );
  }
}

class _QueueView extends ConsumerWidget {
  const _QueueView({
    required this.languages,
    required this.languageId,
    required this.onLanguageChanged,
  });

  final List<ContributorLanguage> languages;
  final String languageId;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(contributionQueueProvider(languageId));
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(contributionQueueProvider(languageId));
        ref.invalidate(contributorLanguagesProvider);
      },
      child: queue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Error(message: '$e'),
        data: (data) => ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            if (languages.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: MboaSpace.lg),
                child: SegmentedButton<String>(
                  segments: [
                    for (final language in languages)
                      ButtonSegment(
                        value: language.id,
                        label: Text(language.name),
                      ),
                  ],
                  selected: {languageId},
                  onSelectionChanged: (s) => onLanguageChanged(s.first),
                ),
              ),
            _CorpusProgress(queue: data),
            const SizedBox(height: MboaSpace.lg),
            if (data.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(MboaSpace.xl),
                child: Text(
                  'Rien à traiter pour cette langue.',
                  style: text.bodyLarge?.copyWith(color: MboaColors.encre500),
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final entry in data.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: MboaSpace.md),
                  child: _EntryTile(
                    entry: entry,
                    onTap: () async {
                      await context.push(
                        '/contribute/${entry.id}',
                        extra: entry,
                      );
                      ref.invalidate(contributionQueueProvider(languageId));
                      ref.invalidate(contributorLanguagesProvider);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CorpusProgress extends StatelessWidget {
  const _CorpusProgress({required this.queue});
  final ContributionQueue queue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final translated = queue.total - queue.missingGloss;
    final ratio = queue.total == 0 ? 0.0 : translated / queue.total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avancement du corpus', style: text.titleLarge),
            const SizedBox(height: MboaSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                backgroundColor: MboaColors.sable100,
                color: MboaColors.forest500,
              ),
            ),
            const SizedBox(height: MboaSpace.sm),
            Text(
              '$translated mot(s) traduit(s) sur ${queue.total}',
              style: text.bodyMedium,
            ),
            const SizedBox(height: MboaSpace.md),
            Wrap(
              spacing: MboaSpace.sm,
              runSpacing: MboaSpace.sm,
              children: [
                for (final entry in queue.counts.entries)
                  _StatusChip(status: entry.key, count: entry.value),
              ],
            ),
            if (queue.missingGloss > 0) ...[
              const SizedBox(height: MboaSpace.md),
              Text(
                'Tant qu’un mot n’a pas de traduction validée, il ne peut apparaître '
                'que dans un exercice d’écoute.',
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.count});
  final String status;
  final int count;

  static const _colors = {
    'PUBLISHED': MboaColors.succes,
    'VALIDATED': MboaColors.forest500,
    'HUMAN_REVIEW': MboaColors.ocre500,
    'TO_VERIFY': MboaColors.terre700,
    'REJECTED': MboaColors.erreur,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? MboaColors.encre500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${kStatusLabels[status] ?? status} · $count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});
  final CorpusEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.lemma, style: lexemeStyle(context, size: 22)),
                    const SizedBox(height: 2),
                    Text(
                      entry.meaningFr ?? 'traduction à saisir',
                      style: text.bodyMedium?.copyWith(
                        color: entry.hasGloss
                            ? MboaColors.encre900
                            : MboaColors.terre700,
                        fontStyle: entry.hasGloss
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MboaSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: entry.hasGloss
                      ? MboaColors.forest100
                      : MboaColors.terre100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  kStatusLabels[entry.status] ?? entry.status,
                  style: text.bodySmall,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MboaColors.encre500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(MboaSpace.xl),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
