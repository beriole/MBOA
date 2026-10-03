/// Produit les captures de l'espace contributeur pour le dossier.
///
///   flutter test test/contribution_captures_test.dart --dart-define=CAPTURE=true
///
/// Sans `CAPTURE`, le test se contente de vérifier que les écrans s'affichent.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mboa_app/design/theme.dart';
import 'package:mboa_app/design/widgets/audio_button.dart';
import 'package:mboa_app/features/contribution/data/contribution_repository.dart';
import 'package:mboa_app/features/contribution/domain/models.dart';
import 'package:mboa_app/features/contribution/presentation/contribution_entry_screen.dart';
import 'package:mboa_app/features/contribution/presentation/contribution_queue_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ContributionRepository {}

class _FakeAudio implements AudioService {
  @override
  Future<void> play(String url, {bool slow = false}) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
  @override
  String? get currentUrl => null;
  @override
  Stream<PlayerState> get state => const Stream.empty();
}

const _captureEnabled = bool.fromEnvironment('CAPTURE');
final _boundary = GlobalKey();
final _shots = Directory('../docs/captures');

/// Données réelles du corpus de démonstration (Lingua Libre, CC BY-SA 4.0).
const _entries = [
  CorpusEntry(
    id: '1',
    lemma: 'ɓasaá',
    meaningFr: null,
    category: 'OTHER',
    status: 'TO_VERIFY',
    hasGloss: false,
    audioUrl: '/api/v1/audio/a1',
    audioAttribution: 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
    sourceTitle: 'Lingua Libre — prononciations basaa (Wikimedia Commons)',
    sourceLicense: 'CC_BY_SA',
    sourceLocator: 'Commons: LL-Q33093 (bas)-Bile rene-ɓasaá.wav',
  ),
  CorpusEntry(
    id: '2',
    lemma: 'màlep',
    meaningFr: null,
    category: 'OTHER',
    status: 'TO_VERIFY',
    hasGloss: false,
    audioUrl: '/api/v1/audio/a2',
    sourceTitle: 'Lingua Libre — prononciations basaa (Wikimedia Commons)',
    sourceLicense: 'CC_BY_SA',
  ),
  CorpusEntry(
    id: '3',
    lemma: 'mààŋgɛ',
    meaningFr: 'sens relu et confirmé',
    category: 'NOUN',
    status: 'HUMAN_REVIEW',
    hasGloss: true,
    audioUrl: '/api/v1/audio/a3',
    sourceTitle: 'Lingua Libre — prononciations basaa (Wikimedia Commons)',
    sourceLicense: 'CC_BY_SA',
  ),
];

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 300));
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

Future<void> _pump(WidgetTester tester, Widget screen, _MockRepo repo) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        overrides: [
          contributionRepositoryProvider.overrideWithValue(repo),
          audioServiceProvider.overrideWithValue(_FakeAudio()),
        ],
        child: MaterialApp(
          theme: buildMboaTheme(),
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump();
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

  testWidgets('file de contribution', (tester) async {
    final repo = _MockRepo();
    when(() => repo.languages()).thenAnswer(
      (_) async => [
        const ContributorLanguage(
          id: 'l1',
          name: 'Basaa',
          iso: 'bas',
          missingGloss: 11,
          total: 13,
        ),
      ],
    );
    when(
      () => repo.queue(any(), onlyMissingGloss: any(named: 'onlyMissingGloss')),
    ).thenAnswer(
      (_) async => const ContributionQueue(
        languageId: 'l1',
        counts: {'PUBLISHED': 11, 'HUMAN_REVIEW': 1, 'TO_VERIFY': 1},
        missingGloss: 11,
        entries: _entries,
      ),
    );

    await _pump(tester, const ContributionQueueScreen(), repo);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Avancement du corpus'), findsOneWidget);
    expect(find.text('2 mot(s) traduit(s) sur 13'), findsOneWidget);
    expect(find.text('ɓasaá'), findsOneWidget);
    expect(find.text('traduction à saisir'), findsWidgets);
    await _capture(tester, '21-contribution-file');
  });

  testWidgets('fiche de contribution', (tester) async {
    await _pump(
      tester,
      ContributionEntryScreen(entry: _entries[0]),
      _MockRepo(),
    );
    expect(find.text('Provenance'), findsOneWidget);
    expect(find.text('Enregistrer la traduction'), findsOneWidget);
    await _capture(tester, '22-contribution-fiche');
  });
}
