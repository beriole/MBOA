import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class SessionState {
  const SessionState({
    required this.status,
    this.displayName,
    this.email,
    this.languageId,
    this.dailyGoalXp = 20,
    this.role = 'LEARNER',
    this.locale = 'fr',
  });

  final AuthStatus status;
  final String? displayName;

  /// L'adresse du compte. La page profil doit pouvoir montrer à qui elle
  /// appartient : c'est la première de « ses informations ».
  final String? email;

  /// Role du compte. Determine l'acces a l'espace contributeur.
  final String role;

  bool get isContributor => role == 'CULTURAL_SPECIALIST' || role == 'ADMIN';

  /// Acces a la console d'administration (SS43).
  bool get isAdmin => role == 'ADMIN';

  /// Espaces de la place de marche (SS46, SS48).
  bool get isArtisan => role == 'ARTISAN';
  bool get isCourier => role == 'COURIER';

  /// Un compte deja engage ailleurs ne se voit pas proposer de candidature.
  bool get canJoinMarket => role == 'LEARNER';

  /// Langue choisie à l'onboarding. Null tant que l'apprenant n'a pas choisi.
  final String? languageId;
  final int dailyGoalXp;

  /// Langue de l'interface, distincte de la langue apprise.
  final String locale;

  SessionState copyWith({
    AuthStatus? status,
    String? displayName,
    String? email,
    String? languageId,
    int? dailyGoalXp,
    String? role,
    String? locale,
  }) => SessionState(
    status: status ?? this.status,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    languageId: languageId ?? this.languageId,
    dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
    role: role ?? this.role,
    locale: locale ?? this.locale,
  );
}

/// Ce que l'apprenant choisit pendant l'onboarding, avant de créer son compte.
class OnboardingDraft {
  String? languageId;
  String? languageName;
  String level = 'DEBUTANT';
  int dailyGoalXp = 20;
}

final onboardingDraftProvider = Provider<OnboardingDraft>(
  (ref) => OnboardingDraft(),
);

class SessionController extends Notifier<SessionState> {
  static const _langKey = 'mboa.language_id';

  /// Copie en memoire, utilisee si les preferences sont indisponibles.
  String? _languageId;

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  SessionState build() {
    // Differe : lire un autre provider pendant `build` n'est pas autorise.
    Future(_restore);
    return const SessionState(status: AuthStatus.unknown);
  }

  /// Les preferences peuvent etre indisponibles (plateforme sans plugin) :
  /// l'application doit demarrer quand meme.
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Preferences indisponibles : $e');
      return null;
    }
  }

  Future<void> _restore() async {
    String? languageId;
    try {
      final prefs = await _prefs();
      languageId = prefs?.getString(_langKey) ?? _languageId;
      if (await _api.tokens.accessToken == null) {
        state = SessionState(
          status: AuthStatus.signedOut,
          languageId: languageId,
        );
        return;
      }
    } catch (e) {
      // Quoi qu'il arrive, l'application ne doit jamais rester sur l'ecran de
      // chargement : on repart d'une session deconnectee.
      debugPrint('Restauration de session impossible : $e');
      state = SessionState(
        status: AuthStatus.signedOut,
        languageId: languageId,
      );
      return;
    }
    try {
      final me = await _api.get('/auth/me');
      state = SessionState(
        status: AuthStatus.signedIn,
        displayName: me['display_name'] as String,
        email: me['email'] as String?,
        dailyGoalXp: me['daily_goal_xp'] as int,
        role: me['role'] as String? ?? 'LEARNER',
        locale: me['locale'] as String? ?? 'fr',
        languageId: languageId,
      );
    } catch (_) {
      await _api.tokens.clear();
      state = SessionState(
        status: AuthStatus.signedOut,
        languageId: languageId,
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final draft = ref.read(onboardingDraftProvider);
    final tokens = await _api.post('/auth/register', {
      'email': email,
      'password': password,
      'display_name': displayName,
      'daily_goal_xp': draft.dailyGoalXp,
    });
    await _api.tokens.save(tokens['access_token'], tokens['refresh_token']);
    if (draft.languageId != null) await selectLanguage(draft.languageId!);
    state = state.copyWith(
      status: AuthStatus.signedIn,
      displayName: displayName,
      dailyGoalXp: draft.dailyGoalXp,
    );
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _api.tokens.save(tokens['access_token'], tokens['refresh_token']);
    await _restore();
  }

  /// Relit le profil depuis le serveur.
  ///
  /// Utilise apres la configuration initiale, qui a pu changer l'objectif
  /// quotidien : l'etat local ne doit pas rester en retard sur la base.
  Future<void> refresh() => _restore();

  /// Modifie le profil cote serveur, puis recopie la reponse dans l'etat.
  ///
  /// C'est le serveur qui fait foi : on n'affiche pas une valeur qu'il
  /// aurait refusee.
  Future<void> updateProfile({
    String? displayName,
    int? dailyGoalXp,
    String? locale,
  }) async {
    final updated = await _api.patch('/auth/me', {
      if (displayName != null) 'display_name': displayName,
      if (dailyGoalXp != null) 'daily_goal_xp': dailyGoalXp,
      if (locale != null) 'locale': locale,
    });
    state = state.copyWith(
      displayName: updated['display_name'] as String,
      dailyGoalXp: updated['daily_goal_xp'] as int,
      locale: updated['locale'] as String,
    );
  }

  Future<void> selectLanguage(String languageId) async {
    _languageId = languageId;
    final prefs = await _prefs();
    await prefs?.setString(_langKey, languageId);
    state = state.copyWith(languageId: languageId);
  }

  Future<void> logout() async {
    await _api.tokens.clear();
    state = SessionState(
      status: AuthStatus.signedOut,
      languageId: state.languageId,
    );
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
