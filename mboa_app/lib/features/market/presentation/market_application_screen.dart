import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/market_repository.dart';
import 'courier_screen.dart' show kVehicleLabels;

/// Candidature artisan ou livreur (SS43, SS46, SS48).
///
/// MBOA ne demande **aucune pièce d'identité en ligne** : elle n'a pas de
/// responsable de traitement à qui confier des documents officiels. La
/// vérification se fait de vive voix, et c'est ce qui aura été présenté qui
/// sera consigné. L'écran le dit avant la saisie, pour que personne ne s'attende
/// à téléverser une carte nationale.
class MarketApplicationScreen extends ConsumerStatefulWidget {
  const MarketApplicationScreen({super.key, required this.role});

  /// `ARTISAN` ou `COURIER`.
  final String role;

  @override
  ConsumerState<MarketApplicationScreen> createState() =>
      _MarketApplicationScreenState();
}

class _MarketApplicationScreenState
    extends ConsumerState<MarketApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activity = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  String _vehicle = 'MOTORCYCLE';
  bool _sending = false;
  String? _error;

  bool get _isCourier => widget.role == 'COURIER';

  @override
  void dispose() {
    _activity.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(marketRepositoryProvider)
          .apply(
            role: widget.role,
            activity: _activity.text.trim(),
            city: _city.text.trim(),
            phone: _phone.text.trim(),
            vehicle: _isCourier ? _vehicle : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dossier envoyé. Il sera examiné par un administrateur.',
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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCourier ? 'Devenir livreur' : 'Devenir artisan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(MboaSpace.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(MboaSpace.md),
              decoration: BoxDecoration(
                color: MboaColors.sable100,
                borderRadius: BorderRadius.circular(MboaRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: MboaColors.encre500,
                  ),
                  const SizedBox(width: MboaSpace.sm),
                  Expanded(
                    child: Text(
                      'MBOA ne vous demandera aucune pièce d’identité ici. La '
                      'vérification se fait lors d’une rencontre ; ce qui aura été '
                      'présenté sera noté au dossier, mais aucun document ne sera '
                      'conservé.',
                      style: text.bodySmall?.copyWith(
                        color: MboaColors.encre500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MboaSpace.xl),
            TextFormField(
              controller: _activity,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: _isCourier
                    ? 'Votre activité de livraison'
                    : 'Votre métier',
                helperText: _isCourier
                    ? 'Depuis quand livrez-vous, dans quelles zones ?'
                    : 'Que fabriquez-vous, depuis quand, où vendez-vous ?',
                helperMaxLines: 2,
              ),
              validator: (value) => (value ?? '').trim().length < 20
                  ? 'Quelques phrases sont nécessaires pour examiner le dossier.'
                  : null,
            ),
            const SizedBox(height: MboaSpace.md),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Indiquez votre ville.'
                  : null,
            ),
            const SizedBox(height: MboaSpace.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                helperText:
                    'C’est par là qu’on vous joindra pour la vérification.',
              ),
              validator: (value) =>
                  (value ?? '').trim().length < 6 ? 'Numéro incomplet.' : null,
            ),
            if (_isCourier) ...[
              const SizedBox(height: MboaSpace.lg),
              DropdownButtonFormField<String>(
                initialValue: _vehicle,
                decoration: const InputDecoration(
                  labelText: 'Moyen de déplacement',
                ),
                items: [
                  for (final entry in kVehicleLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => _vehicle = value!),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: MboaSpace.lg),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: MboaColors.erreur),
              ),
            ],
            const SizedBox(height: MboaSpace.xl),
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? 'Envoi…' : 'Envoyer mon dossier'),
            ),
            const SizedBox(height: MboaSpace.md),
            Text(
              'Un administrateur vous recontactera. Sa décision sera motivée et '
              'consignée.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ],
        ),
      ),
    );
  }
}
