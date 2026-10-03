import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mboa_app/core/api_client.dart';
import 'package:mboa_app/features/certificates/data/certificate_store.dart';
import 'package:mboa_app/features/certificates/data/certificates_repository.dart';
import 'package:mboa_app/features/certificates/domain/models.dart';
import 'package:mboa_app/features/certificates/presentation/certificates_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CertificatesRepository {}

Map<String, dynamic> _certificateJson({
  bool revoked = false,
  double score = 0.87,
}) => {
  'id': 'c1',
  'code': 'MBOA-BAS-2026-9PHFM3',
  'learner_name': 'Ngo Bassong',
  'course_title': 'Basaa — Initiation',
  'section_title': 'Les sons du basaa',
  'language_name': 'Basaa',
  'lessons_completed': 4,
  'lessons_total': 4,
  'average_score': score,
  'exercises_answered': 21,
  'completed_at': '2026-09-24T09:00:00+00:00',
  'issued_at': '2026-09-24T09:05:00+00:00',
  'revoked_at': revoked ? '2026-09-25T10:00:00+00:00' : null,
  'revoked_reason': revoked
      ? 'Parcours effectué avec un compte de test.'
      : null,
};

const _availableJson = {
  'section_id': 's2',
  'section_title': 'Saluer et se présenter',
  'course_title': 'Basaa — Initiation',
  'language_name': 'Basaa',
  'lessons_total': 3,
};

Future<void> _pump(WidgetTester tester, CertificatesRepository repo) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [certificatesRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: CertificatesScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  // mocktail exige une valeur de repli pour `any()` sur un type non nullable.
  setUpAll(
    () => registerFallbackValue(Certificate.fromJson(_certificateJson())),
  );

  group('écran des attestations', () {
    testWidgets('la portée est annoncée avant toute attestation', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.list).thenAnswer(
        (_) async =>
            CertificateList.fromJson({'delivrees': [], 'disponibles': []}),
      );

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      // La même phrase que sur le PDF : l'écran et le document ne racontent
      // pas deux histoires.
      expect(
        find.textContaining(
          'ne constitue pas une certification de niveau de langue',
        ),
        findsOneWidget,
      );
      expect(find.text('Aucune attestation pour l’instant'), findsOneWidget);
    });

    testWidgets('une section terminée peut être demandée', (tester) async {
      final repo = _MockRepo();
      when(repo.list).thenAnswer(
        (_) async => CertificateList.fromJson({
          'delivrees': [],
          'disponibles': [_availableJson],
        }),
      );
      when(
        () => repo.issue(any()),
      ).thenAnswer((_) async => Certificate.fromJson(_certificateJson()));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Saluer et se présenter'), findsOneWidget);
      expect(find.textContaining('3 leçons terminées'), findsOneWidget);

      await tester.tap(find.text('Demander l’attestation'));
      await tester.pumpAndSettle();

      verify(() => repo.issue('s2')).called(1);
    });

    testWidgets('une attestation délivrée montre son code et ses chiffres', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.list).thenAnswer(
        (_) async => CertificateList.fromJson({
          'delivrees': [_certificateJson()],
          'disponibles': [],
        }),
      );

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('MBOA-BAS-2026-9PHFM3'), findsOneWidget);
      expect(find.text('4 / 4 leçons · score moyen 87 %'), findsOneWidget);
      expect(find.textContaining('vérifier l’attestation'), findsOneWidget);
      expect(find.text('Télécharger le PDF'), findsOneWidget);
    });

    testWidgets('une attestation révoquée ne se télécharge plus', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.list).thenAnswer(
        (_) async => CertificateList.fromJson({
          'delivrees': [_certificateJson(revoked: true)],
          'disponibles': [],
        }),
      );

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Révoquée'), findsOneWidget);
      // Le motif reste visible : la personne doit savoir pourquoi.
      expect(find.textContaining('compte de test'), findsOneWidget);
      expect(find.text('Télécharger le PDF'), findsNothing);
      // Mais le code reste affiché : le tiers qui la détient doit pouvoir
      // interroger la vérification.
      expect(find.text('MBOA-BAS-2026-9PHFM3'), findsOneWidget);
    });

    testWidgets('un refus du serveur est montré tel quel', (tester) async {
      final repo = _MockRepo();
      when(repo.list).thenAnswer(
        (_) async => CertificateList.fromJson({
          'delivrees': [],
          'disponibles': [_availableJson],
        }),
      );
      when(() => repo.issue(any())).thenThrow(
        ApiException(
          'Parcours incomplet : 2 lecon(s) terminee(s) sur 3.',
          statusCode: 409,
        ),
      );

      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demander l’attestation'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Parcours incomplet'), findsOneWidget);
    });

    testWidgets('le téléchargement indique où le fichier est déposé', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(repo.list).thenAnswer(
        (_) async => CertificateList.fromJson({
          'delivrees': [_certificateJson()],
          'disponibles': [],
        }),
      );
      when(() => repo.download(any())).thenAnswer(
        (_) async => '/documents/attestation-MBOA-BAS-2026-9PHFM3.pdf',
      );

      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Télécharger le PDF'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('attestation-MBOA-BAS-2026-9PHFM3.pdf'),
        findsOneWidget,
      );
    });
  });

  group('modèle', () {
    test('le score affiché est celui du serveur, arrondi une seule fois', () {
      final certificate = Certificate.fromJson(_certificateJson(score: 0.875));
      expect(certificate.scorePercent, 88);
      expect(certificate.isRevoked, isFalse);
    });

    test('une liste vide se reconnaît', () {
      final list = CertificateList.fromJson({
        'delivrees': [],
        'disponibles': [],
      });
      expect(list.isEmpty, isTrue);
    });
  });

  group('dépôt', () {
    test('le PDF est écrit sous le nom du code', () async {
      final store = _FakeStore();
      final api = _FakeApi();
      final repo = CertificatesRepository(api, store);

      final path = await repo.download(
        Certificate.fromJson(_certificateJson()),
      );

      expect(store.filename, 'attestation-MBOA-BAS-2026-9PHFM3.pdf');
      expect(store.bytes, isNotEmpty);
      expect(path, endsWith('attestation-MBOA-BAS-2026-9PHFM3.pdf'));
      expect(api.requested, '/me/certificates/c1/pdf');
    });
  });
}

class _FakeStore implements CertificateStore {
  String? filename;
  Uint8List bytes = Uint8List(0);

  @override
  Future<String> save(String name, Uint8List data) async {
    filename = name;
    bytes = data;
    return '/documents/$name';
  }
}

/// Client minimal : seul `bytes` est exercé ici.
class _FakeApi extends Fake implements ApiClient {
  String? requested;

  @override
  Future<Uint8List> bytes(String path) async {
    requested = path;
    return Uint8List.fromList('%PDF-1.3'.codeUnits);
  }
}
