import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/mboa_logo.dart';
import '../auth/auth_controller.dart';
import '../progress/progress_providers.dart';

/// Onboarding en quatre étapes : valeur → langue → niveau → objectif quotidien.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _step = 0;

  static const _stepCount = 4;

  /// Le nom de chaque étape. Sans lui, les quatre pages se ressemblent et
  /// rien ne dit sur laquelle on se trouve : les segments seuls donnent un
  /// compte, pas un nom.
  static const _stepTitles = [
    'Bienvenue',
    'Votre langue',
    'Votre niveau',
    'Votre objectif',
  ];

  void _next() {
    if (_step == _stepCount - 1) {
      context.go('/register');
      return;
    }
    setState(() => _step++);
    _pages.animateToPage(
      _step,
      duration: MboaMotion.standard,
      curve: Curves.easeInOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pages.animateToPage(
      _step,
      duration: MboaMotion.standard,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingDraftProvider);
    final canContinue = _step != 1 || draft.languageId != null;

    // Chaque étape a sa couleur : on voit qu'on avance, et l'écran cesse
    // d'être une suite de pages blanches identiques.
    final sections = [
      MboaSection.accueil,
      MboaSection.apprendre,
      MboaSection.culture,
      MboaSection.boutique,
    ];
    final section = sections[_step];

    return Scaffold(
      backgroundColor: section.fond,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: section.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MboaSpace.sm,
                  MboaSpace.sm,
                  MboaSpace.md,
                  MboaSpace.md,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Revenir',
                      onPressed: _step == 0 ? null : _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      disabledColor: Colors.white38,
                    ),
                    Expanded(
                      child: _Steps(
                        step: _step,
                        total: _stepCount,
                        label: _stepTitles[_step],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Connexion'),
                    ),
                  ],
                ),
              ),
              // La feuille claire porte le contenu et remonte sur le dégradé :
              // même grammaire visuelle que les écrans de compte.
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: section.fond,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MboaRadius.xl),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _pages,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _WelcomePage(section: section),
                            _LanguagePage(onChanged: () => setState(() {})),
                            _LevelPage(onChanged: () => setState(() {})),
                            _GoalPage(onChanged: () => setState(() {})),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(MboaSpace.lg),
                        child: FilledButton(
                          onPressed: canContinue ? _next : null,
                          child: Text(
                            _step == _stepCount - 1
                                ? 'Créer mon compte'
                                : 'Continuer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'avancement, en segments plutôt qu'en barre continue.
///
/// Une barre qui se remplit ne dit pas combien d'étapes restent. Quatre
/// segments le disent d'un coup d'œil, et l'on sait où l'on s'arrête.
class _Steps extends StatelessWidget {
  const _Steps({required this.step, required this.total, required this.label});

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
                      color: i <= step ? Colors.white : Colors.white30,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Le titre d'une page d'onboarding : une accroche discrète, puis la question.
///
/// Les quatre pages flottaient sans titre commun : l'œil ne trouvait pas où
/// commence la question posée.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.eyebrow, required this.title, this.subtitle});

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: text.bodySmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: MboaColors.encre500,
          ),
        ),
        const SizedBox(height: MboaSpace.xs),
        Text(title, style: text.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: MboaSpace.xs),
          Text(
            subtitle!,
            style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
        ],
        const SizedBox(height: MboaSpace.lg),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.section});
  final MboaSection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget point(MboaTileTone tone, IconData icon, String title, String body) =>
        Padding(
          padding: const EdgeInsets.only(bottom: MboaSpace.md),
          child: Container(
            padding: const EdgeInsets.all(MboaSpace.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MboaRadius.md),
              border: Border.all(color: MboaColors.contour),
              boxShadow: kMboaCardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(MboaRadius.sm),
                  ),
                  child: Icon(icon, color: tone.icon, size: 22),
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MboaSpace.xl,
        MboaSpace.xl,
        MboaSpace.xl,
        MboaSpace.sm,
      ),
      children: [
        const Center(child: MboaLogo(height: 132)),
        const SizedBox(height: MboaSpace.xl),
        Text(
          'Votre langue. Votre culture.',
          style: text.headlineMedium?.copyWith(height: 1.2),
        ),
        Text(
          'Partout où vous êtes.',
          style: text.headlineMedium?.copyWith(
            height: 1.2,
            color: section.accent,
          ),
        ),
        const SizedBox(height: MboaSpace.xl),
        point(
          MboaTileTone.vert,
          Icons.headphones_rounded,
          'De vraies voix',
          'Chaque mot est enregistré par un locuteur de la langue.',
        ),
        point(
          MboaTileTone.indigo,
          Icons.verified_rounded,
          'Des contenus vérifiés',
          'Chaque mot porte une source, et une personne l’a validé.',
        ),
        point(
          MboaTileTone.ambre,
          Icons.bolt_rounded,
          'Quelques minutes par jour',
          'Des leçons courtes, et des révisions au bon moment.',
        ),
      ],
    );
  }
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final languages = ref.watch(languagesProvider);
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(MboaSpace.xl),
      children: [
        const _PageHeader(
          eyebrow: 'Étape 2',
          title: 'Quelle langue veux-tu apprendre ?',
          subtitle:
              'Chaque langue est vérifiée avant d’être proposée. C’est le '
              'cœur de tout ce que vous lirez ensuite.',
        ),
        languages.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text('$e', style: const TextStyle(color: MboaColors.erreur)),
          data: (list) => Column(
            children: [
              for (final language in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: MboaSpace.md),
                  child: _SelectableCard(
                    selected: draft.languageId == language.id,
                    onTap: () {
                      draft
                        ..languageId = language.id
                        ..languageName = language.name;
                      onChanged();
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(language.name, style: text.titleLarge),
                              if (language.autonym != null)
                                Text(
                                  language.autonym!,
                                  style: lexemeStyle(context, size: 18),
                                ),
                              const SizedBox(height: MboaSpace.xs),
                              Text(
                                '${language.publishedWords} mots vérifiés'
                                '${language.toneCount != null ? ' · ${language.toneCount} tons' : ''}',
                                style: text.bodySmall?.copyWith(
                                  color: MboaColors.encre500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: MboaSpace.sm),
                        Icon(
                          draft.languageId == language.id
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: draft.languageId == language.id
                              ? MboaColors.forest500
                              : MboaColors.encre400,
                        ),
                        const SizedBox(width: MboaSpace.sm),
                        Text(
                          language.iso.toUpperCase(),
                          style: text.labelLarge?.copyWith(
                            color: MboaColors.encre500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (list.length < 2)
                Text(
                  'D\'autres langues arriveront dès que leurs contenus auront été vérifiés.',
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelPage extends ConsumerWidget {
  const _LevelPage({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final text = Theme.of(context).textTheme;

    Widget option(String value, String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.md),
      child: _SelectableCard(
        selected: draft.level == value,
        onTap: () {
          draft.level = value;
          onChanged();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleLarge),
            Text(
              subtitle,
              style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(MboaSpace.xl),
      children: [
        _PageHeader(
          eyebrow: 'Étape 3',
          title: 'Où en es-tu en ${draft.languageName ?? 'cette langue'} ?',
          subtitle: 'Pour commencer au bon endroit, sans vous faire reprendre '
              'ce que vous savez déjà.',
        ),
        option(
          'DEBUTANT',
          'Je débute',
          'Je commence par les sons et les premiers mots.',
        ),
        option(
          'QUELQUES_MOTS',
          'Je connais quelques mots',
          'Un test de placement viendra ajuster ton point de départ.',
        ),
      ],
    );
  }
}

class _GoalPage extends ConsumerWidget {
  const _GoalPage({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final text = Theme.of(context).textTheme;
    const goals = [
      (10, 'Détente', '~5 min / jour'),
      (20, 'Régulier', '~10 min / jour'),
      (30, 'Sérieux', '~15 min / jour'),
      (50, 'Intense', '~25 min / jour'),
    ];

    return ListView(
      padding: const EdgeInsets.all(MboaSpace.xl),
      children: [
        const _PageHeader(
          eyebrow: 'Étape 4',
          title: 'Ton objectif quotidien',
          subtitle: 'Tu pourras le changer à tout moment. Ces quelques minutes '
              'suffisent : la régularité compte plus que l’intensité.',
        ),
        for (final (xp, label, time) in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: MboaSpace.md),
            child: _SelectableCard(
              selected: draft.dailyGoalXp == xp,
              onTap: () {
                draft.dailyGoalXp = xp;
                onChanged();
              },
              // Colonne et non ligne : à largeur téléphone, « Régulier » et
              // « 20 XP · ~10 min / jour » ne tiennent pas côte à côte.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.titleLarge),
                  Text(
                    '$xp XP · $time',
                    style: text.bodyMedium?.copyWith(
                      color: MboaColors.encre500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? MboaColors.forest100 : Colors.white,
      elevation: selected ? 0 : 1,
      shadowColor: MboaColors.indigo600.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(MboaRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(MboaRadius.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MboaMotion.quick,
          padding: const EdgeInsets.all(MboaSpace.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MboaRadius.md),
            border: Border.all(
              color: selected ? MboaColors.forest500 : MboaColors.sable600,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Emblème provisoire : motif géométrique original, en attendant la mascotte
/// dont le concept doit d'abord être validé culturellement (livrable K7).
