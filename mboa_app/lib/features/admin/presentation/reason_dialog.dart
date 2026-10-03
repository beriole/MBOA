import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// Demande le motif d'un acte d'administration.
///
/// Le serveur refuse tout acte non motivé ; cette boîte de dialogue n'est donc
/// pas un garde-fou d'interface qu'on pourrait contourner, mais la façon de
/// saisir une information obligatoire. Elle explique pourquoi on la demande.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String action,
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _ReasonDialog(title: title, action: action, hint: hint),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.action, this.hint});

  final String title;
  final String action;
  final String? hint;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  /// Même seuil que le serveur : cinq caractères utiles.
  bool get _isValid => _controller.text.trim().length >= 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cet acte sera inscrit au journal avec votre nom et ce motif. '
            'Le journal ne peut pas être effacé.',
            style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
          const SizedBox(height: MboaSpace.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Motif',
              hintText:
                  widget.hint ?? 'Sur quelle base prenez-vous cette décision ?',
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
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
