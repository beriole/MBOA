import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/models.dart';
import 'certificate_store.dart';

class CertificatesRepository {
  CertificatesRepository(this._api, this._store);

  final ApiClient _api;
  final CertificateStore _store;

  Future<CertificateList> list() async => CertificateList.fromJson(
    await _api.get('/me/certificates') as Map<String, dynamic>,
  );

  Future<Certificate> issue(String sectionId) async => Certificate.fromJson(
    await _api.post('/me/certificates', {'section_id': sectionId})
        as Map<String, dynamic>,
  );

  /// Télécharge le PDF et le dépose dans les documents de l'appareil.
  /// Renvoie le chemin du fichier écrit.
  Future<String> download(Certificate certificate) async {
    final bytes = await _api.bytes('/me/certificates/${certificate.id}/pdf');
    return _store.save('attestation-${certificate.code}.pdf', bytes);
  }

  /// Vérification publique, telle qu'un tiers l'obtiendrait — sans jeton.
  Future<Map<String, dynamic>> verify(String code) async =>
      await _api.get('/certificates/verify/$code') as Map<String, dynamic>;
}

final certificateStoreProvider = Provider<CertificateStore>(
  (ref) => defaultCertificateStore(),
);

final certificatesRepositoryProvider = Provider<CertificatesRepository>(
  (ref) => CertificatesRepository(
    ref.watch(apiClientProvider),
    ref.watch(certificateStoreProvider),
  ),
);

final certificatesProvider = FutureProvider<CertificateList>(
  (ref) => ref.watch(certificatesRepositoryProvider).list(),
);
