import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'certificate_store.dart';

/// Mobile et bureau : le PDF est écrit dans les documents de l'appareil, et on
/// rend son chemin pour pouvoir le dire à la personne.
class FileCertificateStore implements CertificateStore {
  const FileCertificateStore();

  @override
  Future<String> save(String filename, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}

CertificateStore createCertificateStore() => const FileCertificateStore();
