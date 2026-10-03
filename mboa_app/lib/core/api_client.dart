import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Adresse de l'API. Surchargeable :
///   flutter run --dart-define=API_BASE=http://10.0.2.2:8010   (émulateur Android)
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:8010',
);

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Stockage des jetons : Keystore / Keychain sur mobile.
///
/// Si le stockage sécurisé est indisponible (appareil sans coffre-fort,
/// plateforme non supportée, environnement de test), on retombe sur une copie
/// en mémoire : la session dure alors le temps du lancement, mais l'application
/// ne se bloque jamais.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, String> _memory = {};
  static const _access = 'mboa.access';
  static const _refresh = 'mboa.refresh';

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key) ?? _memory[key];
    } catch (e) {
      debugPrint('Stockage sécurisé indisponible en lecture : $e');
      return _memory[key];
    }
  }

  Future<void> _write(String key, String? value) async {
    if (value == null) {
      _memory.remove(key);
    } else {
      _memory[key] = value;
    }
    try {
      value == null
          ? await _storage.delete(key: key)
          : await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Stockage sécurisé indisponible en écriture : $e');
    }
  }

  Future<String?> get accessToken => _read(_access);

  Future<String?> get refreshToken => _read(_refresh);

  Future<void> save(String access, String refresh) async {
    await _write(_access, access);
    await _write(_refresh, refresh);
  }

  Future<void> clear() async {
    await _write(_access, null);
    await _write(_refresh, null);
  }
}

/// Client HTTP : ajoute le jeton, et le renouvelle une fois en cas d'expiration.
class ApiClient {
  ApiClient(this._tokens, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: '$kApiBase/api/v1',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.accessToken;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) async {
          // Connexion coupée avant toute réponse : la requête n'a très
          // probablement pas été traitée. On réessaie une fois — les tentatives
          // d'exercice portent un identifiant client, donc un doublon éventuel
          // est ignoré par le serveur.
          const transient = {
            DioExceptionType.connectionError,
            DioExceptionType.connectionTimeout,
          };
          if (transient.contains(error.type) &&
              error.requestOptions.extra['mboa_retried'] != true) {
            final retry = error.requestOptions..extra['mboa_retried'] = true;
            try {
              return handler.resolve(await _dio.fetch(retry));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }

          final isAuthRoute = error.requestOptions.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 &&
              !isAuthRoute &&
              await _refresh()) {
            final retry = error.requestOptions;
            retry.headers['Authorization'] =
                'Bearer ${await _tokens.accessToken}';
            try {
              return handler.resolve(await _dio.fetch(retry));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStore _tokens;

  TokenStore get tokens => _tokens;

  Future<bool> _refresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await Dio(
        BaseOptions(baseUrl: _dio.options.baseUrl),
      ).post('/auth/refresh', data: {'refresh_token': refresh});
      await _tokens.save(res.data['access_token'], res.data['refresh_token']);
      return true;
    } catch (_) {
      await _tokens.clear();
      return false;
    }
  }

  Future<dynamic> get(String path) => _call(() => _dio.get(path));

  Future<dynamic> post(String path, [Object? body]) =>
      _call(() => _dio.post(path, data: body ?? const {}));

  Future<dynamic> patch(String path, [Object? body]) =>
      _call(() => _dio.patch(path, data: body ?? const {}));

  Future<dynamic> put(String path, [Object? body]) =>
      _call(() => _dio.put(path, data: body ?? const {}));

  Future<dynamic> delete(String path) => _call(() => _dio.delete(path));

  /// Envoie un fichier en `multipart/form-data`.
  ///
  /// Les octets sont passés en mémoire plutôt que par un chemin de fichier :
  /// sur le web il n'y a pas de système de fichiers accessible, et le même
  /// code doit servir les deux plateformes.
  Future<dynamic> upload(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
  }) => _call(
    () => _dio.post(
      path,
      data: FormData.fromMap({
        field: MultipartFile.fromBytes(bytes, filename: filename),
      }),
    ),
  );

  /// Télécharge un fichier binaire (une attestation PDF, par exemple) en
  /// réutilisant le client déjà porteur du jeton.
  Future<Uint8List> bytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      // Le corps d'erreur arrive lui aussi en octets : on le relit en JSON
      // pour retrouver le message du serveur plutôt qu'un texte générique.
      final data = e.response?.data;
      if (data is List<int>) {
        try {
          final decoded = jsonDecode(utf8.decode(data));
          if (decoded is Map && decoded['detail'] is String) {
            throw ApiException(
              decoded['detail'] as String,
              statusCode: e.response?.statusCode,
            );
          }
        } on FormatException {
          // Corps illisible : on retombe sur le message générique.
        }
      }
      throw ApiException(_messageFrom(e), statusCode: e.response?.statusCode);
    }
  }

  Future<dynamic> _call(Future<Response> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      throw ApiException(_messageFrom(e), statusCode: e.response?.statusCode);
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (data is Map && data['detail'] is List) {
      return 'Certaines informations sont invalides. Vérifie le formulaire.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return "Impossible de joindre le serveur MBOA ($kApiBase).";
    }
    debugPrint('Erreur API : $e');
    return 'Une erreur est survenue. Réessaie dans un instant.';
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStoreProvider)),
);
