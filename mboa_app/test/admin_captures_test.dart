/// Produit les captures de la console d'administration pour le dossier.
///
///   flutter test test/admin_captures_test.dart --dart-define=CAPTURE=true
///
/// Les chiffres utilisés sont ceux relevés sur la base de démonstration : le
/// dossier ne montre pas des données inventées pour faire joli.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/design/theme.dart';
import 'package:mboa_app/design/widgets/mboa_header_tabs.dart';
import 'package:mboa_app/features/admin/data/admin_repository.dart';
import 'package:mboa_app/features/admin/domain/models.dart';
import 'package:mboa_app/features/admin/presentation/admin_console_screen.dart';
import 'package:mboa_app/features/auth/auth_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AdminRepository {}

/// Session figée sur un compte administrateur : sans elle, la console ne
/// montrerait que son écran de refus.
class _FakeSession extends SessionController {
  @override
  SessionState build() =>
      SessionState(status: AuthStatus.signedIn, role: 'ADMIN');
}

const _captureEnabled = bool.fromEnvironment('CAPTURE');
final _boundary = GlobalKey();
final _shots = Directory('../docs/captures');

/// Relevé du 24 septembre 2026 sur la base de démonstration.
final _dashboard = AdminDashboard.fromJson({
  'comptes': {
    'total': 6,
    'par_role': [
      {'role': 'LEARNER', 'total': 4, 'actifs': 4},
      {'role': 'CULTURAL_SPECIALIST', 'total': 1, 'actifs': 1},
      {'role': 'ADMIN', 'total': 1, 'actifs': 1},
    ],
    'connectes_7j': 6,
    'inscrits_30j': 6,
    'jamais_connectes': 0,
  },
  'corpus': {
    'par_langue': [
      {
        'id': 'l1',
        'iso639_3': 'bas',
        'name': 'Basaa',
        'total': 22,
        'publies': 13,
        'valides': 0,
        'en_attente': 9,
        'sans_glose': 9,
      },
    ],
    'par_statut': [],
  },
  'licences': [
    {'licence': 'CC0', 'sources': 1, 'mots': 22, 'mots_publies': 13},
    {'licence': 'CC_BY_SA', 'sources': 1, 'mots': 0, 'mots_publies': 0},
    {
      'licence': 'COPYRIGHT_NO_AGREEMENT',
      'sources': 2,
      'mots': 0,
      'mots_publies': 0,
    },
  ],
  'contenu': {
    'exercices_publies': 24,
    'exercices_en_attente': 0,
    'lecons': 4,
    'fiches_publiees': 3,
    'rubriques': 16,
    'rubriques_vides': 13,
    'enregistrements': 22,
  },
  'activite': {
    'sessions': 3,
    'tentatives': 21,
    'tentatives_7j': 21,
    'traductions': 5,
    'traductions_sans_reponse': 1,
  },
  'a_traiter': {
    'mots_a_relire': 9,
    'exercices_a_relire': 0,
    'fiches_a_relire': 0,
    'demandes_habilitation': 1,
    'habilitations_actives': 2,
  },
  'integrite': {
    'conforme': true,
    'anomalies_totales': 0,
    'controles': [
      {
        'code': 'lexique_publie_sans_source',
        'libelle': 'Mots publiés sans source identifiée',
        'anomalies': 0,
        'conforme': true,
      },
      {
        'code': 'lexique_publie_sans_validateur',
        'libelle': 'Mots publiés sans validateur humain',
        'anomalies': 0,
        'conforme': true,
      },
      {
        'code': 'lexique_auto_valide',
        'libelle': 'Mots validés par leur propre rédacteur',
        'anomalies': 0,
        'conforme': true,
      },
      {
        'code': 'exercices_publies_sans_origine',
        'libelle': 'Exercices publiés sans mot d’origine',
        'anomalies': 0,
        'conforme': true,
      },
      {
        'code': 'fiches_publiees_sans_source',
        'libelle': 'Fiches culturelles publiées sans source',
        'anomalies': 0,
        'conforme': true,
      },
      {
        'code': 'sources_sans_licence',
        'libelle': 'Sources utilisées dont la licence reste inconnue',
        'anomalies': 0,
        'conforme': true,
      },
    ],
  },
  'chantiers_ouverts': [
    {
      'domaine': 'Paiements et abonnements',
      'etat': 'non implémenté',
      'raison':
          'aucune entité juridique ni compte marchand à ce stade du projet',
    },
    {
      'domaine': 'Vérification d’identité des artisans et livreurs',
      'etat': 'non implémenté',
      'raison':
          'la place de marché n’est pas ouverte ; cette vérification portera '
          'sur des pièces d’identité et relève d’un traitement de données à déclarer',
    },
  ],
});

