import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/tokens.dart';
import '../../design/widgets/mboa_header.dart';
import '../../design/widgets/mboa_tiles.dart';
import '../auth/auth_controller.dart';
import '../progress/progress_providers.dart';

/// Le profil : les informations de la personne connectée, et rien d'autre.
///
/// L'écran portait auparavant des invitations à devenir artisan, livreur ou
/// spécialiste. C'était du recrutement posé sur une page personnelle : un
/// apprenant y lisait surtout ce qu'il n'était pas. Ces choix se font désormais
/// à l'inscription, où ils ont leur place.
///
/// Ce qui reste ici est à lui : son identité, sa progression, les espaces
/// auxquels il a **effectivement** accès, et les réglages de son compte.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Les états de maîtrise, dans l'ordre où ils se succèdent.
  static const _mastery = [
    ('MASTERED', 'Maîtrisés', MboaColors.succes),
    ('REVIEW', 'En révision', MboaColors.forest500),
    ('LEARNING', 'En apprentissage', MboaColors.info),
    ('WEAK', 'Fragiles', MboaColors.terre700),
    ('NEW', 'Nouveaux', MboaColors.encre400),
  ];

  static const _roleLabels = {
    'ADMIN': ('Administration', Icons.shield_rounded),
    'CULTURAL_SPECIALIST': ('Spécialiste culturel', Icons.verified_rounded),
    'ARTISAN': ('Artisan', Icons.storefront_rounded),
    'COURIER': ('Livreur', Icons.two_wheeler_rounded),
    'LEARNER': ('Apprenant', Icons.school_rounded),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final progress = ref.watch(progressProvider);
    final text = Theme.of(context).textTheme;
    final role = _roleLabels[session.role] ?? _roleLabels['LEARNER']!;

    return Scaffold(
      backgroundColor: MboaSection.profil.fond,
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) => ListView(
          padding: EdgeInsets.zero,
          children: [
            MboaGradientHeader(
              section: MboaSection.profil,
              title: session.displayName ?? 'Mon profil',
              subtitle: session.email,
              leading: _Avatar(name: session.displayName),
              actions: [
                MboaHeaderAction(
                  icon: Icons.settings_outlined,
                  tooltip: 'Modifier mon profil',
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoleBadge(label: role.$1, icon: role.$2),
                      const SizedBox(width: MboaSpace.sm),
                      _LevelBadge(xp: p.totalXp),
                    ],
                  ),
                  const SizedBox(height: MboaSpace.lg),
                  Row(
                    children: [
                      Expanded(
                        child: MboaStat(
                          value: '${p.totalXp}',
                          label: 'XP au total',
                          icon: Icons.bolt_rounded,
                          onLight: true,
                        ),
                      ),
                      const SizedBox(width: MboaSpace.sm),
                      Expanded(
                        child: MboaStat(
                          value: '${p.streakDays} j',
                          label: 'record ${p.longestStreak} j',
                          icon: Icons.local_fire_department_rounded,
                          onLight: true,
                        ),
                      ),
                      const SizedBox(width: MboaSpace.sm),
                      Expanded(
                        child: MboaStat(
                          value: '${p.lessonsCompleted}',
                          label: 'leçons',
                          icon: Icons.school_rounded,
                          onLight: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MboaSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AchievementsSection(xp: p.totalXp, streak: p.streakDays, completed: p.lessonsCompleted),
                  const SizedBox(height: MboaSpace.lg),
                  _Card(
                    title: 'Mes mots',
                    child: _Mastery(mastery: p.mastery),
                  ),
                  const SizedBox(height: MboaSpace.lg),
                  _Spaces(session: session),
                  const SizedBox(height: MboaSpace.lg),
                  _Card(
                    title: 'Mon compte',
                    child: Column(
                      children: [
                        _Line(
                          icon: Icons.manage_accounts_outlined,
                          tone: MboaTileTone.bleu,
                          title: 'Modifier mon profil',
                          subtitle:
                              'Nom affiché, objectif quotidien, mot de passe.',
                          onTap: () => context.push('/profile/edit'),
                        ),
                        _Line(
                          icon: Icons.workspace_premium_outlined,
                          tone: MboaTileTone.ambre,
                          title: 'Mes attestations',
                          subtitle:
                              'Ce que vous avez terminé, attesté et vérifiable.',
                          onTap: () => context.push('/certificates'),
                        ),
                        _Line(
                          icon: Icons.favorite_border_rounded,
                          tone: MboaTileTone.rose,
                          title: 'Mes favoris',
                          subtitle: 'Fiches et enregistrements mis de côté.',
                          onTap: () => context.push('/culture/favoris'),
                        ),
                        _Line(
                          icon: Icons.receipt_long_outlined,
                          tone: MboaTileTone.orange,
                          title: 'Mes commandes',
                          subtitle: 'Suivi des objets commandés.',
                          onTap: () => context.push('/orders'),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MboaSpace.xl),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).logout();
                      if (context.mounted) context.go('/onboarding');
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Se déconnecter'),
                  ),
                  const SizedBox(height: MboaSpace.md),
                  Center(
                    child: Text(
                      'MBOA — les contenus affichés portent leur source.',
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre400,
                      ),
                    ),
                  ),
                  const SizedBox(height: MboaSpace.xxxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: Colors.white24,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white54, width: 2),
    ),
    alignment: Alignment.center,
    child: Text(
      (name == null || name!.isEmpty)
          ? '?'
          : name!.substring(0, 1).toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
    ),
  );
}

/// Le rôle réel du compte, tel que le serveur le connaît.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: MboaSpace.md, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      ],
    ),
  );
}

/// Un bloc blanc titré.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(MboaSpace.lg),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(MboaRadius.lg),
      border: Border.all(color: MboaColors.contour),
      boxShadow: kMboaCardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: MboaSpace.md),
        child,
      ],
    ),
  );
}

