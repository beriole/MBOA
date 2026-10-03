import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/models.dart';

/// Accès à la console d'administration.
///
/// Chaque méthode qui modifie quelque chose exige un motif : ce n'est pas une
/// politesse d'interface, c'est le contrat du serveur, qui refuse l'acte sans
/// lui et le consigne au journal.
class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<AdminDashboard> dashboard() async => AdminDashboard.fromJson(
    await _api.get('/admin/dashboard') as Map<String, dynamic>,
  );

  Future<List<AdminUser>> users({String? query, String? role}) async {
    final params = <String>[
      if (query != null && query.isNotEmpty)
        'q=${Uri.encodeQueryComponent(query)}',
      if (role != null) 'role=$role',
    ];
    final suffix = params.isEmpty ? '' : '?${params.join('&')}';
    final data = await _api.get('/admin/users$suffix');
    return (data['items'] as List)
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> changeRole(
    String userId, {
    required String role,
    required String reason,
  }) =>
      _api.post('/admin/users/$userId/role', {'role': role, 'reason': reason});

  Future<void> changeStatus(
    String userId, {
    required bool isActive,
    required String reason,
  }) => _api.post('/admin/users/$userId/status', {
    'is_active': isActive,
    'reason': reason,
  });

  Future<List<SpecialistApplication>> applications({String? status}) async {
    final suffix = status == null ? '' : '?status=$status';
    final data = await _api.get('/admin/applications$suffix') as List;
    return data
        .map((e) => SpecialistApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `decision` vaut ACCEPT, REJECT ou NEEDS_INFO.
  Future<void> decideApplication(
    String applicationId, {
    required String decision,
    required String reason,
    List<String>? grantedScope,
  }) => _api.post('/admin/applications/$applicationId/decision', {
    'decision': decision,
    'reason': reason,
    if (grantedScope != null) 'granted_scope': grantedScope,
  });

  Future<List<AuditEntry>> audit({String? action}) async {
    final suffix = action == null ? '' : '?action=$action';
    final data = await _api.get('/admin/audit$suffix') as List;
    return data
        .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlatformSetting>> settings() async {
    final data = await _api.get('/admin/settings') as List;
    return data
        .map((e) => PlatformSetting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateSetting(
    String key, {
    required Object? value,
    required String reason,
  }) => _api.put('/admin/settings/$key', {'value': value, 'reason': reason});
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

final adminDashboardProvider = FutureProvider<AdminDashboard>(
  (ref) => ref.watch(adminRepositoryProvider).dashboard(),
);

/// `null` = tous les comptes.
final adminUsersProvider = FutureProvider.family<List<AdminUser>, String?>(
  (ref, query) => ref.watch(adminRepositoryProvider).users(query: query),
);

/// `null` = toutes les demandes, y compris celles déjà traitées.
final adminApplicationsProvider =
    FutureProvider.family<List<SpecialistApplication>, String?>(
      (ref, status) =>
          ref.watch(adminRepositoryProvider).applications(status: status),
    );

final adminAuditProvider = FutureProvider<List<AuditEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).audit(),
);

final adminSettingsProvider = FutureProvider<List<PlatformSetting>>(
  (ref) => ref.watch(adminRepositoryProvider).settings(),
);
