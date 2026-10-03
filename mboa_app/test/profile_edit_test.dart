import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/core/api_client.dart';
import 'package:mboa_app/features/auth/auth_controller.dart';
import 'package:mboa_app/features/profile/profile_edit_screen.dart';

/// Session pilotée par le test, qui retient ce que l'écran lui demande.
class _FakeSession extends SessionController {
  _FakeSession(this._initial);
  final SessionState _initial;

  Map<String, Object?>? saved;
  Object? failure;

  @override
  SessionState build() => _initial;

  @override
  Future<void> updateProfile({
    String? displayName,
    int? dailyGoalXp,
    String? locale,
  }) async {
    if (failure != null) throw failure!;
    saved = {
      'display_name': displayName,
      'daily_goal_xp': dailyGoalXp,
      'locale': locale,
    };
    state = state.copyWith(
      displayName: displayName,
      dailyGoalXp: dailyGoalXp,
      locale: locale,
    );
  }
}

Future<_FakeSession> _pump(WidgetTester tester, {SessionState? initial}) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final session = _FakeSession(
    initial ??
        const SessionState(
          status: AuthStatus.signedIn,
          displayName: 'Ama',
          dailyGoalXp: 20,
          locale: 'fr',
        ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(() => session)],
      child: const MaterialApp(home: ProfileEditScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('le formulaire part des valeurs du compte', (tester) async {
    await _pump(tester);

    expect(find.widgetWithText(TextFormField, 'Ama'), findsOneWidget);
    expect(find.text('Objectif quotidien'), findsOneWidget);
    // L'e-mail et le rôle ne sont pas modifiables ici.
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('Rôle'), findsNothing);
  });

  testWidgets('un nom vide est refusé avant tout appel', (tester) async {
    final session = await _pump(tester);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Un nom est nécessaire.'), findsOneWidget);
    expect(session.saved, isNull);
  });

  testWidgets('les modifications sont envoyées au serveur', (tester) async {
    final session = await _pump(tester);

    await tester.enterText(find.byType(TextFormField), 'Ama Ndongo');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(session.saved, {
      'display_name': 'Ama Ndongo',
      'daily_goal_xp': 20,
      'locale': 'en',
    });
  });

  testWidgets('un refus du serveur reste affiché à l’écran', (tester) async {
    final session = await _pump(tester);
    session.failure = ApiException(
      'Certaines informations sont invalides. Vérifie le formulaire.',
      statusCode: 422,
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Le message du serveur est repris tel quel, et l'ecran ne se ferme pas.
    expect(
      find.text(
        'Certaines informations sont invalides. Vérifie le formulaire.',
      ),
      findsOneWidget,
    );
    expect(find.text('Modifier mon profil'), findsOneWidget);
  });

  testWidgets('le changement de mot de passe annonce ses conséquences', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Changer mon mot de passe'));
    await tester.pumpAndSettle();

    expect(find.text('Mot de passe actuel'), findsOneWidget);
    expect(find.text('Nouveau mot de passe'), findsOneWidget);
    expect(
      find.textContaining(
        'sessions ouvertes sur tes autres appareils seront fermées',
      ),
      findsOneWidget,
    );
  });

  test('l’état de session porte la langue d’interface', () {
    const state = SessionState(status: AuthStatus.signedIn);
    expect(state.locale, 'fr');
    expect(state.copyWith(locale: 'en').locale, 'en');
    // Le rôle par défaut n'ouvre aucun espace réservé.
    expect(state.isContributor, isFalse);
    expect(state.isAdmin, isFalse);
  });
}
