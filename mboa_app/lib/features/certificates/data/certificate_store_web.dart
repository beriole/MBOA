import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'certificate_store.dart';

/// Web : le navigateur télécharge le fichier lui-même.
///
/// On construit un objet en mémoire, on déclenche le téléchargement, puis on
/// libère l'URL : sans cela, le PDF resterait en mémoire pour toute la durée de
/// l'onglet.
class BrowserCertificateStore implements CertificateStore {
  const BrowserCertificateStore();

  @override
  Future<String> save(String filename, Uint8List bytes) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
    // Le navigateur décide de l'emplacement : on ne connaît que le nom.
    return filename;
  }
}

CertificateStore createCertificateStore() => const BrowserCertificateStore();
