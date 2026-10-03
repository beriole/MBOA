import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/features/culture/data/culture_repository.dart';
import 'package:mboa_app/features/culture/domain/models.dart';
import 'package:mboa_app/features/onboarding/setup_repository.dart';
import 'package:mboa_app/features/onboarding/setup_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockSetup extends Mock implements SetupRepository {}

class _MockCulture extends Mock implements CultureRepository {}

const _categories = [
  CultureCategory(id: 'c1', code: 'TALES', name: 'Contes', publishedCount: 0),
  CultureCategory(
    id: 'c2',
    code: 'LANGUAGE',
    name: 'Langue',
    publishedCount: 1,
  ),
];

PlacementInfo _placement({bool available = false}) => PlacementInfo.fromJson({
  'disponible': available,
  'exercices_publies': 24,
  'types_publies': available ? 3 : 1,
  'minimum_requis': 8,
  'types_requis': 2,
  'explication': available
      ? 'Un court test tiré du corpus publié peut situer votre point de départ.'
      : 'Le corpus publié ne comporte qu’un seul type d’exercice. Un test bâti '
            'dessus mesurerait une seule compétence, pas un niveau.',
});

final _summary = SetupSummary.fromJson(const {
  'nom': 'Ama',
  'motivations': ['FAMILY'],
  'interets': ['Contes'],
  'minutes': 10,
  'daily_goal_xp': 20,
  'notifications_actives': ['reminders'],
  'test_de_positionnement': false,
  'termine': false,
});

Future<_MockSetup> _pump(
  WidgetTester tester, {
  bool placementAvailable = false,
}) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final setup = _MockSetup();
  final culture = _MockCulture();
  when(() => setup.save(any())).thenAnswer((_) async => <String, dynamic>{});
  when(
    setup.placement,
  ).thenAnswer((_) async => _placement(available: placementAvailable));
  when(setup.summary).thenAnswer((_) async => _summary);
  when(culture.categories).thenAnswer((_) async => _categories);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        setupRepositoryProvider.overrideWithValue(setup),
        cultureRepositoryProvider.overrideWithValue(culture),
      ],
      child: const MaterialApp(home: SetupScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return setup;
}

/// `find.byType` compare le type exact : un `FilledButton` classique convient,
/// mais on cible par texte pour rester lisible.
Finder _continuer() => find.widgetWithText(FilledButton, 'Continuer');

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  testWidgets('la première étape attend au moins une motivation', (
    tester,
  ) async {
    final setup = await _pump(tester);

    expect(
      find.text('Pourquoi souhaitez-vous apprendre cette langue ?'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_continuer()).onPressed, isNull);

    await tester.tap(find.text('Communiquer avec ma famille'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_continuer()).onPressed, isNotNull);

    await tester.tap(_continuer());
    await tester.pumpAndSettle();
    verify(
      () => setup.save({
        'motivations': ['FAMILY'],
      }),
    ).called(1);
  });

  testWidgets('les centres d’intérêt sont les rubriques réelles', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Par intérêt personnel'));
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();

    expect(
      find.text('Quels sujets culturels vous intéressent ?'),
      findsOneWidget,
    );
    // Le compte de fiches est affiché, rubriques vides comprises.
    expect(find.text('Contes · 0'), findsOneWidget);
    expect(find.text('Langue · 1'), findsOneWidget);
  });

  testWidgets('le test de positionnement se déclare indisponible', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Par intérêt personnel'));
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contes · 0'));
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();

    expect(
      find.text('Le corpus publié ne le permet pas encore'),
      findsOneWidget,
    );
    expect(
      find.textContaining('une seule compétence, pas un niveau'),
      findsOneWidget,
    );
    expect(find.textContaining('1 type sur 2'), findsOneWidget);
    // L'étape reste franchissable : aucun choix n'est imposé.
    expect(tester.widget<FilledButton>(_continuer()).onPressed, isNotNull);
  });

  testWidgets('le corpus suffisant est signalé, sans promettre le test', (
    tester,
  ) async {
    await _pump(tester, placementAvailable: true);
    await tester.tap(find.text('Par intérêt personnel'));
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contes · 0'));
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();

    expect(find.text('Le corpus publié le permettrait'), findsOneWidget);
    // Le test n'existe pas encore : l'écran ne prétend pas le lancer.
    expect(find.textContaining('n’est pas encore construit'), findsOneWidget);
    expect(find.text('Oui, prévenez-moi quand il existera'), findsOneWidget);
  });

  testWidgets('les notifications annoncent qu’elles ne déclenchent rien', (
    tester,
  ) async {
    final setup = await _pump(tester);
    await tester.tap(find.text('Par intérêt personnel'));
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contes · 0'));
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();

    expect(
      find.text('Souhaitez-vous recevoir des notifications ?'),
      findsOneWidget,
    );
    expect(find.textContaining('Aucun envoi n’est branché'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(4));

    await tester.tap(_continuer());
    await tester.pumpAndSettle();
    verify(
      () => setup.save({
        'notifications': {
          'reminders': true,
          'new_content': true,
          'tips': false,
          'offers': false,
        },
      }),
    ).called(1);
  });

  testWidgets('le récapitulatif n’affiche que ce qui a été choisi', (
    tester,
  ) async {
    await _pump(tester);
    for (final action in ['Par intérêt personnel', 'Contes · 0']) {
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.tap(_continuer());
      await tester.pumpAndSettle();
    }
    await tester.tap(_continuer());
    await tester.pumpAndSettle();
    await tester.tap(_continuer());
    await tester.pumpAndSettle();

    expect(find.text('Votre parcours est prêt'), findsOneWidget);
    expect(find.text('Ama'), findsOneWidget);
    expect(find.text('Communiquer avec ma famille'), findsOneWidget);
    expect(find.text('10 min · 20 XP'), findsOneWidget);
    expect(find.text('rappels'), findsOneWidget);
  });

  group('récapitulatif', () {
    test('une ligne vide n’apparaît pas', () {
      final summary = SetupSummary.fromJson(const {
        'nom': 'Ama',
        'motivations': [],
        'interets': [],
        'minutes': null,
        'daily_goal_xp': 20,
        'notifications_actives': [],
        'test_de_positionnement': null,
        'termine': false,
      });
      final labels = summary.lines.map((l) => l.$1).toList();

      expect(labels, contains('Nom'));
      expect(labels, isNot(contains('Objectif quotidien')));
      expect(labels, isNot(contains('Centres d’intérêt')));
      // Une absence de notification est une information, pas un vide.
      expect(
        summary.lines.firstWhere((l) => l.$1 == 'Notifications').$2,
        'aucune',
      );
    });

    test('les codes de motivation sont traduits', () {
      expect(
        _summary.lines.firstWhere((l) => l.$1 == 'Motivations').$2,
        'Communiquer avec ma famille',
      );
    });
  });
}
