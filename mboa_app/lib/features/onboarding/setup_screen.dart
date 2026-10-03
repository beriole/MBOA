import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../design/tokens.dart';
import '../../design/widgets/mboa_tiles.dart';
import '../auth/auth_controller.dart';
import 'setup_repository.dart';

/// Configuration initiale, après l'inscription (lot 3 des maquettes).
///
/// L'onboarding *avant* compte recueille la langue, le niveau et l'objectif
/// quotidien. Les étapes qui suivent — motivation, centres d'intérêt, test de
/// positionnement, notifications — demandent un compte pour être enregistrées,
/// et se déroulent donc ici.
///
/// Deux étapes disent franchement ce qu'elles sont :
///
///  - le **test de positionnement** ne s'affiche que si le corpus publié
///    permet de poser de vraies questions ; sinon il l'explique ;
///  - les **notifications** recueillent un consentement, elles ne déclenchent
///    rien à ce jour, et l'écran le dit.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _steps = 5;

  /// Le nom de chaque étape : les segments disent « 3/5 », pas de quoi il
  /// s'agit. Les deux ensemble disent où l'on est et ce qu'on y fait.
  static const _stepTitles = [
    'Vos motivations',
    'Vos centres d’intérêt',
    'Test de positionnement',
    'Notifications',
    'Récapitulatif',
  ];

  int _step = 0;
  bool _saving = false;
  String? _error;

  final Set<String> _motivations = {};
  final Set<String> _interests = {};
  final Map<String, bool> _notifications = {
    'reminders': true,
    'new_content': true,
    'tips': false,
    'offers': false,
  };
  bool? _placementAccepted;

  SetupRepository get _repo => ref.read(setupRepositoryProvider);

  Future<void> _send(Map<String, dynamic> body) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.save(body);
      if (mounted) setState(() => _step++);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Revenir à l'étape précédente. Les choix déjà faits sont conservés, et
  /// l'étape est de toute façon enregistrée côté serveur : rien n'est perdu.
  void _back() {
    if (_step == 0 || _saving) return;
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        await _send({'motivations': _motivations.toList()});
      case 1:
        await _send({'interests': _interests.toList()});
      case 2:
        await _send({'placement_test_accepted': _placementAccepted ?? false});
      case 3:
        await _send({'notifications': _notifications});
      case 4:
        await _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await _repo.save({'completed': true});
      // L'objectif quotidien a pu changer : on relit la session.
      await ref.read(sessionProvider.notifier).refresh();
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    try {
      await _repo.save({'completed': true});
    } on ApiException catch (_) {
      // Passer la configuration ne doit jamais bloquer l'entrée dans l'app.
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MboaSection.accueil.fond,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MboaSpace.sm,
                MboaSpace.sm,
                MboaSpace.md,
                MboaSpace.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Étape précédente',
                    onPressed: _step == 0 ? null : _back,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: _SetupSteps(
                      step: _step,
                      total: _steps,
                      label: _stepTitles[_step],
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: const Text('Passer'),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MboaSpace.lg),
                child: Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(color: MboaColors.erreur),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MboaSpace.lg,
                MboaSpace.md,
                MboaSpace.lg,
                MboaSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _saving || !_canContinue ? null : _next,
                    child: Text(
                      _step == _steps - 1
                          ? 'Commencer mon apprentissage'
                          : 'Continuer',
                    ),
                  ),
                  // Un bouton inactif sans explication ressemble à une panne.
                  if (!_canContinue && !_saving) ...[
                    const SizedBox(height: MboaSpace.sm),
                    Text(
                      'Choisissez au moins une réponse pour continuer.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Les deux premières étapes attendent au moins un choix ; les autres ont
  /// toujours une réponse valide, y compris « non ».
  bool get _canContinue => switch (_step) {
    0 => _motivations.isNotEmpty,
    1 => _interests.isNotEmpty,
    _ => true,
  };

  Widget _body() => switch (_step) {
    0 => _MotivationStep(
      selected: _motivations,
      onToggle: (code) => setState(() => _motivations.toggle(code)),
    ),
    1 => _InterestStep(
      selected: _interests,
      onToggle: (code) => setState(() => _interests.toggle(code)),
    ),
    2 => _PlacementStep(
      accepted: _placementAccepted,
      onChanged: (value) => setState(() => _placementAccepted = value),
    ),
    3 => _NotificationStep(
      values: _notifications,
      onChanged: (key, value) => setState(() => _notifications[key] = value),
    ),
    _ => const _SummaryStep(),
  };
}

extension _Toggle on Set<String> {
  void toggle(String value) => contains(value) ? remove(value) : add(value);
}

// ---------------------------------------------------------------------------
// Étapes
// ---------------------------------------------------------------------------

/// L'avancement de la configuration, en segments nommés.
///
/// La barre continue qu'elle remplace disait « 3/5 » sans dire de quoi. Les
/// segments disent combien d'étapes restent, et le libellé en dessous dit
/// laquelle — comme à l'onboarding, dont c'est la même grammaire.
class _SetupSteps extends StatelessWidget {
  const _SetupSteps({
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Étape ${step + 1} sur $total, $label',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: MboaMotion.standard,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? MboaSection.accueil.accent
                          : MboaColors.contour,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${step + 1}/$total · $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(MboaSpace.lg),
      children: [
        const SizedBox(height: MboaSpace.lg),
        Text(title, style: text.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: MboaSpace.sm),
          Text(
            subtitle!,
            style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
        ],
        const SizedBox(height: MboaSpace.xl),
        ...children,
        const SizedBox(height: MboaSpace.xxl),
      ],
    );
  }
}

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final MboaTileTone tone;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.md),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(MboaRadius.md),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTouchTarget),
            padding: const EdgeInsets.all(MboaSpace.md),
            decoration: BoxDecoration(
              color: selected ? MboaColors.forest100 : Colors.white,
              borderRadius: BorderRadius.circular(MboaRadius.md),
              border: Border.all(
                color: selected ? MboaColors.forest500 : MboaColors.contour,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                MboaIconTile(icon: icon, tone: tone),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(label, style: text.titleMedium)],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? MboaColors.forest500 : MboaColors.encre400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotivationStep extends StatelessWidget {
  const _MotivationStep({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  static const options = [
    (
      'DISCOVER_CULTURE',
      Icons.museum_outlined,
      'Découvrir ma culture',
      MboaTileTone.ambre,
    ),
    (
      'FAMILY',
      Icons.family_restroom_rounded,
      'Communiquer avec ma famille',
      MboaTileTone.rose,
    ),
    (
      'TRAVEL',
      Icons.flight_takeoff_rounded,
      'Voyager au Cameroun',
      MboaTileTone.bleu,
    ),
    (
      'PROFESSIONAL',
      Icons.work_outline_rounded,
      'Raisons professionnelles',
      MboaTileTone.orange,
    ),
    (
      'PERSONAL',
      Icons.favorite_outline_rounded,
      'Par intérêt personnel',
      MboaTileTone.vert,
    ),
    ('OTHER', Icons.more_horiz_rounded, 'Autre raison', MboaTileTone.indigo),
  ];

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: 'Pourquoi souhaitez-vous apprendre cette langue ?',
    subtitle:
        'Choisissez une ou plusieurs raisons. Elles orientent ce qu’on '
        'vous propose, elles ne verrouillent rien.',
    children: [
      for (final (code, icon, label, tone) in options)
        _SelectableRow(
          icon: icon,
          tone: tone,
          label: label,
          selected: selected.contains(code),
          onTap: () => onToggle(code),
        ),
    ],
  );
}

class _InterestStep extends ConsumerWidget {
  const _InterestStep({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rubriques = ref.watch(setupCategoriesProvider);

    return _StepScaffold(
      title: 'Quels sujets culturels vous intéressent ?',
      subtitle:
          'Les rubriques du Culture Hub. Certaines sont encore vides : '
          'elles attendent des contributeurs.',
      children: [
        rubriques.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (list) => Wrap(
            spacing: MboaSpace.sm,
            runSpacing: MboaSpace.sm,
            children: [
              for (final rubrique in list)
                FilterChip(
                  label: Text('${rubrique.name} · ${rubrique.publishedCount}'),
                  selected: selected.contains(rubrique.code),
                  onSelected: (_) => onToggle(rubrique.code),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlacementStep extends ConsumerWidget {
  const _PlacementStep({required this.accepted, required this.onChanged});

  final bool? accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placement = ref.watch(setupPlacementProvider);

    return _StepScaffold(
      title: 'Souhaitez-vous faire un test de positionnement ?',
      subtitle:
          'Le test lui-même n’est pas encore construit. Cette étape '
          'enregistre votre souhait ; elle ne lance rien.',
      children: [
        placement.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          // Le serveur dit si le corpus publié permettrait un test honnête.
          // L'application dit, elle, que le test n'est pas encore branché : les
          // deux informations sont distinctes et toutes deux affichées.
          data: (info) => Column(
            children: [
              MboaNoteBox(
                icon: info.available
                    ? Icons.inventory_2_outlined
                    : Icons.info_outline_rounded,
                tone: info.available ? MboaTileTone.vert : MboaTileTone.indigo,
                title: info.available
                    ? 'Le corpus publié le permettrait'
                    : 'Le corpus publié ne le permet pas encore',
                text:
                    '${info.explanation} '
                    '(${info.published} exercice${info.published > 1 ? 's' : ''} '
                    'publié${info.published > 1 ? 's' : ''} sur ${info.required} '
                    'attendus, ${info.types} type${info.types > 1 ? 's' : ''} '
                    'sur ${info.typesRequired}).',
              ),
              const SizedBox(height: MboaSpace.lg),
              _SelectableRow(
                icon: Icons.notifications_active_outlined,
                tone: MboaTileTone.vert,
                label: 'Oui, prévenez-moi quand il existera',
                selected: accepted == true,
                onTap: () => onChanged(true),
              ),
              _SelectableRow(
                icon: Icons.schedule_rounded,
                tone: MboaTileTone.indigo,
                label: 'Non, je commence directement',
                selected: accepted == false,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationStep extends StatelessWidget {
  const _NotificationStep({required this.values, required this.onChanged});

  final Map<String, bool> values;
  final void Function(String, bool) onChanged;

  static const options = [
    ('reminders', 'Rappels d’apprentissage', 'Pour ne pas perdre votre série.'),
    (
      'new_content',
      'Nouveaux contenus',
      'Fiches culturelles, leçons, mots validés.',
    ),
    (
      'tips',
      'Conseils personnalisés',
      'Suggestions fondées sur votre progression.',
    ),
    ('offers', 'Offres et événements', 'Boutique et rendez-vous culturels.'),
  ];

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: 'Souhaitez-vous recevoir des notifications ?',
    children: [
      const MboaNoteBox(
        icon: Icons.notifications_off_outlined,
        tone: MboaTileTone.ambre,
        text:
            'Aucun envoi n’est branché à ce jour. Ce réglage enregistre '
            'votre accord ; il ne déclenche rien pour l’instant.',
      ),
      const SizedBox(height: MboaSpace.lg),
      for (final (key, label, description) in options)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: values[key] ?? false,
          title: Text(label, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(description),
          onChanged: (value) => onChanged(key, value),
        ),
    ],
  );
}

class _SummaryStep extends ConsumerWidget {
  const _SummaryStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(setupSummaryProvider);
    final text = Theme.of(context).textTheme;

    return _StepScaffold(
      title: 'Votre parcours est prêt',
      subtitle:
          'Voici ce que vous avez choisi. Tout se modifie depuis le profil.',
      children: [
        summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (data) => Column(
            children: [
              for (final (label, value) in data.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: MboaSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          label,
                          style: text.bodySmall?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),
                      ),
                      Expanded(child: Text(value, style: text.bodyLarge)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
