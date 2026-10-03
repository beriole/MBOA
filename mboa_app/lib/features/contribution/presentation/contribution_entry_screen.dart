import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/audio_button.dart';
import '../data/contribution_repository.dart';
import '../domain/models.dart';

/// Fiche de contribution : écouter, saisir la traduction, décider.
///
/// La provenance est affichée avant le formulaire : on ne valide pas un mot
/// sans savoir d'où il vient (SS4).
class ContributionEntryScreen extends ConsumerStatefulWidget {
  const ContributionEntryScreen({super.key, required this.entry});

  final CorpusEntry entry;

  @override
  ConsumerState<ContributionEntryScreen> createState() =>
      _ContributionEntryScreenState();
}

class _ContributionEntryScreenState
    extends ConsumerState<ContributionEntryScreen> {
  late final TextEditingController _meaning = TextEditingController(
    text: widget.entry.meaningFr ?? '',
  );
  late final TextEditingController _lemma = TextEditingController(
    text: widget.entry.lemma,
  );
  final _comment = TextEditingController();

  late String _category = widget.entry.category;
  late String _status = widget.entry.status;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void didUpdateWidget(covariant ContributionEntryScreen old) {
    super.didUpdateWidget(old);
    // Si l'ecran est reutilise pour un autre mot (enchainement des fiches),
    // il doit repartir de zero : sinon la saisie precedente resterait affichee.
    if (old.entry.id != widget.entry.id) {
      _meaning.text = widget.entry.meaningFr ?? '';
      _lemma.text = widget.entry.lemma;
      _comment.clear();
      setState(() {
        _category = widget.entry.category;
        _status = widget.entry.status;
        _message = null;
        _isError = false;
      });
    }
  }

  @override
  void dispose() {
    _meaning.dispose();
    _lemma.dispose();
    _comment.dispose();
    super.dispose();
  }

  ContributionRepository get _repo => ref.read(contributionRepositoryProvider);

  Future<void> _run(
    Future<({String status, String message})> Function() action,
  ) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await action();
      setState(() {
        _status = result.status;
        _message = result.message;
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _message = '$e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() {
    final meaning = _meaning.text.trim();
    if (meaning.isEmpty) {
      setState(() {
        _message =
            'La traduction française est nécessaire pour valider ce mot.';
        _isError = true;
      });
      return Future.value();
    }
    return _run(
      () => _repo.save(
        widget.entry.id,
        meaningFr: meaning,
        category: _category,
        lemma: _lemma.text.trim() == widget.entry.lemma
            ? null
            : _lemma.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contribution')),
      // L'action principale reste accessible sans faire defiler toute la fiche.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: MboaColors.ivoire,
          border: Border(top: BorderSide(color: Color(0xFFE7DCC9))),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(MboaSpace.lg),
          child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Enregistrer la traduction'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MboaSpace.lg),
        children: [
          // ---------------------------------------------------- la forme
          Center(
            child: Column(
              children: [
                Text(entry.lemma, style: lexemeStyle(context, size: 34)),
                const SizedBox(height: MboaSpace.lg),
                if (entry.audioUrl != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AudioButton(url: entry.audioUrl!, size: 72),
                      const SizedBox(width: MboaSpace.md),
                      AudioButton(url: entry.audioUrl!, size: 52, slow: true),
                    ],
                  )
                else
                  Text(
                    'Aucun enregistrement pour ce mot.',
                    style: text.bodyMedium?.copyWith(
                      color: MboaColors.encre500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MboaSpace.xl),

          // ---------------------------------------------------- provenance
          _Provenance(entry: entry),
          const SizedBox(height: MboaSpace.xl),

          // ---------------------------------------------------- saisie
          Text('Traduction en français', style: text.titleLarge),
          const SizedBox(height: MboaSpace.sm),
          TextField(
            controller: _meaning,
            decoration: const InputDecoration(
              hintText: 'Ce que ce mot signifie',
              helperText:
                  'Écrivez seulement ce que vous savez. En cas de doute, '
                  'demandez une modification plutôt que de valider.',
              helperMaxLines: 3,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: MboaSpace.lg),
          Text('Catégorie grammaticale', style: text.titleLarge),
          const SizedBox(height: MboaSpace.sm),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: [
              for (final entry in kGrammaticalCategories.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: MboaSpace.lg),
          ExpansionTile(
            title: Text('Corriger l’orthographe', style: text.bodyLarge),
            subtitle: Text(
              'À n’utiliser que si la forme écrite est fautive.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: MboaSpace.md),
            children: [
              TextField(
                controller: _lemma,
                style: lexemeStyle(context, size: 20),
                decoration: const InputDecoration(labelText: 'Forme écrite'),
              ),
            ],
          ),

          if (_message != null) ...[
            const SizedBox(height: MboaSpace.lg),
            _Banner(message: _message!, isError: _isError),
          ],

          const SizedBox(height: MboaSpace.xl),
          _StatusLine(status: _status),
          const SizedBox(height: MboaSpace.md),

          // ---------------------------------------------------- actions
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    () => _repo.decide(
                      widget.entry.id,
                      decision: 'ACCEPT',
                      comment: _comment.text.trim(),
                    ),
                  ),
            icon: const Icon(Icons.verified_rounded, color: MboaColors.succes),
            label: const Text('Valider (relecture d’un autre contributeur)'),
          ),
          const SizedBox(height: MboaSpace.sm),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    () => _repo.decide(
                      widget.entry.id,
                      decision: 'REQUEST_CHANGES',
                      comment: _comment.text.trim(),
                    ),
                  ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Demander une modification'),
          ),
          const SizedBox(height: MboaSpace.sm),
          if (_status == 'VALIDATED')
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: MboaColors.succes),
              onPressed: _busy
                  ? null
                  : () => _run(() => _repo.publish(widget.entry.id)),
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Publier dans l’application'),
            ),
          const SizedBox(height: MboaSpace.sm),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    () => _repo.decide(
                      widget.entry.id,
                      decision: 'REJECT',
                      comment: _comment.text.trim(),
                    ),
                  ),
            icon: const Icon(Icons.block_rounded, color: MboaColors.erreur),
            label: const Text(
              'Rejeter cette entrée',
              style: TextStyle(color: MboaColors.erreur),
            ),
          ),
          const SizedBox(height: MboaSpace.md),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(
              labelText: 'Remarque (jointe à votre décision)',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: MboaSpace.xl),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Retour à la file'),
          ),
        ],
      ),
    );
  }
}

