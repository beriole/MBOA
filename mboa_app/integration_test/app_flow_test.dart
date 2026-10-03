/// Test d'intégration : la vraie application, contre la vraie API locale.
///
/// Déroule le scénario du SS49 de bout en bout par l'interface :
///   onboarding → choix de la langue → compte → parcours → leçon → écoute →
///   réponses → feedback → fin de leçon → XP → révision du lendemain.
///
/// Produit aussi les captures d'écran du dossier (docs/captures).
///
/// Prérequis : l'API doit tourner sur http://127.0.0.1:8010
/// Lancement  : flutter test integration_test -d windows
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mboa_app/design/widgets/audio_button.dart';
import 'package:mboa_app/features/exercises/exercise_view.dart';
import 'package:mboa_app/main.dart';

/// Aucun moteur audio sur le bureau : on enregistre les URL demandées.
class _SilentAudio implements AudioService {
  final requested = <String>[];

  @override
  Future<void> play(String url, {bool slow = false}) async => requested.add(url);
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
  @override
  String? get currentUrl => requested.isEmpty ? null : requested.last;
  @override
  Stream<PlayerState> get state => const Stream.empty();
}

final _boundaryKey = GlobalKey();
final _shots = Directory('../docs/captures');
var _shotIndex = 1;

/// Les captures ne sont produites que sur un vrai appareil (`--dart-define=CAPTURE=true`).
/// Sans cela, le test tourne en mode headless : le flux est verifie, pas le rendu.
const bool _captureEnabled = bool.fromEnvironment('CAPTURE');

/// Laisse passer quelques images. On evite `pumpAndSettle` : un indicateur de
/// chargement tourne en boucle et empecherait le test de se stabiliser.
Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    // `runAsync` laisse s'ecouler du temps REEL : sans lui, les appels HTTP et
    // les canaux de plateforme ne se resolvent jamais dans un test de widgets.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    // pump AVEC duree : fait aussi avancer l'horloge simulee, sinon les
    // `Future` planifies dans la zone de test ne se declenchent jamais.
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _settle(tester);
  if (!_captureEnabled) return;
  final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // `toImage` et l'encodage PNG ne se terminent qu'en temps reel.
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_shots.path}/${_shotIndex.toString().padLeft(2, '0')}-$name.png');
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  _shotIndex++;
}

/// Attend qu'une condition soit vraie, sans bloquer sur les requêtes réseau.
Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 25),
  String? description,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    // pump AVEC duree : fait aussi avancer l'horloge simulee, sinon les
    // `Future` planifies dans la zone de test ne se declenchent jamais.
    await tester.pump(const Duration(milliseconds: 60));
    if (condition()) return;
  }
  fail('Délai dépassé en attendant : ${description ?? 'condition'}');
}

/// L'icone d'un onglet change quand il est selectionne : on accepte les deux.
Future<void> _tapIcon(WidgetTester tester, IconData icon, IconData selected) async {
  await _until(
    tester,
    () => find.byIcon(icon).evaluate().isNotEmpty || find.byIcon(selected).evaluate().isNotEmpty,
    description: 'un onglet de navigation',
  );
  final finder = find.byIcon(icon).evaluate().isNotEmpty ? find.byIcon(icon) : find.byIcon(selected);
  await tester.tap(finder.first);
  await _settle(tester);
}

