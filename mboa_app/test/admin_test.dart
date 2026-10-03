import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/admin/data/admin_repository.dart';
import 'package:mboa_app/features/admin/domain/models.dart';
import 'package:mboa_app/features/admin/presentation/admin_applications_view.dart';
import 'package:mboa_app/features/admin/presentation/admin_audit_view.dart';
import 'package:mboa_app/features/admin/presentation/admin_console_screen.dart';
import 'package:mboa_app/features/admin/presentation/admin_dashboard_view.dart';
import 'package:mboa_app/features/admin/presentation/admin_settings_view.dart';
import 'package:mboa_app/features/admin/presentation/admin_users_view.dart';
import 'package:mboa_app/features/admin/presentation/admin_widgets.dart';
import 'package:mboa_app/design/tokens.dart';
import 'package:mboa_app/design/widgets/mboa_header.dart';
import 'package:mboa_app/design/widgets/mboa_header_tabs.dart';
import 'package:mboa_app/features/auth/auth_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AdminRepository {}

/// Session figée : la console vérifie le rôle avant de s'afficher.
class _FakeSession extends SessionController {
  _FakeSession(this._role);
  final String _role;

  @override
  SessionState build() =>
      SessionState(status: AuthStatus.signedIn, role: _role);
}

Map<String, dynamic> _dashboardJson({
  int anomalies = 0,
  int motsARelire = 12,
}) => {
  'comptes': {
    'total': 34,
    'par_role': [
      {'role': 'LEARNER', 'total': 30, 'actifs': 29},
      {'role': 'CULTURAL_SPECIALIST', 'total': 3, 'actifs': 3},
      {'role': 'ADMIN', 'total': 1, 'actifs': 1},
    ],
    'connectes_7j': 11,
    'inscrits_30j': 34,
    'jamais_connectes': 2,
  },
  'corpus': {
    'par_langue': [
      {
        'id': 'l1',
        'iso639_3': 'bas',
        'name': 'Basaa',
        'total': 120,
        'publies': 30,
        'valides': 4,
        'en_attente': 86,
        'sans_glose': 70,
      },
    ],
    'par_statut': [
      {'statut': 'TO_VERIFY', 'total': 86},
    ],
  },
  'licences': [
    {'licence': 'CC0', 'sources': 1, 'mots': 120, 'mots_publies': 30},
    {
      'licence': 'COPYRIGHT_NO_AGREEMENT',
      'sources': 2,
      'mots': 0,
      'mots_publies': 0,
    },
  ],
  'contenu': {
    'exercices_publies': 8,
    'exercices_en_attente': 2,
    'lecons': 5,
    'fiches_publiees': 3,
    'rubriques': 16,
    'rubriques_vides': 13,
    'enregistrements': 105,
  },
  'activite': {
    'sessions': 9,
    'tentatives': 140,
    'tentatives_7j': 42,
    'traductions': 22,
    'traductions_sans_reponse': 7,
  },
  'a_traiter': {
    'mots_a_relire': motsARelire,
    'exercices_a_relire': 2,
    'fiches_a_relire': 1,
    'demandes_habilitation': 3,
    'habilitations_actives': 4,
  },
  'integrite': {
    'conforme': anomalies == 0,
    'anomalies_totales': anomalies,
    'controles': [
      {
        'code': 'lexique_publie_sans_source',
        'libelle': 'Mots publies sans source identifiee',
        'anomalies': anomalies,
        'conforme': anomalies == 0,
      },
      {
        'code': 'fiches_auto_validees',
        'libelle': 'Fiches culturelles validees par leur propre auteur',
        'anomalies': 0,
        'conforme': true,
      },
    ],
  },
  'chantiers_ouverts': [
    {
      'domaine': 'Paiements et abonnements',
      'etat': 'non implemente',
      'raison':
          'aucune entite juridique ni compte marchand a ce stade du projet',
    },
  ],
};

final _application = SpecialistApplication.fromJson({
  'id': 'a1',
  'status': 'PENDING',
  'user_id': 'u1',
  'display_name': 'Ngo Bassong',
  'email': 'contact@example.org',
  'language_name': 'Basaa',
  'claimed_role': 'NATIVE_SPEAKER',
  'relationship_fr': 'Langue maternelle, parlee en famille depuis l’enfance.',
  'requested_scope': ['LEXICON', 'AUDIO'],
  'affiliation': 'Association culturelle de Douala',
  'referees_fr': 'La presidente de l’association peut confirmer.',
  'evidence_url': null,
  'review_note': null,
});