/// La répartition des mots par état de maîtrise, en barres.
///
/// Des pastilles de couleur suivies d'un nombre ne se comparaient pas d'un coup
/// d'œil. Une barre proportionnelle le fait — et le nombre reste écrit, parce
/// que la couleur seule ne doit jamais porter l'information.
class _Mastery extends StatelessWidget {
  const _Mastery({required this.mastery});
  final Map<String, int> mastery;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = mastery.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return Text(
        'Terminez une leçon pour voir votre progression ici.',
        style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
      );
    }

    return Column(
      children: [
        for (final (cle, libelle, couleur) in ProfileScreen._mastery)
          if ((mastery[cle] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: MboaSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(libelle, style: text.bodyMedium)),
                      Text('${mastery[cle]}', style: text.labelLarge),
                    ],
                  ),
                  const SizedBox(height: MboaSpace.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (mastery[cle] ?? 0) / total,
                      minHeight: 8,
                      backgroundColor: MboaColors.sable100,
                      valueColor: AlwaysStoppedAnimation(couleur),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: MboaSpace.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$total mot${total > 1 ? 's' : ''} rencontré${total > 1 ? 's' : ''}',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
        ),
      ],
    );
  }
}

/// Les espaces auxquels le compte a réellement accès.
///
/// Rien n'y est proposé : on n'y voit que ce qu'on peut ouvrir. Un apprenant
/// n'y trouve donc pas ce bloc du tout — mieux vaut une section absente qu'une
/// section remplie de portes fermées.
class _Spaces extends StatelessWidget {
  const _Spaces({required this.session});
  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final lignes = <Widget>[
      if (session.isContributor)
        _Line(
          icon: Icons.edit_note_rounded,
          tone: MboaTileTone.vert,
          title: 'Espace contributeur',
          subtitle: 'Traduire et valider les mots du corpus.',
          onTap: () => context.push('/contribute'),
        ),
      if (session.isArtisan)
        _Line(
          icon: Icons.storefront_rounded,
          tone: MboaTileTone.orange,
          title: 'Ma boutique',
          subtitle: 'Objets en vente et commandes reçues.',
          onTap: () => context.push('/artisan'),
        ),
      if (session.isCourier)
        _Line(
          icon: Icons.local_shipping_rounded,
          tone: MboaTileTone.ambre,
          title: 'Mes courses',
          subtitle: 'Courses à prendre et livraisons en cours.',
          onTap: () => context.push('/courier'),
        ),
      if (session.isAdmin)
        _Line(
          icon: Icons.admin_panel_settings_rounded,
          tone: MboaTileTone.indigo,
          title: 'Administration',
          subtitle: 'Comptes, habilitations, intégrité du contenu.',
          onTap: () => context.push('/admin'),
        ),
    ];

    if (lignes.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: 'Mes espaces',
      child: Column(children: lignes),
    );
  }
}

/// Une ligne cliquable dans un bloc.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final MboaTileTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MboaRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MboaSpace.sm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(MboaRadius.sm),
                  ),
                  child: Icon(icon, color: tone.icon, size: 20),
                ),
                const SizedBox(width: MboaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: MboaColors.encre500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MboaColors.encre400,
                ),
              ],
            ),
          ),
        ),
        if (!last) const Divider(height: 1, color: MboaColors.contour),
      ],
    );
  }
}

/// Badge de niveau calculé selon l'XP accumulé.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    final level = (xp / 100).floor() + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MboaSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: MboaColors.or.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MboaColors.or, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 16, color: MboaColors.or),
          const SizedBox(width: 6),
          Text(
            'Niveau $level',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Section des succès et trophées débloqués.
class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({
    required this.xp,
    required this.streak,
    required this.completed,
  });

  final int xp;
  final int streak;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final badges = [
      (
        icon: Icons.local_fire_department_rounded,
        title: 'Flamme MBOA',
        sub: 'Série de $streak j',
        unlocked: streak >= 3,
        tone: MboaTileTone.orange,
      ),
      (
        icon: Icons.military_tech_rounded,
        title: 'Explorateur',
        sub: '$completed leçons',
        unlocked: completed >= 1,
        tone: MboaTileTone.ambre,
      ),
      (
        icon: Icons.bolt_rounded,
        title: 'Foudre de Guerre',
        sub: '$xp XP gagnés',
        unlocked: xp >= 50,
        tone: MboaTileTone.indigo,
      ),
      (
        icon: Icons.workspace_premium_rounded,
        title: 'Passionné',
        sub: 'Patrimoine',
        unlocked: completed >= 5,
        tone: MboaTileTone.vert,
      ),
    ];

    return _Card(
      title: 'Trophées & Succès',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final b in badges)
              Padding(
                padding: const EdgeInsets.only(right: MboaSpace.md),
                child: Opacity(
                  opacity: b.unlocked ? 1.0 : 0.45,
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.all(MboaSpace.md),
                    decoration: BoxDecoration(
                      color: b.unlocked ? b.tone.background : MboaColors.sable100,
                      borderRadius: BorderRadius.circular(MboaRadius.md),
                      border: Border.all(
                        color: b.unlocked ? b.tone.icon.withValues(alpha: 0.3) : MboaColors.contour,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MboaIconTile(
                          icon: b.icon,
                          tone: b.unlocked ? b.tone : MboaTileTone.indigo,
                          size: 40,
                        ),
                        const SizedBox(height: MboaSpace.sm),
                        Text(
                          b.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.sub,
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(
                            fontSize: 11,
                            color: MboaColors.encre500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