final _applications = [
  SpecialistApplication.fromJson({
    'id': 'a1',
    'status': 'PENDING',
    'user_id': 'u1',
    'display_name': 'Ngo Bassong',
    'email': 'demo@example.org',
    'language_name': 'Basaa',
    'claimed_role': 'NATIVE_SPEAKER',
    'relationship_fr':
        'Langue maternelle, parlée quotidiennement en famille depuis '
        'l’enfance ; je co-anime une émission de radio communautaire.',
    'requested_scope': ['LEXICON', 'AUDIO'],
    'affiliation': 'Radio communautaire (démonstration)',
    'referees_fr': 'Le responsable d’antenne peut confirmer.',
    'evidence_url': null,
    'review_note': null,
  }),
];

/// Comptes de la base de demonstration. Les adresses sont en `example.org`,
/// domaine reserve a la documentation : aucune n'appartient a quiconque.
final _users = [
  AdminUser.fromJson({
    'id': 'u1',
    'email': 'admin@example.org',
    'display_name': 'Administratrice du projet',
    'role': 'ADMIN',
    'is_active': true,
    'habilitations': 0,
  }),
  AdminUser.fromJson({
    'id': 'u2',
    'email': 'demo@example.org',
    'display_name': 'Ngo Bassong',
    'role': 'CULTURAL_SPECIALIST',
    'is_active': true,
    'habilitations': 2,
  }),
  AdminUser.fromJson({
    'id': 'u3',
    'email': 'apprenant@example.org',
    'display_name': 'Compte de demonstration',
    'role': 'LEARNER',
    'is_active': true,
    'habilitations': 0,
  }),
  AdminUser.fromJson({
    'id': 'u4',
    'email': 'relecteur@example.org',
    'display_name': 'Ancien relecteur',
    'role': 'LEARNER',
    'is_active': false,
    'habilitations': 0,
  }),
];

/// Les quatre reglages que le serveur cree reellement.
final _settings = [
  PlatformSetting.fromJson({
    'key': 'registration_open',
    'value': true,
    'description_fr': 'Les nouvelles inscriptions sont acceptees.',
    'is_editable': true,
  }),
  PlatformSetting.fromJson({
    'key': 'default_daily_goal_xp',
    'value': 20,
    'description_fr': "Objectif quotidien propose par defaut a l'inscription.",
    'is_editable': true,
  }),
  PlatformSetting.fromJson({
    'key': 'review_required_before_publish',
    'value': true,
    'description_fr':
        'Relecture humaine obligatoire avant publication. Ce parametre est '
        'affiche pour memoire : la regle est appliquee par la base de donnees '
        'et ne peut pas etre desactivee ici.',
    'is_editable': false,
  }),
  PlatformSetting.fromJson({
    'key': 'support_email',
    'value': 'contact@example.org',
    'description_fr': 'Adresse affichee aux utilisateurs en cas de probleme.',
    'is_editable': true,
  }),
];

final _audit = [
  AuditEntry.fromJson({
    'id': 'j1',
    'actor_label': 'Administratrice <admin@example.org>',
    'action': 'APPLICATION_ACCEPTED',
    'target_type': 'SPECIALIST_APPLICATION',
    'target_id': 'a1',
    'target_label': 'demo@example.org / Basaa',
    'reason':
        'Entretien mené le 3 avril ; le responsable d’antenne confirme la '
        'pratique quotidienne de la langue.',
    'details': {'perimetre_accorde': 'LEXICON'},
    'created_at': '2026-09-24T09:12:00+00:00',
  }),
  AuditEntry.fromJson({
    'id': 'j2',
    'actor_label': 'Administratrice <admin@example.org>',
    'action': 'USER_ROLE_CHANGED',
    'target_type': 'USER',
    'target_id': 'u2',
    'target_label': 'relecteur@example.org',
    'reason': 'Fin de la mission de relecture, à la demande de l’intéressé.',
    'details': {'avant': 'CULTURAL_SPECIALIST', 'apres': 'LEARNER'},
    'created_at': '2026-09-23T16:40:00+00:00',
  }),
  AuditEntry.fromJson({
    'id': 'j3',
    'actor_label': 'ligne de commande (scripts.grant_admin)',
    'action': 'USER_ROLE_CHANGED',
    'target_type': 'USER',
    'target_id': 'u3',
    'target_label': 'admin@example.org',
    'reason': 'Porteuse du projet, premier compte d’administration.',
    'details': {'avant': 'LEARNER', 'apres': 'ADMIN'},
    'created_at': '2026-09-20T08:05:00+00:00',
  }),
];

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  if (!_captureEnabled) return;
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_shots.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

