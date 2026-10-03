import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import 'admin_widgets.dart';
import 'reason_dialog.dart';

/// Nom lisible des paramètres.
///
/// L'écran affichait `review_required_before_publish` en gros comme titre : une
/// clé de base de données, en anglais, en minuscules soulignées. Le libellé
/// français passe devant ; la clé reste visible en petit, parce qu'un
/// administrateur qui ouvre un ticket a besoin de la citer exactement.
/// Les quatre clés sont celles que le serveur crée réellement
/// (`DEFAULT_SETTINGS`, `app/modules/admin/router.py`). Une clé ajoutée plus
/// tard sans libellé ici s'affichera sous son nom technique : c'est laid, mais
/// honnête, et préférable à un libellé deviné.
const Map<String, String> _settingLabels = {
  'registration_open': 'Inscriptions ouvertes',
  'default_daily_goal_xp': 'Objectif quotidien par défaut',
  'review_required_before_publish': 'Relecture obligatoire avant publication',
  'support_email': 'Adresse de contact affichée aux utilisateurs',
};

/// Paramètres de la plateforme (SS43).
///
/// Volontairement peu nombreux. Un paramètre ici est un choix de politique ;
/// les réglages techniques restent dans la configuration du serveur. Et l'un
/// d'eux est verrouillé : la relecture avant publication est appliquée par la
/// base de données, elle ne se débranche pas depuis un écran.
class AdminSettingsView extends ConsumerStatefulWidget {
  const AdminSettingsView({super.key});

  @override
  ConsumerState<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends ConsumerState<AdminSettingsView> {
  static String _label(PlatformSetting setting) =>
      _settingLabels[setting.key] ?? setting.key;

  Future<void> _edit(PlatformSetting setting) async {
    final Object? value;
    if (setting.value is bool) {
      value = !(setting.value as bool);
    } else {
      final entered = await _askValue(setting);
      if (entered == null) return;
      value = setting.value is int ? int.tryParse(entered) : entered;
      if (value == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ce paramètre attend un nombre entier.'),
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;

    final reason = await askReason(
      context,
      title: 'Modifier « ${_label(setting)} »',
      action: 'Enregistrer',
    );
    if (reason == null) return;

    try {
      await ref
          .read(adminRepositoryProvider)
          .updateSetting(setting.key, value: value, reason: reason);
      ref.invalidate(adminSettingsProvider);
      ref.invalidate(adminAuditProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<String?> _askValue(PlatformSetting setting) {
    final controller = TextEditingController(text: '${setting.value}');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_label(setting)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            const SizedBox(height: MboaSpace.md),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: setting.value is int
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: const InputDecoration(labelText: 'Nouvelle valeur'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(adminSettingsProvider);

    return settings.when(
      loading: () => const AdminLoading(),
      error: (e, _) => AdminError(
        message: '$e',
        onRetry: () => ref.invalidate(adminSettingsProvider),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminSettingsProvider),
        child: ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            const AdminNotice(
              message:
                  'Chaque modification est inscrite au journal avec son motif. '
                  'Les réglages marqués d’un cadenas sont tenus par la base de '
                  'données : aucun écran ne peut les débrancher.',
            ),
            const SizedBox(height: MboaSpace.lg),
            for (final setting in list)
              Padding(
                padding: const EdgeInsets.only(bottom: MboaSpace.md),
                child: _SettingCard(
                  setting: setting,
                  label: _label(setting),
                  onEdit: () => _edit(setting),
                ),
              ),
            if (list.isEmpty)
              const AdminEmpty(
                icon: Icons.tune_rounded,
                title: 'Aucun paramètre',
                message:
                    'Le serveur n’expose pour l’instant aucun réglage de '
                    'politique modifiable depuis cet écran.',
              ),
            const SizedBox(height: MboaSpace.xxl),
          ],
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.setting,
    required this.label,
    required this.onEdit,
  });

  final PlatformSetting setting;
  final String label;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final verrouille = !setting.isEditable;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(
          color: verrouille
              ? MboaColors.terre700.withValues(alpha: 0.35)
              : MboaColors.contour,
        ),
      ),
      child: InkWell(
        onTap: setting.isEditable ? onEdit : null,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(MboaSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      setting.description,
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                    const SizedBox(height: MboaSpace.sm),
                    AdminTag(setting.key, icon: Icons.key_outlined),
                  ],
                ),
              ),
              const SizedBox(width: MboaSpace.md),
              if (verrouille)
                const Tooltip(
                  message: 'Règle appliquée par la base de données',
                  child: Icon(Icons.lock_rounded, color: MboaColors.terre700),
                )
              else
                _Value(setting: setting, onTap: onEdit),
            ],
          ),
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.setting, required this.onTap});
  final PlatformSetting setting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (setting.value is bool) {
      return Switch(value: setting.value as bool, onChanged: (_) => onTap());
    }
    // La valeur dans une pastille, pas en texte nu : on voit qu'elle se touche.
    return Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: MboaSpace.md),
      decoration: BoxDecoration(
        color: MboaSection.administration.fond,
        borderRadius: BorderRadius.circular(MboaRadius.sm),
        border: Border.all(color: MboaColors.contour),
      ),
      child: Text(
        '${setting.value}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: MboaSection.administration.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
