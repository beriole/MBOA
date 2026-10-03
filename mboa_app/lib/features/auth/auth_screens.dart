import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/tokens.dart';
import '../../design/widgets/mboa_logo.dart';
import 'auth_controller.dart';

/// Les types de compte proposés à l'inscription.
///
/// Ils étaient auparavant offerts depuis la page profil, une fois le compte
/// créé — ce qui mettait sur l'écran personnel d'un apprenant des invitations à
/// devenir artisan ou livreur, sans rapport avec ses propres informations. Le
/// choix se fait désormais à l'inscription, là où il a du sens.
///
/// **Un point à ne pas perdre** : choisir « artisan » ou « livreur » ne donne
/// pas le rôle. Cela ouvre un dossier que l'administration examine. MBOA ne
/// conserve aucune pièce d'identité ; la vérification a lieu hors ligne, et
/// c'est elle qui autorise à vendre ou à livrer. L'écran le dit avant le choix,
/// pas après.
enum AccountKind {
  learner(
    label: 'Apprendre une langue',
    hint: 'Leçons, vocabulaire, patrimoine',
    description:
        'Suivre les leçons, écouter les enregistrements, explorer le '
        'patrimoine. C’est immédiat.',
    icon: Icons.school_rounded,
    tone: MboaTileTone.indigo,
  ),
  artisan(
    label: 'Vendre mes créations',
    hint: 'Boutique d’artisanat',
    description:
        'Ouvrir une boutique d’artisanat. Un dossier est examiné avant '
        'la première mise en vente.',
    icon: Icons.storefront_rounded,
    tone: MboaTileTone.orange,
    route: '/become/artisan',
  ),
  courier(
    label: 'Livrer des commandes',
    hint: 'Courses dans votre ville',
    description:
        'Prendre en charge les livraisons de votre ville. Un dossier est '
        'examiné avant la première course.',
    icon: Icons.two_wheeler_rounded,
    tone: MboaTileTone.ambre,
    route: '/become/courier',
  ),
  contributor(
    label: 'Contribuer au contenu',
    hint: 'Mots, fiches, enregistrements',
    description:
        'Proposer des mots, des enregistrements, des fiches. Toute '
        'contribution passe par la validation.',
    icon: Icons.menu_book_rounded,
    tone: MboaTileTone.vert,
    route: '/become-specialist',
  );

  const AccountKind({
    required this.label,
    required this.hint,
    required this.description,
    required this.icon,
    required this.tone,
    this.route,
  });

  final String label;

  /// L'intention en une ligne, telle qu'elle tient dans la tuile de choix.
  final String hint;

  /// Ce que ce type de compte ouvre vraiment. Elle est affichée sous le
  /// choix, une fois la tuile sélectionnée : quatre paragraphes empilés
  /// avant même de choisir obligerait à faire défiler pour les lire tous.
  final String description;

  final IconData icon;
  final MboaTileTone tone;

  /// Où emmener après la création du compte. Nul pour l'apprenant : il n'a
  /// aucun dossier à déposer.
  final String? route;

  bool get needsReview => route != null;
}

// ---------------------------------------------------------------------------
// Inscription
// ---------------------------------------------------------------------------

