import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design/tokens.dart';
import '../data/certificates_repository.dart';
import '../domain/models.dart';

/// Ce que l'attestation n'atteste pas. Reprend mot pour mot la phrase imprimée
/// sur le PDF : l'écran et le document ne doivent pas raconter deux histoires.
const String kCertificateScope =
    'Une attestation MBOA certifie un parcours accompli dans l’application. '
    'Elle ne constitue pas une certification de niveau de langue : MBOA '
    'n’organise aucun examen et n’évalue pas la production orale.';

/// Attestations de parcours (SS15).
class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  String? _busySectionId;

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _issue(AvailableCertificate available) async {
    setState(() => _busySectionId = available.sectionId);
    try {
      await ref.read(certificatesRepositoryProvider).issue(available.sectionId);
      ref.invalidate(certificatesProvider);
      _report('Attestation délivrée.');
    } on ApiException catch (e) {
      _report(e.message);
    } finally {
      if (mounted) setState(() => _busySectionId = null);
    }
  }

  Future<void> _download(Certificate certificate) async {
    try {
      final path = await ref
          .read(certificatesRepositoryProvider)
          .download(certificate);
      _report('PDF enregistré : $path');
    } on ApiException catch (e) {
      _report(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificates = ref.watch(certificatesProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes attestations')),
      body: certificates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(certificatesProvider),
          child: ListView(
            padding: const EdgeInsets.all(MboaSpace.lg),
            children: [
              Text(
                kCertificateScope,
                style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
              ),
              const SizedBox(height: MboaSpace.xl),
              if (data.isEmpty) const _NothingYet(),
              if (data.available.isNotEmpty) ...[
                Text('À demander', style: text.titleLarge),
                const SizedBox(height: MboaSpace.md),
                for (final available in data.available)
                  _AvailableCard(
                    available: available,
                    busy: _busySectionId == available.sectionId,
                    onIssue: () => _issue(available),
                  ),
                const SizedBox(height: MboaSpace.xl),
              ],
              if (data.issued.isNotEmpty) ...[
                Text('Délivrées', style: text.titleLarge),
                const SizedBox(height: MboaSpace.md),
                for (final certificate in data.issued)
                  _CertificateCard(
                    certificate: certificate,
                    onDownload: () => _download(certificate),
                  ),
              ],
              const SizedBox(height: MboaSpace.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({
    required this.available,
    required this.busy,
    required this.onIssue,
  });

  final AvailableCertificate available;
  final bool busy;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: MboaSpace.md),
      child: Padding(
        padding: const EdgeInsets.all(MboaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(available.sectionTitle, style: text.titleMedium),
            Text(
              '${available.courseTitle} · ${available.lessonsTotal} leçon'
              '${available.lessonsTotal > 1 ? 's' : ''} terminée'
              '${available.lessonsTotal > 1 ? 's' : ''}',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
            const SizedBox(height: MboaSpace.md),
            FilledButton.icon(
              onPressed: busy ? null : onIssue,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(busy ? 'Émission…' : 'Demander l’attestation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate, required this.onDownload});

  final Certificate certificate;
  final VoidCallback onDownload;

  static String _date(DateTime value) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final d = value.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final revoked = certificate.isRevoked;

    return Container(
      margin: const EdgeInsets.only(bottom: MboaSpace.md),
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: revoked ? MboaColors.sable100 : MboaColors.forest100,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border.all(
          color: revoked ? MboaColors.sable600 : MboaColors.forest500,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                revoked ? Icons.block_rounded : Icons.workspace_premium_rounded,
                color: revoked ? MboaColors.encre500 : MboaColors.forest700,
              ),
              const SizedBox(width: MboaSpace.sm),
              Expanded(
                child: Text(certificate.sectionTitle, style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: MboaSpace.sm),
          Text(
            '${certificate.courseTitle} · ${certificate.languageName}',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
          const SizedBox(height: MboaSpace.sm),
          Text(
            '${certificate.lessonsCompleted} / ${certificate.lessonsTotal} '
            'leçon${certificate.lessonsTotal > 1 ? 's' : ''} · '
            'score moyen ${certificate.scorePercent} %',
            style: text.bodyMedium,
          ),
          Text(
            'Délivrée le ${_date(certificate.issuedAt)}',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
          const SizedBox(height: MboaSpace.md),
          SelectableText(certificate.code, style: text.titleSmall),
          Text(
            'Ce code permet à un tiers de vérifier l’attestation.',
            style: text.bodySmall?.copyWith(color: MboaColors.encre500),
          ),
          if (revoked) ...[
            const SizedBox(height: MboaSpace.md),
            Text(
              'Révoquée',
              style: text.titleSmall?.copyWith(color: MboaColors.terre700),
            ),
            if (certificate.revokedReason != null)
              Text('« ${certificate.revokedReason!} »', style: text.bodySmall),
          ] else ...[
            const SizedBox(height: MboaSpace.md),
            OutlinedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Télécharger le PDF'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MboaSpace.xl),
      decoration: BoxDecoration(
        color: MboaColors.sable100,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            size: 40,
            color: MboaColors.encre400,
          ),
          const SizedBox(height: MboaSpace.md),
          Text('Aucune attestation pour l’instant', style: text.titleLarge),
          const SizedBox(height: MboaSpace.xs),
          Text(
            'Termine toutes les leçons d’une section pour pouvoir en demander une.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
          ),
        ],
      ),
    );
  }
}
