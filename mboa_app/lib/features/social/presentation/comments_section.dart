import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../data/social_repository.dart';
import '../domain/models.dart';

/// Le bloc « avis » posé sous une fiche, un enregistrement ou un produit.
///
/// Trois choix d'affichage portent la règle « un avis n'est pas une source » :
///
/// - l'avertissement du serveur est affiché **avant** les commentaires, pas en
///   petit en dessous : quelqu'un qui ne lit que le début doit déjà le savoir ;
/// - chaque propos porte le nom de son auteur et sa date, jamais une voix
///   anonyme qui ressemblerait à celle de MBOA ;
/// - les étoiles n'apparaissent que si le serveur dit que la cible se note.
///   Sur une fiche culturelle, il n'y en a pas — on ne vote pas sur un fait.
class CommentsSection extends ConsumerStatefulWidget {
  const CommentsSection({
    super.key,
    required this.targetType,
    required this.targetId,
    this.title = 'Avis et commentaires',
  });

  final String targetType;
  final String targetId;
  final String title;

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _controller = TextEditingController();
  int? _rating;
  bool _sending = false;
  String? _error;

  ({String type, String id}) get _target =>
      (type: widget.targetType, id: widget.targetId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final texte = _controller.text.trim();
    if (texte.length < 2) {
      setState(() => _error = 'Écrivez au moins quelques mots.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(socialRepositoryProvider)
          .add(
            widget.targetType,
            widget.targetId,
            body: texte,
            rating: _rating,
          );
      _controller.clear();
      setState(() => _rating = null);
      ref.invalidate(commentsProvider(_target));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(Comment comment) async {
    final motif = await showDialog<String>(
      context: context,
      builder: (context) => const _ReportDialog(),
    );
    if (motif == null || !mounted) return;
    final message = await ref
        .read(socialRepositoryProvider)
        .report(comment.id, motif);
    if (!mounted) return;
    ref.invalidate(commentsProvider(_target));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(_target));
    final text = Theme.of(context).textTheme;

    return comments.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(MboaSpace.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Text(
          'Les avis n’ont pas pu être chargés. $e',
          style: text.bodySmall?.copyWith(color: MboaColors.encre500),
        ),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: text.titleLarge)),
              if (data.rateable && data.average != null) ...[
                const SizedBox(width: MboaSpace.sm),
                _AverageBadge(average: data.average!, voters: data.voters),
              ],
            ],
          ),
          const SizedBox(height: MboaSpace.sm),
          _Notice(text: data.notice),
          const SizedBox(height: MboaSpace.lg),
          _Composer(
            controller: _controller,
            rateable: data.rateable,
            rating: _rating,
            onRating: (value) => setState(() => _rating = value),
            sending: _sending,
            error: _error,
            onSend: _send,
          ),
          const SizedBox(height: MboaSpace.lg),
          if (data.isEmpty)
            Text(
              'Personne ne s’est encore exprimé ici.',
              style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
            )
          else
            for (final comment in data.items)
              _CommentTile(comment: comment, onReport: () => _report(comment)),
        ],
      ),
    );
  }
}

/// L'avertissement du serveur, mis en évidence plutôt qu'en note de bas de page.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(MboaSpace.md),
      decoration: BoxDecoration(
        color: MboaColors.ocre100,
        borderRadius: BorderRadius.circular(MboaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: MboaColors.encre900,
          ),
          const SizedBox(width: MboaSpace.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _AverageBadge extends StatelessWidget {
  const _AverageBadge({required this.average, required this.voters});
  final double average;
  final int voters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$average sur 5, $voters avis',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: MboaColors.ocre500, size: 20),
          const SizedBox(width: MboaSpace.xs),
          Text(average.toStringAsFixed(1), style: text.titleMedium),
          const SizedBox(width: MboaSpace.xs),
          Text(
            '($voters)',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.rateable,
    required this.rating,
    required this.onRating,
    required this.sending,
    required this.error,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool rateable;
  final int? rating;
  final ValueChanged<int?> onRating;
  final bool sending;
  final String? error;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rateable) ...[
          Text('Votre note', style: text.labelLarge),
          const SizedBox(height: MboaSpace.xs),
          Row(
            children: [
              for (var etoile = 1; etoile <= 5; etoile++)
                IconButton(
                  tooltip: '$etoile sur 5',
                  onPressed: () => onRating(rating == etoile ? null : etoile),
                  icon: Icon(
                    (rating ?? 0) >= etoile
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: MboaColors.ocre500,
                  ),
                ),
              if (rating != null)
                TextButton(
                  onPressed: () => onRating(null),
                  child: const Text('Retirer'),
                ),
            ],
          ),
        ],
        TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 2000,
          decoration: InputDecoration(
            // L'étiquette reste visible une fois la saisie commencée ; un
            // intitulé posé en texte d'aide disparaît à la première lettre,
            // et plus rien ne dit ce qu'on est en train d'écrire.
            labelText: rateable ? 'Votre avis' : 'Votre commentaire',
            hintText: rateable
                ? 'Décrivez votre expérience avec cet objet…'
                : 'Ce que cette publication vous évoque…',
            errorText: error,
            border: const OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Publier'),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onReport});
  final Comment comment;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.md),
      child: Container(
        padding: const EdgeInsets.all(MboaSpace.md),
        decoration: BoxDecoration(
          color: MboaColors.sable100,
          borderRadius: BorderRadius.circular(MboaRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: MboaColors.indigo100,
                  child: Text(
                    _initiale(comment.author),
                    style: text.labelLarge?.copyWith(
                      color: MboaColors.indigo700,
                    ),
                  ),
                ),
                const SizedBox(width: MboaSpace.sm),
                Expanded(child: Text(comment.author, style: text.labelLarge)),
                if (comment.rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          i < comment.rating!
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 14,
                          color: MboaColors.ocre500,
                        ),
                    ],
                  ),
                IconButton(
                  tooltip: 'Signaler',
                  iconSize: 18,
                  onPressed: onReport,
                  icon: const Icon(
                    Icons.flag_outlined,
                    color: MboaColors.encre400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MboaSpace.xs),
            Text(comment.body, style: text.bodyMedium),
            if (comment.createdAt != null) ...[
              const SizedBox(height: MboaSpace.xs),
              Text(
                _date(comment.createdAt!),
                style: text.bodySmall?.copyWith(color: MboaColors.encre400),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// La première lettre du nom, ou un point d'interrogation si le nom est vide.
  static String _initiale(String nom) =>
      nom.isEmpty ? '?' : nom.substring(0, 1).toUpperCase();

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler ce commentaire'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Le commentaire sera masqué en attendant l’examen. Il ne sera pas '
            'supprimé : la modération doit pouvoir le lire pour trancher.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: MboaSpace.md),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motif',
              hintText: 'Dites ce qui pose problème, en une phrase.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final motif = _controller.text.trim();
            if (motif.length >= 5) Navigator.of(context).pop(motif);
          },
          child: const Text('Signaler'),
        ),
      ],
    );
  }
}
