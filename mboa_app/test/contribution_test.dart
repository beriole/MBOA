import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mboa_app/design/widgets/audio_button.dart';
import 'package:mboa_app/features/auth/auth_controller.dart';
import 'package:mboa_app/features/contribution/data/contribution_repository.dart';
import 'package:mboa_app/features/contribution/domain/models.dart';
import 'package:mboa_app/features/contribution/presentation/contribution_entry_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ContributionRepository {}

class _FakeAudio implements AudioService {
  final played = <String>[];
  @override
  Future<void> play(String url, {bool slow = false}) async => played.add(url);
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
  @override
  String? get currentUrl => null;
  @override
  Stream<PlayerState> get state => const Stream.empty();
}

const _entry = CorpusEntry(
  id: 'entry-1',
  lemma: 'ɓasaá',
  meaningFr: null,
  category: 'OTHER',
  status: 'TO_VERIFY',
  hasGloss: false,
  audioUrl: '/api/v1/audio/abc',
  audioAttribution: 'Bile rene (Lingua Libre) - CC BY-SA 4.0',
  sourceTitle: 'Lingua Libre — prononciations basaa',
  sourceLicense: 'CC_BY_SA',
  sourceLocator: 'Commons: LL-Q33093 (bas)-Bile rene-ɓasaá.wav',
);

Future<_MockRepo> _pump(
  WidgetTester tester, {
  CorpusEntry entry = _entry,
}) async {
  final repo = _MockRepo();
  // Surface haute : sinon la ListView ne construit pas les actions secondaires.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contributionRepositoryProvider.overrideWithValue(repo),
        audioServiceProvider.overrideWithValue(_FakeAudio()),
      ],
      child: MaterialApp(home: ContributionEntryScreen(entry: entry)),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('fiche de contribution', () {
    testWidgets('la provenance est affichée avant le formulaire', (
      tester,
    ) async {
      await _pump(tester);

      // On ne valide pas un mot sans savoir d'où il vient (SS4).
      expect(find.text('Provenance'), findsOneWidget);
      expect(
        find.textContaining('Lingua Libre', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('CC_BY_SA', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('LL-Q33093', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('ɓasaá'), findsOneWidget);
    });

    testWidgets('enregistrer sans traduction est refusé côté client', (
      tester,
    ) async {
      final repo = await _pump(tester);

      await tester.tap(find.text('Enregistrer la traduction'));
      await tester.pump();

      verifyNever(
        () => repo.save(
          any(),
          meaningFr: any(named: 'meaningFr'),
          category: any(named: 'category'),
          lemma: any(named: 'lemma'),
        ),
      );
      expect(
        find.textContaining('traduction française est nécessaire'),
        findsOneWidget,
      );
    });

    testWidgets('la saisie est envoyée et le nouveau statut affiché', (
      tester,
    ) async {
      final repo = await _pump(tester);
      when(
        () => repo.save(
          any(),
          meaningFr: any(named: 'meaningFr'),
          category: any(named: 'category'),
          lemma: any(named: 'lemma'),
        ),
      ).thenAnswer(
        (_) async => (
          status: 'HUMAN_REVIEW',
          message: 'Saisie enregistrée. En attente de relecture.',
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'la langue basaa');
      await tester.tap(find.text('Enregistrer la traduction'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => repo.save(
          captureAny(),
          meaningFr: captureAny(named: 'meaningFr'),
          category: any(named: 'category'),
          lemma: any(named: 'lemma'),
        ),
      ).captured;
      expect(captured[0], 'entry-1');
      expect(captured[1], 'la langue basaa');
      expect(find.textContaining('En attente de relecture'), findsOneWidget);
      expect(find.text('Statut : À relire'), findsOneWidget);
    });

    testWidgets('le bouton publier n\'apparaît qu\'une fois validé', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Publier dans l’application'), findsNothing);

      await _pump(
        tester,
        entry: const CorpusEntry(
          id: 'entry-2',
          lemma: 'màlep',
          meaningFr: 'eau',
          category: 'NOUN',
          status: 'VALIDATED',
          hasGloss: true,
        ),
      );
      expect(find.text('Publier dans l’application'), findsOneWidget);
    });

    testWidgets('le refus du serveur est montré sans perdre la saisie', (
      tester,
    ) async {
      final repo = await _pump(tester);
      when(
        () => repo.decide(
          any(),
          decision: any(named: 'decision'),
          comment: any(named: 'comment'),
        ),
      ).thenThrow(
        Exception(
          'Vous avez saisi cette entrée : un autre contributeur doit la valider.',
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'essai');
      await tester.tap(find.textContaining('Valider'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vous avez saisi'), findsOneWidget);
      // La saisie reste à l'écran : le contributeur ne recommence pas son travail.
      expect(find.text('essai'), findsOneWidget);
    });
  });

  group('session', () {
    test('seuls le spécialiste et l\'administrateur sont contributeurs', () {
      const learner = SessionState(status: AuthStatus.signedIn);
      const specialist = SessionState(
        status: AuthStatus.signedIn,
        role: 'CULTURAL_SPECIALIST',
      );
      const admin = SessionState(status: AuthStatus.signedIn, role: 'ADMIN');

      expect(learner.isContributor, isFalse);
      expect(specialist.isContributor, isTrue);
      expect(admin.isContributor, isTrue);
    });
  });

  group('avancement du corpus', () {
    test('le ratio de traduction est calculé sur le total', () {
      const language = ContributorLanguage(
        id: 'l',
        name: 'Basaa',
        iso: 'bas',
        missingGloss: 3,
        total: 12,
      );
      expect(language.glossRatio, 0.75);
    });

    test('un corpus vide ne divise pas par zéro', () {
      const language = ContributorLanguage(
        id: 'l',
        name: 'X',
        iso: 'xxx',
        missingGloss: 0,
        total: 0,
      );
      expect(language.glossRatio, 0);
    });
  });
}
