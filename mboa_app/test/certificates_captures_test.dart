/// Produit les captures des attestations et du profil pour le dossier.
///
///   flutter test test/certificates_captures_test.dart --dart-define=CAPTURE=true
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/design/theme.dart';
import 'package:mboa_app/features/auth/auth_controller.dart';
import 'package:mboa_app/features/certificates/data/certificates_repository.dart';
import 'package:mboa_app/features/certificates/domain/models.dart';
import 'package:mboa_app/features/certificates/presentation/certificates_screen.dart';
import 'package:mboa_app/features/profile/profile_edit_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CertificatesRepository {}

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: AuthStatus.signedIn,
    displayName: 'Ngo Bassong',
    dailyGoalXp: 30,
    locale: 'fr',
  );
}

const _captureEnabled = bool.fromEnvironment('CAPTURE');
final _boundary = GlobalKey();
final _shots = Directory('../docs/captures');

/// Etat correspondant a l'attestation produite par scripts.demo_attestation.
final _list = CertificateList.fromJson({
  'delivrees': [
    {
      'id': 'c1',
      'code': 'MBOA-BAS-2026-9PHFM3',
      'learner_name': 'Ngo Bassong',
      'course_title': 'Basaa — Initiation',
      'section_title': 'Les sons du basaa',
      'language_name': 'Basaa',
      'lessons_completed': 1,
      'lessons_total': 1,
      'average_score': 0.87,
      'exercises_answered': 21,
      'completed_at': '2026-09-24T09:00:00+00:00',
      'issued_at': '2026-09-24T09:05:00+00:00',
      'revoked_at': null,
      'revoked_reason': null,
    },
  ],
  'disponibles': [
    {
      'section_id': 's2',
      'section_title': 'Saluer et se présenter',
      'course_title': 'Basaa — Initiation',
      'language_name': 'Basaa',
      'lessons_total': 3,
    },
  ],
});

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

/// `Override` n'est pas exporte par flutter_riverpod 3 : on construit donc la
/// liste sur place, en laissant le type s'inferer.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  CertificatesRepository? repo,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        overrides: [
          if (repo != null)
            certificatesRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(_FakeSession.new),
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

  testWidgets('mes attestations', (tester) async {
    final repo = _MockRepo();
    when(repo.list).thenAnswer((_) async => _list);

    await _pump(tester, const CertificatesScreen(), repo: repo);
    expect(find.text('MBOA-BAS-2026-9PHFM3'), findsOneWidget);
    await _capture(tester, '38-attestations');
  });

  testWidgets('modification du profil', (tester) async {
    await _pump(tester, const ProfileEditScreen());
    expect(find.text('Objectif quotidien'), findsOneWidget);
    await _capture(tester, '39-profil-modification');
  });
}