/// Monte la console entière, puis ouvre l'onglet demandé.
///
/// Les captures montraient jusqu'ici chaque vue seule sous une `AppBar` grise
/// fabriquee pour l'occasion : trois images blanches qui ne ressemblaient pas a
/// l'ecran reel. On photographie desormais la console telle qu'elle s'affiche,
/// en-tete degrade et onglets compris.
Future<void> _pump(
  WidgetTester tester,
  AdminRepository repo,
  String onglet,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(_FakeSession.new),
        ],
        child: MaterialApp(
          theme: buildMboaTheme(),
          debugShowCheckedModeBanner: false,
          home: const AdminConsoleScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // On touche la pastille par son libelle, et non le n-ieme `InkWell` : le
  // bouton de retour et celui de rechargement en sont aussi, et compter les
  // `InkWell` ouvrait un onglet au hasard.
  //
  // `ensureVisible` d'abord : la rangee de pastilles defile, et les deux
  // dernieres sont hors de l'ecran sur un telephone de 390 points. Sans cela
  // le `tap` tombait dans le vide — ce qu'il signalait, mais sans echouer.
  final cible = find.descendant(
    of: find.byType(MboaHeaderTabs),
    matching: find.text(onglet),
  );
  // On cadre la pastille entiere et non son libelle : `ensureVisible` aligne le
  // bord gauche de sa cible sur celui du cadre, et viser le texte faisait
  // defiler la rangee de la largeur de l'icone — la premiere pastille
  // apparaissait rognee sur la capture.
  final pastille = find.ancestor(of: cible, matching: find.byType(InkWell));
  await tester.ensureVisible(pastille);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

/// Un dépôt qui répond à tout : la console charge les cinq onglets, et
/// `TabBarView` en construit plus d'un à la fois.
_MockRepo _repoComplet() {
  final repo = _MockRepo();
  when(repo.dashboard).thenAnswer((_) async => _dashboard);
  when(
    () => repo.applications(status: any(named: 'status')),
  ).thenAnswer((_) async => _applications);
  when(
    () => repo.audit(action: any(named: 'action')),
  ).thenAnswer((_) async => _audit);
  when(
    () => repo.users(
      query: any(named: 'query'),
      role: any(named: 'role'),
    ),
  ).thenAnswer((_) async => _users);
  when(repo.settings).thenAnswer((_) async => _settings);
  return repo;
}

void main() {
  setUpAll(() async {
    final fontData = await rootBundle.load('assets/fonts/Inter-Variable.ttf');
    await (FontLoader('Inter')..addFont(Future.value(fontData))).load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final icons = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.view(icons.readAsBytesSync().buffer)),
            ))
            .load();
      }
    }
    if (!_shots.existsSync()) _shots.createSync(recursive: true);
  });

  testWidgets('tableau de bord', (tester) async {
    await _pump(tester, _repoComplet(), 'Tableau de bord');
    expect(
      find.text('Aucun contenu publié n’échappe aux règles'),
      findsOneWidget,
    );
    await _capture(tester, '33-admin-tableau-de-bord');
  });

  testWidgets('comptes', (tester) async {
    await _pump(tester, _repoComplet(), 'Comptes');
    expect(find.text('Spécialiste culturel'), findsOneWidget);
    await _capture(tester, '34-admin-comptes');
  });

  testWidgets('demande d’habilitation', (tester) async {
    await _pump(tester, _repoComplet(), 'Demandes');
    expect(find.text('RAPPORT À LA LANGUE'), findsOneWidget);
    await _capture(tester, '35-admin-habilitation');
  });

  testWidgets('paramètres de la plateforme', (tester) async {
    await _pump(tester, _repoComplet(), 'Paramètres');
    expect(
      find.text('Relecture obligatoire avant publication'),
      findsOneWidget,
    );
    await _capture(tester, '36-admin-parametres');
  });

  testWidgets('journal des actes', (tester) async {
    await _pump(tester, _repoComplet(), 'Journal');
    expect(find.text('Candidature acceptée'), findsOneWidget);
    await _capture(tester, '37-admin-journal');
  });
}
