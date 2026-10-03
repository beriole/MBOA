import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design/tokens.dart';
import '../auth/auth_controller.dart';

/// Modification du profil (SS15).
///
/// On ne modifie ici que ce qui appartient à la personne : son nom affiché, sa
/// langue d'interface, son objectif quotidien, son mot de passe. Le rôle et
/// l'e-mail n'y figurent pas — le premier ne se choisit pas soi-même, le second
/// identifie le compte.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late int _goal;
  late String _locale;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _name = TextEditingController(text: session.displayName ?? '');
    _goal = session.dailyGoalXp;
    _locale = session.locale;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .updateProfile(
            displayName: _name.text.trim(),
            dailyGoalXp: _goal,
            locale: _locale,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil mis à jour.')));
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PasswordSheet(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mot de passe modifié. Les autres sessions ont été fermées.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nom affiché'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Un nom est nécessaire.'
                  : null,
            ),
            const SizedBox(height: MboaSpace.lg),
            Row(
              children: [
                Expanded(
                  child: Text('Objectif quotidien', style: text.titleMedium),
                ),
                // La valeur du curseur reste lisible sans le manipuler.
                Text('$_goal XP', style: text.titleMedium),
              ],
            ),
            Text(
              'Entre 10 et 50 XP par jour. Un objectif tenable vaut mieux qu’un '
              'objectif ambitieux.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            Slider(
              value: _goal.toDouble(),
              min: 10,
              max: 50,
              divisions: 4,
              label: '$_goal XP',
              onChanged: (value) => setState(() => _goal = value.round()),
            ),
            const SizedBox(height: MboaSpace.md),
            Text('Langue de l’interface', style: text.titleMedium),
            const SizedBox(height: MboaSpace.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fr', label: Text('Français')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {_locale},
              onSelectionChanged: (values) =>
                  setState(() => _locale = values.first),
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
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
            ),
            const SizedBox(height: MboaSpace.xxl),
            const Divider(),
            const SizedBox(height: MboaSpace.md),
            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Changer mon mot de passe'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Changement de mot de passe. L'ancien est exigé : un téléphone laissé
/// déverrouillé ne doit pas suffire à verrouiller le compte de quelqu'un.
class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 8) {
      setState(
        () => _error = 'Le nouveau mot de passe fait au moins 8 caractères.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post('/auth/me/password', {
        'current_password': _current.text,
        'new_password': _next.text,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: MboaSpace.lg,
        right: MboaSpace.lg,
        top: MboaSpace.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + MboaSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Changer mon mot de passe', style: text.titleLarge),
          const SizedBox(height: MboaSpace.sm),
          Text(
            'Les sessions ouvertes sur tes autres appareils seront fermées.',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
          const SizedBox(height: MboaSpace.lg),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
          ),
          const SizedBox(height: MboaSpace.md),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: MboaSpace.md),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(color: MboaColors.erreur),
            ),
          ],
          const SizedBox(height: MboaSpace.lg),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Enregistrement…' : 'Changer'),
          ),
        ],
      ),
    );
  }
}
