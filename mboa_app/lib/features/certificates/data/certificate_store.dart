import 'dart:typed_data';

import 'certificate_store_io.dart'
    if (dart.library.js_interop) 'certificate_store_web.dart';

/// Où déposer le PDF d'une attestation.
///
/// Les deux plateformes n'ont pas la même notion de « enregistrer un fichier » :
/// sur mobile et bureau, on écrit dans les documents de l'appareil ; sur le web,
/// on déclenche un téléchargement du navigateur. L'import conditionnel choisit
/// l'implémentation à la compilation — `dart:io` n'existe pas sur le web, et
/// sa seule présence empêcherait la compilation.
abstract class CertificateStore {
  Future<String> save(String filename, Uint8List bytes);
}

/// L'implémentation de la plateforme courante.
CertificateStore defaultCertificateStore() => createCertificateStore();