/// L'inscription en deux temps.
///
/// Elle demandait trois champs, puis quatre cartes de choix, puis un bouton,
/// sur un seul écran : il fallait faire défiler pour atteindre le bouton, et la
/// question la plus importante — *pourquoi s'inscrire* — arrivait en dernier,
/// après le mot de passe. Les deux sont désormais séparées : d'abord qui on
/// est, ensuite ce qu'on vient faire. Chaque écran ne pose qu'une question, et
/// le bouton reste visible.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _revealed = false;
  String? _error;
  int _step = 0;
  AccountKind _kind = AccountKind.learner;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toProject() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _submit() async {
    // Le formulaire d'identité n'est plus monté à la seconde étape : il n'est
    // construit que par `_identity()`. Déréférencer `currentState!` ici levait
    // une exception à chaque appui sur « Créer mon compte », si bien qu'aucun
    // compte ne pouvait être créé — l'écran restait figé, sans message.
    //
    // La validation a déjà eu lieu au passage d'étape. On ne la rejoue que si
    // le formulaire est encore là, et un champ redevenu invalide ramène à
    // l'étape où on peut le corriger.
    final identite = _form.currentState;
    if (identite != null && !identite.validate()) {
      setState(() => _step = 0);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
          );
      if (!mounted) return;
      // Le compte est créé comme apprenant dans tous les cas. Un type qui
      // demande vérification enchaîne sur son dossier ; il n'est pas accordé
      // ici, et l'écran suivant l'explique.
      context.go(_kind.route ?? '/setup');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingDraftProvider);
    final surIdentite = _step == 0;

    return _AuthScaffold(
      section: MboaSection.accueil,
      title: surIdentite ? 'Créez votre compte' : 'Que voulez-vous faire ?',
      subtitle: surIdentite
          ? draft.languageName != null
                ? 'Pour garder votre progression en ${draft.languageName}.'
                : 'Pour garder votre progression.'
          : 'Cela décide de ce que MBOA vous proposera.',
      stepper: _StepDots(step: _step, total: 2),
      fields: [if (surIdentite) _identity() else _project()],
      error: _error,
      busy: _busy,
      primaryLabel: surIdentite
          ? 'Continuer'
          : _kind.needsReview
          ? 'Créer mon compte et déposer un dossier'
          : 'Créer mon compte',
      onPrimary: surIdentite ? _toProject : _submit,
      secondaryLabel: surIdentite ? null : 'Revenir à mes informations',
      onSecondary: surIdentite
          ? null
          : () => setState(() {
              _step = 0;
              _error = null;
            }),
      footerLabel: 'J’ai déjà un compte',
      onFooter: () => context.go('/login'),
    );
  }

  Widget _identity() => Form(
    key: _form,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Prénom ou pseudonyme',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Indiquez un prénom ou un pseudonyme.'
                : null,
          ),
          const SizedBox(height: MboaSpace.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Adresse e-mail',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Cette adresse ne ressemble pas à un e-mail.'
                : null,
          ),
          const SizedBox(height: MboaSpace.md),
          TextFormField(
            controller: _password,
            obscureText: !_revealed,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              helperText: '8 caractères au minimum',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _revealed ? 'Masquer' : 'Afficher',
                icon: Icon(
                  _revealed
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () => setState(() => _revealed = !_revealed),
              ),
            ),
            validator: (v) => (v == null || v.length < 8)
                ? 'Huit caractères au minimum.'
                : null,
            onFieldSubmitted: (_) => _toProject(),
          ),
          const SizedBox(height: MboaSpace.sm),
          // Le seul retour immédiat sur la saisie : l'utilisateur voit où il en
          // est au lieu de n'apprendre qu'à la fin que le mot de passe est
          // refusé.
          _PasswordStrength(password: _password),
        ],
      ),
    ),
  );

  Widget _project() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // La hauteur des tuiles est calculée, pas figée : avec un rapport
      // largeur/hauteur constant, le texte débordait déjà de six pixels à
      // taille normale, et le débordement grandissait avec le réglage système
      // de taille de texte — donc chez les gens qui en ont besoin.
      LayoutBuilder(
        builder: (context, contraintes) {
          final largeur = (contraintes.maxWidth - MboaSpace.md) / 2;
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: MboaSpace.md,
            crossAxisSpacing: MboaSpace.md,
            childAspectRatio: largeur / _KindTile.hauteur(context),
            children: [
              for (final kind in AccountKind.values)
                _KindTile(
                  kind: kind,
                  selected: _kind == kind,
                  onTap: () => setState(() => _kind = kind),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: MboaSpace.lg),
      // La description du type choisi, et non les quatre à la fois : on lit ce
      // qui va réellement se passer, et ce que le choix engage.
      _Notice(
        icon: _kind.needsReview
            ? Icons.how_to_reg_outlined
            : Icons.bolt_rounded,
        text: _kind.needsReview
            ? '${_kind.description} Votre compte est créé immédiatement comme '
                  'apprenant ; le dossier est examiné par l’administration. '
                  'MBOA ne conserve aucune pièce d’identité et vérifie hors '
                  'ligne.'
            : _kind.description,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Connexion
// ---------------------------------------------------------------------------
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _revealed = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    section: MboaSection.profil,
    title: 'Bon retour',
    subtitle: 'Reprenez où vous vous étiez arrêté.',
    fields: [
      AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Adresse e-mail',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: _password,
              obscureText: !_revealed,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _revealed ? 'Masquer' : 'Afficher',
                  icon: Icon(
                    _revealed
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () => setState(() => _revealed = !_revealed),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
    ],
    error: _error,
    busy: _busy,
    primaryLabel: 'Se connecter',
    onPrimary: _submit,
    footerLabel: 'Créer un compte',
    onFooter: () => context.go('/onboarding'),
  );
}

// ---------------------------------------------------------------------------
// Habillage commun
// ---------------------------------------------------------------------------

/// La structure des écrans de compte.
///
/// Elle était posée sur un fond blanc, sans autre repère qu'un emblème et deux
/// champs : rien n'y signalait qu'on était dans MBOA. Elle se compose désormais
/// d'un bandeau dégradé porteur de la marque, et d'une feuille blanche arrondie
/// qui vient s'y adosser et porte le formulaire — la même grammaire visuelle
/// que le reste de l'application.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.error,
    required this.busy,
    required this.primaryLabel,
    required this.onPrimary,
    required this.footerLabel,
    required this.onFooter,
    this.stepper,
    this.secondaryLabel,
    this.onSecondary,
  });

  final MboaSection section;
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final String? error;
  final bool busy;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String footerLabel;
  final VoidCallback onFooter;

  /// L'avancement, quand l'écran se déroule en plusieurs temps.
  final Widget? stepper;

  /// Le retour arrière, quand l'écran se déroule en plusieurs temps.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MboaSpace.xl,
                      MboaSpace.xl,
                      MboaSpace.xl,
                      MboaSpace.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MboaLogo(
                          variant: MboaLogoVariant.embleme,
                          height: 64,
                        ),
                        const SizedBox(height: MboaSpace.lg),
                        Text(
                          title,
                          style: text.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: MboaSpace.xs),
                        Text(
                          subtitle,
                          style: text.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        if (stepper != null) ...[
                          const SizedBox(height: MboaSpace.lg),
                          stepper!,
                        ],
                      ],
                    ),
                  ),
                  // La feuille blanche : elle porte le formulaire et remonte
                  // sur le dégradé.
                  Container(
                    decoration: BoxDecoration(
                      color: section.fond,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(MboaRadius.xl),
                      ),
                    ),
                    padding: const EdgeInsets.all(MboaSpace.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...fields,
                        if (error != null) ...[
                          const SizedBox(height: MboaSpace.lg),
                          _ErrorBox(message: error!),
                        ],
                        const SizedBox(height: MboaSpace.xl),
                        FilledButton(
                          onPressed: busy ? null : onPrimary,
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(primaryLabel),
                        ),
                        if (secondaryLabel != null) ...[
                          const SizedBox(height: MboaSpace.xs),
                          TextButton(
                            onPressed: busy ? null : onSecondary,
                            style: TextButton.styleFrom(
                              foregroundColor: MboaColors.encre500,
                            ),
                            child: Text(secondaryLabel!),
                          ),
                        ],
                        const SizedBox(height: MboaSpace.sm),
                        TextButton(
                          onPressed: onFooter,
                          child: Text(footerLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'avancement de l'inscription, en segments.
///
/// Une barre continue ne dit pas combien d'étapes restent ; deux segments le
/// disent, et le libellé qui les accompagne nomme l'étape en cours.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Étape ${step + 1} sur $total',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: MboaSpace.sm),
        Text(
          step == 0 ? 'Étape 1 · Vos informations' : 'Étape 2 · Votre projet',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    ),
  );
}

/// La robustesse du mot de passe, dite pendant la saisie.
///
/// Purement indicative : la règle qui compte est celle du serveur, huit
/// caractères au minimum. L'intérêt est ailleurs — l'utilisateur n'attend plus
/// la fin du formulaire pour apprendre que son mot de passe est refusé.
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final TextEditingController password;

  static const _labels = ['Trop court', 'Faible', 'Correct', 'Solide'];

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: password,
        builder: (context, value, _) {
          final typed = value.text;
          final score = _score(typed);
          if (typed.isEmpty) return const SizedBox.shrink();
          final color = switch (score) {
            0 => MboaColors.erreur,
            1 => MboaColors.terre700,
            2 => MboaColors.ocre500,
            _ => MboaColors.succes,
          };

          return Semantics(
            label: 'Robustesse du mot de passe : ${_labels[score]}',
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: MboaMotion.quick,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < score ? color : Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 5),
                ],
                const SizedBox(width: MboaSpace.sm),
                Text(
                  _labels[score],
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          );
        },
      );

  /// De 0 (trop court) à 3 (solide). Une seule règle est celle du serveur ; les
  /// deux autres ne servent qu'à décourager un mot de passe trivial.
  static int _score(String value) {
    if (value.length < 8) return 0;
    var score = 1;
    final hasLetter = value.contains(RegExp('[A-Za-z]'));
    final hasDigit = value.contains(RegExp('[0-9]'));
    if (hasLetter && hasDigit) score++;
    if (value.length >= 12) score++;
    return score.clamp(0, 3);
  }
}

