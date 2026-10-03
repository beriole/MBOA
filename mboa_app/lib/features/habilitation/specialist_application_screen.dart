import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design/tokens.dart';
import '../learning/domain/models.dart';
import '../progress/progress_providers.dart';

/// Candidature pour devenir spécialiste culturel (SS43).
///
/// MBOA ne demande ni pièce d'identité ni relevé bancaire : la question n'est
/// pas qui vous êtes administrativement, mais au nom de quoi vous pourriez
/// décider qu'un mot est juste. Le formulaire demande donc le rapport à la
/// langue et des personnes capables d'en répondre.
class SpecialistApplicationScreen extends ConsumerStatefulWidget {
  const SpecialistApplicationScreen({super.key});

  @override
  ConsumerState<SpecialistApplicationScreen> createState() =>
      _SpecialistApplicationScreenState();
}

class _SpecialistApplicationScreenState
    extends ConsumerState<SpecialistApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _relationship = TextEditingController();
  final _affiliation = TextEditingController();
  final _referees = TextEditingController();

  String? _languageId;
  String _claimedRole = 'NATIVE_SPEAKER';
  final Set<String> _scope = {'LEXICON'};
  bool _sending = false;
  String? _error;

  static const _roles = {
    'NATIVE_SPEAKER': 'Locuteur natif',
    'LINGUIST': 'Linguiste',
    'TEACHER': 'Enseignant',
    'RECORDIST': 'Preneur de son',
    'EDITOR': 'Rédacteur',
  };

  static const _scopes = {
    'LEXICON': 'Le lexique',
    'GRAMMAR': 'La grammaire',
    'AUDIO': 'Les enregistrements',
    'CULTURE': 'Les fiches culturelles',
    'EXERCISE': 'Les exercices',
  };

  @override
  void dispose() {
    _relationship.dispose();
    _affiliation.dispose();
    _referees.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _languageId == null) {
      if (_languageId == null) {
        setState(
          () => _error = 'Choisis la langue sur laquelle tu veux travailler.',
        );
      }
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).post('/me/specialist-application', {
        'language_id': _languageId,
        'claimed_role': _claimedRole,
        'relationship_fr': _relationship.text.trim(),
        if (_affiliation.text.trim().isNotEmpty)
          'affiliation': _affiliation.text.trim(),
        if (_referees.text.trim().isNotEmpty)
          'referees_fr': _referees.text.trim(),
        'requested_scope': _scope.toList(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Candidature envoyée. Elle sera examinée par un administrateur.',
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = ref.watch(languagesProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Devenir spécialiste')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            Text(
              'Valider un mot, c’est affirmer qu’il se dit ainsi. MBOA ne confie '
              'ce geste qu’à des personnes dont la légitimité a été vérifiée — '
              'et la vérification est consignée.',
              style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
            ),
            const SizedBox(height: MboaSpace.xl),
            languages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _languageId,
                decoration: const InputDecoration(labelText: 'Langue'),
                items: [
                  for (final Language language in list)
                    DropdownMenuItem(
                      value: language.id,
                      child: Text(language.name),
                    ),
                ],
                onChanged: (value) => setState(() => _languageId = value),
              ),
            ),
            const SizedBox(height: MboaSpace.lg),
            DropdownButtonFormField<String>(
              initialValue: _claimedRole,
              decoration: const InputDecoration(labelText: 'À quel titre'),
              items: [
                for (final entry in _roles.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _claimedRole = value!),
            ),
            const SizedBox(height: MboaSpace.lg),
            TextFormField(
              controller: _relationship,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Ton rapport à cette langue',
                helperText:
                    'Langue maternelle, apprise, étudiée ? Depuis quand, où, '
                    'avec qui la parles-tu ?',
                helperMaxLines: 3,
              ),
              // Le serveur exige vingt caractères : on le dit avant l'envoi.
              validator: (value) => (value ?? '').trim().length < 20
                  ? 'Quelques phrases sont nécessaires pour examiner la demande.'
                  : null,
            ),
            const SizedBox(height: MboaSpace.md),
            TextFormField(
              controller: _affiliation,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Rattachement (facultatif)',
                helperText: 'Association, université, radio communautaire…',
              ),
            ),
            const SizedBox(height: MboaSpace.md),
            TextFormField(
              controller: _referees,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Qui peut en répondre (facultatif)',
                helperText:
                    'Personnes ou institutions que nous pouvons contacter.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: MboaSpace.lg),
            Text('Ce que tu souhaites relire', style: text.titleMedium),
            const SizedBox(height: MboaSpace.sm),
            Wrap(
              spacing: MboaSpace.sm,
              runSpacing: MboaSpace.sm,
              children: [
                for (final entry in _scopes.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _scope.contains(entry.key),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _scope.add(entry.key)
                          : _scope.remove(entry.key);
                    }),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: MboaSpace.lg),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: MboaColors.erreur),
              ),
            ],
            const SizedBox(height: MboaSpace.xl),
            FilledButton(
              onPressed: _sending || _scope.isEmpty ? null : _submit,
              child: Text(_sending ? 'Envoi…' : 'Envoyer ma candidature'),
            ),
            const SizedBox(height: MboaSpace.md),
            Text(
              'Un administrateur examinera la demande et motivera sa réponse. '
              'Tu la retrouveras dans ton profil.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ],
        ),
      ),
    );
  }
}
