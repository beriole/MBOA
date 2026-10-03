/// Produit la capture de l'écran de traduction pour le dossier.
///
///   flutter test test/translation_capture_test.dart --dart-define=CAPTURE=true
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
import 'package:mboa_app/features/learning/domain/models.dart';
import 'package:mboa_app/features/progress/progress_providers.dart';
import 'package:mboa_app/features/translation/data/translation_repository.dart';
import 'package:mboa_app/features/translation/domain/models.dart';
import 'package:mboa_app/features/translation/presentation/translation_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TranslationRepository {}

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

const _basaa = Language(
  id: 'lang-1',
  iso: 'bas',
  name: 'Basaa',
  autonym: 'ɓasaá',
  toneCount: 4,
  publishedWords: 13,
);

/// Le cas le plus courant : l'apprenant tape « basaa » sur un clavier ordinaire.
final _folded = TranslationResult(
  requestId: 'req-1',
  mode: 'LEXICON',
  message:
      "Correspondance trouvée : l'orthographe exacte s'écrit « ɓasaá ». "
      "Les lettres ɓ, ɛ, ɔ, ŋ ne sont pas de simples variantes de b, e, o, n.",
  disclaimer:
      'MBOA ne traduit pas de phrases libres : il recherche dans un corpus '
      'vérifié par des locuteurs. Un mot absent du corpus n’est pas un mot inexistant.',
  confidence: 0.7,
  matches: const [
    TranslationMatch(
      vocabularyId: 'v1',
      lemma: 'ɓasaá',
      meaningFr: 'la langue basaa',
      category: 'NOUN',
      kind: MatchKind.folded,
      confidence: 0.7,
      audioUrl: '/api/v1/audio/a1',
      audioAttribution: 'Bile rene (Lingua Libre) — CC BY-SA 4.0',
      sourceTitle: 'Lingua Libre — prononciations basaa (Wikimedia Commons)',
      sourceLicense: 'CC_BY_SA',
    ),
  ],
);

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

  testWidgets('écran de traduction', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repo = _MockRepo();
    when(
      () => repo.translate(
        languageId: any(named: 'languageId'),
        text: any(named: 'text'),
        intoFrench: any(named: 'intoFrench'),
      ),
    ).thenAnswer((_) async => _folded);

    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: ProviderScope(
          overrides: [
            translationRepositoryProvider.overrideWithValue(repo),
            audioServiceProvider.overrideWithValue(_FakeAudio()),
            selectedLanguageProvider.overrideWith((ref) async => _basaa),
          ],
          child: MaterialApp(
            theme: buildMboaTheme(),
            debugShowCheckedModeBanner: false,
            home: const TranslationScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'basaa');
    await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
    await tester.pumpAndSettle();

    expect(find.text('lettres spéciales rétablies'), findsOneWidget);

    if (_captureEnabled) {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${_shots.path}/23-traduction.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