Future<void> _tapText(WidgetTester tester, String label) async {
  await _until(tester, () => find.text(label).evaluate().isNotEmpty, description: label);
  await tester.tap(find.text(label).first);
  await _settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // L'hote de test n'a aucun plugin natif et ne doit pas telecharger de polices :
  // on repond a la place des canaux de plateforme, pour que le test mesure
  // l'application et non l'absence de plateforme.
  setUpAll(() async {
    // Sans cela, les tests dessinent une police de substitution : les captures
    // seraient illisibles. On charge la vraie Inter, embarquee dans l'app.
    final fontData = await rootBundle.load('assets/fonts/Inter-Variable.ttf');
    await (FontLoader('Inter')..addFont(Future.value(fontData))).load();

    // Meme chose pour les icones Material, fournies par le SDK Flutter.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final icons = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')
              ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer))))
            .load();
      }
    }

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
    final secrets = <String, String>{};
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => switch (call.method) {
        'read' => secrets[call.arguments['key'] as String],
        'write' => secrets[call.arguments['key'] as String] = call.arguments['value'] as String,
        'delete' => secrets.remove(call.arguments['key'] as String),
        'readAll' => secrets,
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
  });


  testWidgets('parcours complet de l\'apprenant', (tester) async {
    if (!_shots.existsSync()) _shots.createSync(recursive: true);

    // Format téléphone : la mise en page doit tenir à cette largeur.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final audio = _SilentAudio();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: ProviderScope(
          overrides: [audioServiceProvider.overrideWithValue(audio)],
          child: const MboaApp(),
        ),
      ),
    );
    await _settle(tester);

    // ---------------------------------------------------------------- onboarding
    await _until(tester, () => find.text('Continuer').evaluate().isNotEmpty,
        description: "l'écran d'accueil de l'onboarding");
    expect(find.text('Écoute de vraies voix'), findsOneWidget);
    await _capture(tester, 'onboarding-accueil');
    await _tapText(tester, 'Continuer');

    // Le choix de la langue vient de l'API, pas d'une liste codée en dur.
    await _until(tester, () => find.text('Basaa').evaluate().isNotEmpty,
        description: 'la liste des langues servie par l\'API');
    expect(find.textContaining('mots vérifiés'), findsWidgets);
    await _capture(tester, 'onboarding-langue');
    await _tapText(tester, 'Basaa');
    await _tapText(tester, 'Continuer');

    await _tapText(tester, 'Je débute');
    await _capture(tester, 'onboarding-niveau');
    await _tapText(tester, 'Continuer');

    await _tapText(tester, 'Régulier');
    await _capture(tester, 'onboarding-objectif');
    await _tapText(tester, 'Créer mon compte');

    // ---------------------------------------------------------------- inscription
    await _until(tester, () => find.byType(TextFormField).evaluate().length >= 3,
        description: 'le formulaire d\'inscription');
    final email = 'demo${DateTime.now().millisecondsSinceEpoch}@example.com';
    await tester.enterText(find.byType(TextFormField).at(0), 'Ama');
    await tester.enterText(find.byType(TextFormField).at(1), email);
    await tester.enterText(find.byType(TextFormField).at(2), 'motdepasse-demo-2026');
    await _settle(tester);
    await _capture(tester, 'inscription');
    await tester.tap(find.widgetWithText(FilledButton, 'Créer mon compte'));
    await _settle(tester);

    // ---------------------------------------------------------------- accueil
    await _until(tester, () => find.textContaining('Bonjour').evaluate().isNotEmpty,
        description: "l'accueil après inscription");
    await _until(tester, () => find.textContaining('Continuer ·').evaluate().isNotEmpty,
        description: 'le parcours chargé depuis l\'API');
    expect(find.text('Objectif du jour'), findsOneWidget);
    await _capture(tester, 'accueil');

    // ---------------------------------------------------------------- parcours
    await _tapIcon(tester, Icons.route_outlined, Icons.route_rounded);
    await _settle(tester);
    await _until(tester, () => find.text('SECTION 1').evaluate().isNotEmpty,
        description: 'le chemin vertical');
    await _capture(tester, 'parcours');

    await _tapIcon(tester, Icons.home_outlined, Icons.home_rounded);
    await _settle(tester);

    // ---------------------------------------------------------------- leçon
    await tester.tap(find.textContaining('Continuer ·'));
    await _settle(tester);
    await _until(tester, () => find.text('Commencer').evaluate().isNotEmpty,
        description: "l'introduction de la leçon");
    await _capture(tester, 'lecon-intro');
    await _tapText(tester, 'Commencer');

    // ---------------------------------------------------------------- exercices
    var answered = 0;
    var gotCorrect = false;
    var gotWrong = false;

    while (answered < 40) {
      await _until(
        tester,
        () =>
            find.byType(ChoiceTile).evaluate().isNotEmpty ||
            find.text('LE SAVAIS-TU ?').evaluate().isNotEmpty ||
            find.text('Leçon terminée').evaluate().isNotEmpty,
        description: 'un exercice, la carte culturelle ou la fin de la leçon',
      );

      // Carte « Le savais-tu ? » : la culture s'intercale avant le résultat (SS21).
      if (find.text('LE SAVAIS-TU ?').evaluate().isNotEmpty) {
        expect(find.textContaining('Source :'), findsOneWidget,
            reason: 'une carte culturelle cite toujours sa source');
        expect(find.text('Découvrir davantage'), findsOneWidget);
        await _capture(tester, 'carte-culturelle');
        await tester.tap(find.text('Continuer'));
        await _settle(tester);
        continue;
      }

      if (find.text('Leçon terminée').evaluate().isNotEmpty) break;

      if (answered == 0) {
        expect(find.textContaining('CC BY-SA'), findsOneWidget,
            reason: 'l\'attribution du locuteur est affichée');
        expect(audio.requested, isNotEmpty, reason: 'l\'audio démarre tout seul');
        expect(audio.requested.first, startsWith('/api/v1/audio/'),
            reason: 'l\'audio est servi par identifiant, pas par nom de fichier');
        await _capture(tester, 'exercice-ecoute');
      }

      // Jeu de paires : on associe chaque mot à son enregistrement.
      final memory = find.byType(MemoryGameView);
      if (memory.evaluate().isNotEmpty) {
        final pairs = (tester.widget<MemoryGameView>(memory).exercise.payload['pairs'] as List)
            .cast<Map>();
        for (final pair in pairs) {
          await tester.tap(find.text(pair['text'] as String));
          await tester.pump();
          final row = find.ancestor(
            of: find.byWidgetPredicate((w) => w is AudioButton && w.url == pair['audio_url']),
            matching: find.byType(Row),
          );
          await tester.tap(find.descendant(of: row, matching: find.byType(ChoiceTile)).first);
          await tester.pump(const Duration(milliseconds: 200));
        }
      } else {
        await tester.tap(find.byType(ChoiceTile).first);
      }

      await _until(tester, () => find.text('Continuer').evaluate().isNotEmpty,
          description: 'la barre de feedback');
      // La barre s'ouvre par une animation de hauteur : taper trop tot tombe
      // a cote du bouton.
      await _settle(tester);

      final correct = find.text('Correct').evaluate().isNotEmpty;
      if (correct && !gotCorrect) {
        gotCorrect = true;
        await _capture(tester, 'feedback-correct');
      }
      if (!correct && !gotWrong) {
        gotWrong = true;
        // Après une erreur : la bonne réponse est montrée, sans humilier.
        expect(find.text('Pas encore'), findsOneWidget);
        expect(find.text('Bonne réponse'), findsOneWidget);
        await _capture(tester, 'feedback-incorrect');
      }

      await tester.tap(find.text('Continuer'));
      await _settle(tester);
      answered++;
    }

    expect(answered, greaterThan(0), reason: 'au moins un exercice a été traité');

    // ---------------------------------------------------------------- résultat
    await _until(tester, () => find.text('Leçon terminée').evaluate().isNotEmpty,
        description: 'l\'écran de résultat');
    expect(find.text('XP gagnés'), findsOneWidget);
    expect(find.text('Série'), findsOneWidget);
    await _capture(tester, 'resultat');
    await _tapText(tester, 'Continuer');

    // ---------------------------------------------------------------- révision
    await _until(tester, () => find.text('Révision recommandée').evaluate().isNotEmpty,
        description: 'la carte de révision sur l\'accueil');

    // Les éléments ratés ne reviennent que le lendemain : on avance l'horloge.
    if (find.text('Démo : passer au lendemain').evaluate().isNotEmpty) {
      await _tapText(tester, 'Démo : passer au lendemain');
      await _until(tester, () => find.text('Réviser maintenant').evaluate().isNotEmpty,
          description: 'la révision devenue disponible');
    }

    if (find.text('Réviser maintenant').evaluate().isNotEmpty) {
      await _capture(tester, 'accueil-revision-due');
      await _tapText(tester, 'Réviser maintenant');
      await _until(
        tester,
        () =>
            find.byType(ChoiceTile).evaluate().isNotEmpty ||
            find.textContaining('Rien à réviser').evaluate().isNotEmpty,
        description: 'la session de révision',
      );
      await _capture(tester, 'revision');

      // La revision est une route plein ecran : on en sort avant de rejoindre
      // les onglets.
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await _settle(tester);
      if (find.text('Quitter').evaluate().isNotEmpty) {
        await _tapText(tester, 'Quitter');
      }
    }

    // ---------------------------------------------------------------- profil
    await _tapIcon(tester, Icons.person_outline_rounded, Icons.person_rounded);
    await _settle(tester);
    await _until(tester, () => find.text('XP au total').evaluate().isNotEmpty,
        description: 'les statistiques personnelles');
    expect(find.text('Mes mots'), findsOneWidget);
    await _capture(tester, 'profil');
  });
}