final _audit = AuditEntry.fromJson({
  'id': 'j1',
  'actor_label': 'Admin <admin@example.org>',
  'action': 'USER_ROLE_CHANGED',
  'target_type': 'USER',
  'target_id': 'u1',
  'target_label': 'contact@example.org',
  'reason': 'Candidature acceptee en reunion du 12 mars.',
  'details': {'avant': 'LEARNER', 'apres': 'CULTURAL_SPECIALIST'},
  'created_at': '2026-03-12T10:30:00+00:00',
});

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  AdminRepository? repo,
  String role = 'ADMIN',
}) async {
  tester.view.physicalSize = const Size(1100, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repo != null) adminRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith(() => _FakeSession(role)),
      ],
      child: MaterialApp(home: Scaffold(body: screen)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('tableau de bord', () {
    testWidgets('l’intégrité passe avant les chiffres d’usage', (tester) async {
      final repo = _MockRepo();
      when(
        repo.dashboard,
      ).thenAnswer((_) async => AdminDashboard.fromJson(_dashboardJson()));

      await _pump(tester, const AdminDashboardView(), repo: repo);
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun contenu publié n’échappe aux règles'),
        findsOneWidget,
      );
      expect(find.text('Mots publies sans source identifiee'), findsOneWidget);

      // La bannière d'intégrité est bien au-dessus du bloc d'usage.
      final banniere = tester.getTopLeft(
        find.text('Aucun contenu publié n’échappe aux règles'),
      );
      final usage = tester.getTopLeft(find.text('Comptes et usage'));
      expect(banniere.dy, lessThan(usage.dy));
    });

    testWidgets('une anomalie est annoncée, pas noyée', (tester) async {
      final repo = _MockRepo();
      when(repo.dashboard).thenAnswer(
        (_) async => AdminDashboard.fromJson(_dashboardJson(anomalies: 2)),
      );

      await _pump(tester, const AdminDashboardView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('2 contenu(s) hors règles'), findsOneWidget);
    });

    testWidgets('les modules non branchés disent pourquoi', (tester) async {
      final repo = _MockRepo();
      when(
        repo.dashboard,
      ).thenAnswer((_) async => AdminDashboard.fromJson(_dashboardJson()));

      await _pump(tester, const AdminDashboardView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Paiements et abonnements'), findsOneWidget);
      expect(find.textContaining('aucune entite juridique'), findsOneWidget);
    });

    testWidgets('les licences restrictives sont distinguées', (tester) async {
      final repo = _MockRepo();
      when(
        repo.dashboard,
      ).thenAnswer((_) async => AdminDashboard.fromJson(_dashboardJson()));

      await _pump(tester, const AdminDashboardView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('CC0 — domaine public'), findsOneWidget);
      expect(find.text('Sous droit d’auteur, sans accord'), findsOneWidget);
      // Le cadenas marque ce qui ne peut pas être rediffusé.
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });
  });

  group('comptes', () {
    testWidgets('un acte non motivé ne peut pas être confirmé', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.users(
          query: any(named: 'query'),
          role: any(named: 'role'),
        ),
      ).thenAnswer(
        (_) async => [
          AdminUser.fromJson({
            'id': 'u1',
            'email': 'contact@example.org',
            'display_name': 'Ngo Bassong',
            'role': 'CULTURAL_SPECIALIST',
            'is_active': true,
            'habilitations': 1,
          }),
        ],
      );

      await _pump(tester, const AdminUsersView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Spécialiste culturel'), findsOneWidget);
      expect(find.text('1 langue(s) habilitée(s)'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Désactiver le compte'));
      await tester.pumpAndSettle();

      expect(find.textContaining('inscrit au journal'), findsOneWidget);
      final bouton = find.widgetWithText(FilledButton, 'Désactiver');
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);

      await tester.enterText(
        find.byType(TextField).last,
        'Départ de l’organisation.',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(bouton).onPressed, isNotNull);

      when(
        () => repo.changeStatus(
          any(),
          isActive: any(named: 'isActive'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      await tester.tap(bouton);
      await tester.pumpAndSettle();

      verify(
        () => repo.changeStatus(
          'u1',
          isActive: false,
          reason: 'Départ de l’organisation.',
        ),
      ).called(1);
    });
  });

  group('demandes d’habilitation', () {
    testWidgets('le dossier est affiché en entier', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.applications(status: any(named: 'status')),
      ).thenAnswer((_) async => [_application]);

      await _pump(tester, const AdminApplicationsView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Ngo Bassong'), findsOneWidget);
      expect(find.text('RAPPORT À LA LANGUE'), findsOneWidget);
      expect(find.text('QUI PEUT EN RÉPONDRE'), findsOneWidget);
      expect(find.text('Basaa'), findsOneWidget);
      expect(find.text('Locuteur natif'), findsOneWidget);
    });

    testWidgets('habiliter exige un motif et le transmet', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.applications(status: any(named: 'status')),
      ).thenAnswer((_) async => [_application]);
      when(
        () => repo.decideApplication(
          any(),
          decision: any(named: 'decision'),
          reason: any(named: 'reason'),
          grantedScope: any(named: 'grantedScope'),
        ),
      ).thenAnswer((_) async {});

      await _pump(tester, const AdminApplicationsView(), repo: repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Habiliter'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'Entretien mené, deux références confirment.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Habiliter'));
      await tester.pumpAndSettle();

      verify(
        () => repo.decideApplication(
          'a1',
          decision: 'ACCEPT',
          reason: 'Entretien mené, deux références confirment.',
        ),
      ).called(1);
    });

    testWidgets('sans demande, l’écran explique d’où elles viennent', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        () => repo.applications(status: any(named: 'status')),
      ).thenAnswer((_) async => []);

      await _pump(tester, const AdminApplicationsView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Aucune demande en attente'), findsOneWidget);
      expect(find.textContaining('depuis leur profil'), findsOneWidget);
    });
  });

  group('paramètres', () {
    testWidgets('la règle de relecture est verrouillée', (tester) async {
      final repo = _MockRepo();
      when(repo.settings).thenAnswer(
        (_) async => [
          PlatformSetting.fromJson({
            'key': 'review_required_before_publish',
            'value': true,
            'description_fr':
                'Relecture humaine obligatoire avant publication.',
            'is_editable': false,
          }),
          PlatformSetting.fromJson({
            'key': 'default_daily_goal_xp',
            'value': 20,
            'description_fr': 'Objectif quotidien propose par defaut.',
            'is_editable': true,
          }),
        ],
      );

      await _pump(tester, const AdminSettingsView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      // Aucun interrupteur n'est offert pour la règle verrouillée.
      expect(find.byType(Switch), findsNothing);
      expect(find.text('20'), findsOneWidget);
    });
  });

  group('journal', () {
    testWidgets('chaque acte montre son motif et son auteur', (tester) async {
      final repo = _MockRepo();
      when(
        () => repo.audit(action: any(named: 'action')),
      ).thenAnswer((_) async => [_audit]);

      await _pump(tester, const AdminAuditView(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Rôle modifié'), findsOneWidget);
      expect(
        find.text('« Candidature acceptee en reunion du 12 mars. »'),
        findsOneWidget,
      );
      expect(find.text('par Admin <admin@example.org>'), findsOneWidget);
      // Les codes de role sont traduits : le journal se lit sans glossaire.
      expect(find.text('Apprenant → Spécialiste culturel'), findsOneWidget);
      expect(
        find.textContaining('Aucune fonction ne permet d’en effacer'),
        findsOneWidget,
      );
    });
  });

  group('console', () {
    testWidgets('elle est refusée à qui n’est pas administrateur', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdminConsoleScreen(),
        role: 'CULTURAL_SPECIALIST',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Cet espace est réservé aux administrateurs.'),
        findsOneWidget,
      );
      // Ni les onglets ni aucun des cinq écrans ne sont construits : le refus
      // n'est pas un voile posé par-dessus une console déjà chargée.
      expect(find.byType(MboaHeaderTabs), findsNothing);
      expect(find.byType(AdminDashboardView), findsNothing);
    });

    testWidgets('les cinq onglets portent la couleur de la console', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        repo.dashboard,
      ).thenAnswer((_) async => AdminDashboard.fromJson(_dashboardJson()));
      when(
        () => repo.users(
          query: any(named: 'query'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async => []);

      await _pump(tester, const AdminConsoleScreen(), repo: repo);
      await tester.pumpAndSettle();

      // La recherche est bornée aux onglets : « Comptes » est aussi le
      // libellé d'un chiffre du tableau de bord, et un `find.text` global
      // compterait les deux.
      final onglets = find.byType(MboaHeaderTabs);
      for (final onglet in [
        'Tableau de bord',
        'Comptes',
        'Demandes',
        'Paramètres',
        'Journal',
      ]) {
        expect(
          find.descendant(of: onglets, matching: find.text(onglet)),
          findsOneWidget,
          reason: 'onglet « $onglet »',
        );
      }

      // Le dégradé de l'en-tête est celui de l'administration, et aucun des
      // cinq dégradés publics : la console est un espace, pas une section.
      final entete = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MboaGradientHeader),
              matching: find.byType(Container),
            )
            .first,
      );
      final gradient =
          (entete.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, MboaSection.administration.gradient);
    });

    testWidgets('les files d’attente s’affichent sur les onglets', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(
        repo.dashboard,
      ).thenAnswer((_) async => AdminDashboard.fromJson(_dashboardJson()));
      when(
        () => repo.users(
          query: any(named: 'query'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async => []);

      await _pump(tester, const AdminConsoleScreen(), repo: repo);
      await tester.pumpAndSettle();

      // 12 mots + 2 exercices + 1 fiche à relire sur l'onglet du tableau de
      // bord, 3 demandes sur celui des habilitations. Un administrateur voit
      // ce qui l'attend sans ouvrir les onglets.
      final onglets = find.byType(MboaHeaderTabs);
      expect(
        find.descendant(of: onglets, matching: find.text('15')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: onglets, matching: find.text('3')),
        findsOneWidget,
      );
      expect(find.text('18 décision(s) en attente'), findsOneWidget);
    });
  });

  group('mise en page', () {
    test('la grille de chiffres suit la largeur et le grossissement', () {
      // Un téléphone : deux colonnes. À 200 %, une seule — trois libellés
      // comme « Demandes d’habilitation » côte à côte seraient coupés.
      expect(AdminStatGrid.colonnes(358, 1.0), 2);
      expect(AdminStatGrid.colonnes(358, 2.0), 1);
      // Une tablette en paysage : quatre.
      expect(AdminStatGrid.colonnes(1000, 1.0), 4);
    });

    // Les cinq écrans, au même grossissement. Le défaut trouvé par ce test au
    // tableau de bord — une étiquette « non implémenté » de 374 px dans 326
    // disponibles — pouvait se reproduire partout où une pastille voisine un
    // texte extensible : il est donc vérifié sur les cinq, pas sur un seul.
    for (final (nom, vue) in const [
      ('tableau de bord', AdminDashboardView()),
      ('comptes', AdminUsersView()),
      ('demandes', AdminApplicationsView()),
      ('paramètres', AdminSettingsView()),
      ('journal', AdminAuditView()),
    ]) {
      testWidgets('rien ne déborde à 200 % de texte — $nom', (tester) async {
        final repo = _MockRepo();
        when(
          repo.dashboard,
        ).thenAnswer((_) async => AdminDashboard.fromJson(_dashboardJson()));
        when(
          () => repo.users(
            query: any(named: 'query'),
            role: any(named: 'role'),
          ),
        ).thenAnswer(
          (_) async => [
            AdminUser.fromJson({
              'id': 'u1',
              'email': 'une.adresse.electronique.assez.longue@example.org',
              'display_name': 'Ngo Bassong Mbarga',
              'role': 'CULTURAL_SPECIALIST',
              'is_active': false,
              'habilitations': 3,
            }),
          ],
        );
        when(
          () => repo.applications(status: any(named: 'status')),
        ).thenAnswer((_) async => [_application]);
        when(
          () => repo.audit(action: any(named: 'action')),
        ).thenAnswer((_) async => [_audit]);
        when(repo.settings).thenAnswer(
          (_) async => [
            PlatformSetting.fromJson({
              'key': 'review_required_before_publish',
              'value': true,
              'description_fr':
                  'Relecture humaine obligatoire avant publication.',
              'is_editable': false,
            }),
            PlatformSetting.fromJson({
              'key': 'default_daily_goal_xp',
              'value': 20,
              'description_fr': 'Objectif quotidien propose par defaut.',
              'is_editable': true,
            }),
          ],
        );

        tester.view.physicalSize = const Size(390, 10000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [adminRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: Scaffold(body: vue),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'à 200 %, l’écran « $nom » déborde : un administrateur qui a '
              'grossi le texte de son téléphone verrait des bandes '
              'd’avertissement à la place de ses données',
        );
      });
    }
  });

  group('modèles', () {
    test('le total à traiter exclut les habilitations déjà accordées', () {
      final dashboard = AdminDashboard.fromJson(_dashboardJson());
      // 12 mots + 2 exercices + 1 fiche + 3 demandes = 18 ; les 4 habilitations
      // actives sont un état, pas une file d'attente.
      expect(dashboard.pendingDecisions, 18);
      expect(dashboard.isClean, isTrue);
    });

    test('la part publiée se calcule sur le corpus réel', () {
      final dashboard = AdminDashboard.fromJson(_dashboardJson());
      expect(dashboard.languages.single.publishedRatio, closeTo(0.25, 0.001));
    });

    test('un verbe technique inconnu s’affiche tel quel', () {
      final entry = AuditEntry.fromJson({
        'id': 'x',
        'actor_label': 'a',
        'action': 'QUELQUE_CHOSE_DE_NOUVEAU',
        'target_type': 'USER',
        'target_id': null,
        'target_label': null,
        'reason': 'motif',
        'details': null,
        'created_at': '2026-03-12T10:30:00+00:00',
      });
      expect(entry.label, 'QUELQUE_CHOSE_DE_NOUVEAU');
      expect(entry.details, isEmpty);
    });
  });
}