class _Provenance extends StatelessWidget {
  const _Provenance({required this.entry});
  final CorpusEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget line(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: MboaSpace.xs),
            child: RichText(
              text: TextSpan(
                style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                children: [
                  TextSpan(text: '$label : '),
                  TextSpan(
                    text: value,
                    style: text.bodySmall?.copyWith(color: MboaColors.encre900),
                  ),
                ],
              ),
            ),
          );

    return Container(
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: MboaColors.sable100,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 20,
                color: MboaColors.forest700,
              ),
              const SizedBox(width: MboaSpace.sm),
              Text('Provenance', style: text.titleLarge),
            ],
          ),
          const SizedBox(height: MboaSpace.sm),
          line('Source', entry.sourceTitle),
          line('Licence', entry.sourceLicense),
          line('Fichier', entry.sourceLocator),
          line('Voix', entry.audioAttribution),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.flag_outlined, size: 20, color: MboaColors.encre500),
      const SizedBox(width: MboaSpace.sm),
      Text(
        'Statut : ${kStatusLabels[status] ?? status}',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(MboaSpace.md),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFBE4E2) : const Color(0xFFE3F2E9),
      borderRadius: BorderRadius.circular(MboaRadius.sm),
    ),
    child: Row(
      children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: isError ? MboaColors.erreur : MboaColors.succes,
          size: 20,
        ),
        const SizedBox(width: MboaSpace.sm),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