/// Une carte de choix du type de compte, en tuile de grille.
///
/// Les quatre cartes se lisaient côte à côte sur toute la largeur, et il
/// fallait faire défiler pour voir la dernière. En grille de deux colonnes, les
/// quatre sont visibles ensemble, et c'est l'écran suivant — non la carte — qui
/// explique ce que le choix engage.
class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AccountKind kind;
  final bool selected;
  final VoidCallback onTap;

  /// Hauteur nécessaire à une tuile, au grossissement de texte courant.
  ///
  /// On lit les tailles dans le thème plutôt que de les recopier : des valeurs
  /// dupliquées se désynchronisent dès qu'on retouche la typographie, et la
  /// tuile se remettrait à déborder sans prévenir.
  ///
  /// Sur-estimer ne coûte rien — la colonne répartit l'espace en trop entre ses
  /// blocs. Sous-estimer rogne le texte.
  static double hauteur(BuildContext context) {
    final styles = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);

    double lignes(TextStyle? style, [int nombre = 1]) {
      final taille = style?.fontSize ?? 14;
      final interligne = style?.height ?? 1.45;
      return scaler.scale(taille) * interligne * nombre;
    }

    final contenu =
        MboaSpace.md * 2 + // rembourrage de la tuile
        44 + // la pastille d'icône
        MboaSpace.sm +
        lignes(styles.titleMedium) + // le libellé
        2 +
        lignes(styles.bodySmall, 2) + // l'explication, sur deux lignes
        MboaSpace.sm +
        24; // la ligne « Choisir »

    return contenu * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        child: AnimatedContainer(
          duration: MboaMotion.quick,
          padding: const EdgeInsets.all(MboaSpace.md),
          decoration: BoxDecoration(
            color: selected ? kind.tone.background : Colors.white,
            borderRadius: BorderRadius.circular(MboaRadius.lg),
            border: Border.all(
              color: selected ? kind.tone.icon : MboaColors.contour,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      // Sélectionnée, la tuile prend la couleur de la pastille
                      // en fond : l'icône s'y fondait et la carte choisie
                      // perdait son repère visuel. On passe alors au blanc.
                      color: selected ? Colors.white : kind.tone.background,
                      borderRadius: BorderRadius.circular(MboaRadius.sm),
                    ),
                    child: Icon(kind.icon, color: kind.tone.icon, size: 22),
                  ),
                  if (kind.needsReview)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MboaColors.sable100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'dossier',
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kind.label,
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kind.hint,
                    style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? kind.tone.icon : MboaColors.encre400,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected ? 'Choisi' : 'Choisir',
                    style: text.bodySmall?.copyWith(
                      color: selected ? kind.tone.icon : MboaColors.encre400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(MboaSpace.md),
    decoration: BoxDecoration(
      color: MboaColors.indigo100,
      borderRadius: BorderRadius.circular(MboaRadius.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MboaColors.indigo700),
        const SizedBox(width: MboaSpace.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(MboaSpace.md),
    decoration: BoxDecoration(
      color: const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(MboaRadius.md),
      border: Border.all(color: MboaColors.erreur.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: MboaColors.erreur,
          size: 20,
        ),
        const SizedBox(width: MboaSpace.sm),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF991B1B)),
          ),
        ),
      ],
    ),
  );
}
