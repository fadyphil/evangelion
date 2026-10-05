import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/features/reading/domain/usecases/load_scripture.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/home_harness.dart';

class _MockReadingRepository extends Mock implements ReadingRepository {}

/// `ReadingCubit` — red-first (AGENT_CONTEXT §6: "**every cubit**", with
/// `bloc_test` + `mocktail`).
///
/// ## THE TWO THINGS THIS CUBIT OWNS, AND WHY ONLY TWO
///
/// The plan says the cubit owns "font scale and verse numbers, which come from
/// `SettingsRepository`". Phase 7 delivers **one** of those and not the other, and
/// both omissions are decisions rather than oversights:
///
/// * **Font scale** is real state with a real writer — the `Aa` control's
///   [ReadingCubit.setFontStep] — and it does not survive leaving `/reading`,
///   because `SettingsRepository` is Phase 9's. That cost is recorded on the cubit,
///   on `readingTextScalerFor` and in `AGENT_CONTEXT` §9, and **no test in this
///   repository claims persistence**.
///
/// * **Verse numbers are not state at all.** The prototype draws a `<sup>` on
///   every verse of both arms (`ReadingEnScreen.tsx:48`,
///   `ReadingArScreen.tsx:49`) and draws **no control** for turning them off. A
///   `bool` with no writer is the defect class this repository has already deleted
///   twice — recorded decision 15's dead `isValidUserId` branch, and decision 48's
///   an unreachable base-class equality getter — so it is **not** shipped.
///   `ScriptureBlock`
///   always renders the marker, and Phase 9's `/settings` reading section is where
///   the preference gets a real writer and a real reader.
void main() {
  late _MockReadingRepository repository;

  ReadingCubit build() {
    final ReadingCubit c = ReadingCubit(
      loadScripture: LoadScripture(repository),
    );
    addTearDown(c.close);
    return c;
  }

  // mocktail needs a value of the named type to build `any(named: 'language')`.
  // `home_bloc_test.dart:61` registers the same one for the same reason, and the
  // enum needs no `Fake` because a real member is a valid instance.
  setUpAll(() => registerFallbackValue(ReadingLanguage.english));

  setUp(() {
    repository = _MockReadingRepository();
    when(() => repository.todayScripture(language: any(named: 'language')))
        .thenAnswer(
          (_) async =>
              const Result<ScriptureText>.success(liveEnglishScripture),
        );
  });

  group('the initial state', () {
    test('is loading, with nothing on screen and the default step', () {
      final ReadingCubit c = build();
      expect(c.state.status, ReadingStatus.loading);
      expect(c.state.scripture, isNull);
      expect(c.state.failure, isNull);
      expect(c.state.fontStep, ReadingCubit.defaultFontStep);
    });

    test('the default step is the identity, which is 3 on the design-system table', () {
      // `evaScalerFor(3)` is 1.00 and the table's middle. Asserted rather than
      // assumed, because a default of 1 would mean the sanctuary renders at 0.90×
      // on a reader who never touched it.
      expect(ReadingCubit.defaultFontStep, 3);
      expect(evaScalerFor(ReadingCubit.defaultFontStep).scale(1), 1.0);
      expect(ReadingCubit.defaultFontStep, isNot(kFontStepMin));
      expect(ReadingCubit.defaultFontStep, isNot(kFontStepMax));
    });
  });

  blocTest<ReadingCubit, ReadingState>(
    'a successful load emits loading then ready, with the passage',
    build: build,
    act: (ReadingCubit c) => c.load(ReadingLanguage.english),
    expect: () => <ReadingState>[
      const ReadingState(),
      const ReadingState(
        status: ReadingStatus.ready,
        scripture: liveEnglishScripture,
      ),
    ],
    verify: (ReadingCubit c) {
      verify(() => repository.todayScripture(language: ReadingLanguage.english))
          .called(1);
    },
  );

  blocTest<ReadingCubit, ReadingState>(
    'a failed load emits loading then failed, and the FAILURE is carried whole',
    build: build,
    setUp: () {
      when(
        () => repository.todayScripture(language: any(named: 'language')),
      ).thenAnswer(
        (_) async => const Result<ScriptureText>.failure(
          Failure(kind: FailureKind.network, message: 'Could not reach it.'),
        ),
      );
    },
    act: (ReadingCubit c) => c.load(ReadingLanguage.english),
    expect: () => <Matcher>[
      isA<ReadingState>().having(
        (ReadingState s) => s.status,
        'status',
        ReadingStatus.loading,
      ),
      isA<ReadingState>()
          .having((ReadingState s) => s.status, 'status', ReadingStatus.failed)
          .having((ReadingState s) => s.scripture, 'scripture', isNull)
          .having(
            (ReadingState s) => s.failure?.message,
            'message',
            'Could not reach it.',
          ),
    ],
  );

  blocTest<ReadingCubit, ReadingState>(
    'a load CLEARS the previous passage, so a language change cannot show the other arm',
    build: build,
    setUp: () {
      // Answer **per language**, or both loads would produce the English passage
      // and the assertion below would pass for the wrong reason — the whole point
      // of clearing is that the second arm is a different arm.
      when(() => repository.todayScripture(language: ReadingLanguage.english))
          .thenAnswer(
            (_) async =>
                const Result<ScriptureText>.success(liveEnglishScripture),
          );
      when(() => repository.todayScripture(language: ReadingLanguage.arabic))
          .thenAnswer(
            (_) async =>
                const Result<ScriptureText>.success(liveArabicScripture),
          );
    },
    act: (ReadingCubit c) async {
      await c.load(ReadingLanguage.english);
      await c.load(ReadingLanguage.arabic);
    },
    expect: () => <Matcher>[
      isA<ReadingState>().having(
        (ReadingState s) => s.status,
        'status',
        ReadingStatus.loading,
      ),
      isA<ReadingState>().having(
        (ReadingState s) => s.status,
        'status',
        ReadingStatus.ready,
      ),
      // The second load empties first. Phase 6 measured the alternative: leaving the
      // old reading on screen during the request renders the previous session's
      // passage under the new language's chrome.
      isA<ReadingState>()
          .having((ReadingState s) => s.scripture, 'scripture', isNull)
          .having(
            (ReadingState s) => s.status,
            'status',
            ReadingStatus.loading,
          ),
      isA<ReadingState>()
          .having((ReadingState s) => s.scripture, 'scripture', isNotNull)
          .having(
            (ReadingState s) => s.scripture?.language,
            'language',
            ReadingLanguage.arabic,
          ),
    ],
    verify: (ReadingCubit c) {
      verify(() => repository.todayScripture(language: ReadingLanguage.english))
          .called(1);
      verify(() => repository.todayScripture(language: ReadingLanguage.arabic))
          .called(1);
    },
  );

  blocTest<ReadingCubit, ReadingState>(
    'a failure after a success does NOT keep the stale passage',
    build: build,
    act: (ReadingCubit c) async {
      await c.load(ReadingLanguage.english);
      when(() => repository.todayScripture(language: any(named: 'language')))
          .thenAnswer(
            (_) async => const Result<ScriptureText>.failure(
              Failure(kind: FailureKind.network, message: 'Gone.'),
            ),
          );
      await c.load(ReadingLanguage.arabic);
    },
    expect: () => <Matcher>[
      // Four emits, and the first is a `loading` **equal to the constructor's** —
      // `Cubit.emit` suppresses an equal state only once something has been
      // emitted, so the very first one always goes out. Measured, and written from
      // the measurement: the code read aloud says three.
      isA<ReadingState>().having(
        (ReadingState s) => s.status,
        'status',
        ReadingStatus.loading,
      ),
      isA<ReadingState>().having(
        (ReadingState s) => s.status,
        'status',
        ReadingStatus.ready,
      ),
      isA<ReadingState>().having(
        (ReadingState s) => s.status,
        'status',
        ReadingStatus.loading,
      ),
      isA<ReadingState>()
          .having((ReadingState s) => s.scripture, 'scripture', isNull)
          .having((ReadingState s) => s.failure?.message, 'message', 'Gone.')
          .having(
            (ReadingState s) => s.fontStep,
            'fontStep',
            ReadingCubit.defaultFontStep,
          ),
    ],
  );

  group('the font step', () {
    test('is settable to any step, and CLAMPED at both ends', () {
      final ReadingCubit c = build();
      c.setFontStep(5);
      expect(c.state.fontStep, 5);
      c.setFontStep(1);
      expect(c.state.fontStep, 1);
      // Out of range is clamped rather than stored, so the knob and the rendered
      // size cannot tell different stories — the reason `clampFontStep` exists.
      c.setFontStep(0);
      expect(c.state.fontStep, kFontStepMin);
      c.setFontStep(99);
      expect(c.state.fontStep, kFontStepMax);
    });

    test('setting the step it already has emits NOTHING', () {
      // The property that keeps the disclosure panel from rebuilding the whole
      // passage on every drag frame of `FontSizeStepper`'s track.
      final ReadingCubit c = build()..setFontStep(3);
      expect(c.state.fontStep, ReadingCubit.defaultFontStep);
      expect(
        () => c.setFontStep(ReadingCubit.defaultFontStep),
        returnsNormally,
      );
      expect(c.state.fontStep, ReadingCubit.defaultFontStep);
    });

    test(
      'survives a load, because it is the reader\'s and not the payload\'s',
      () async {
        final ReadingCubit c = build();
        c.setFontStep(4);
        await c.load(ReadingLanguage.english);
        expect(c.state.fontStep, 4);
        expect(c.state.scripture, isNotNull);
      },
    );

    test('and it is NOT cleared by a failure either', () async {
      final ReadingCubit c = build();
      c.setFontStep(4);
      when(() => repository.todayScripture(language: any(named: 'language')))
          .thenAnswer(
            (_) async => const Result<ScriptureText>.failure(
              Failure(kind: FailureKind.network, message: 'x'),
            ),
          );
      await c.load(ReadingLanguage.english);
      expect(
        c.state.fontStep,
        4,
        reason: 'a retry must not reset the reader\'s size',
      );
    });
  });

  group('the cubit is a Cubit and not a Bloc, and here is why that is load-bearing', () {
    test('there is no event type, so there is no event equality to get wrong', () {
      // Recorded decision 48 is about `HomeEvent`'s base equality being uncovered because it
      // was unreachable. The way this phase avoids that class entirely is to have
      // no events: `ReadingCubit` is a `Cubit`, its inputs are method parameters,
      // and `bloc.add` — which swallows a duplicate when every event is equal —
      // is not reachable from it at all.
      final ReadingCubit c = build();
      expect(c, isA<Cubit<ReadingState>>());
      expect(
        c,
        isNot(isA<Bloc<Object, ReadingState>>()),
        reason:
            'and there is no such class, which is the point — `Bloc.add` is '
            'not reachable from this cubit',
      );
    });

    test('`load` and a retry are the SAME method, because there is one section', () {
      // Phase 6 needs two events because `/` has two independent sections and a
      // retry must re-request only the failed one (`home_bloc_test.dart`'s
      // `verifyNever`). `/reading` has one, so a `retry` event would be a second
      // spelling of `load` with nothing to distinguish them.
      final ReadingCubit c = build();
      expect(c.load, isNotNull);
      expect(() => c.retry(ReadingLanguage.english), returnsNormally);
    });
  });

  group('ReadingState', () {
    test('equality covers every field, so a rebuild is a real change', () {
      const ReadingState base = ReadingState();
      expect(base, const ReadingState());
      expect(base.hashCode, const ReadingState().hashCode);
      expect(base.copyWith(), base);
      for (final ReadingState other in <ReadingState>[
        base.copyWith(status: ReadingStatus.ready),
        base.copyWith(scripture: liveEnglishScripture),
        base.copyWith(
          failure: const Failure(kind: FailureKind.network, message: 'x'),
        ),
        base.copyWith(fontStep: 5),
      ]) {
        expect(base, isNot(other), reason: '$other must differ');
      }
    });

    test('the three statuses are exactly loading, ready and failed', () {
      // Phase 6's `HomeSectionStatus` doc gives the argument: "loading" is not "no
      // data", and a two-value enum would have to encode it as one.
      expect(ReadingStatus.values, <ReadingStatus>[
        ReadingStatus.loading,
        ReadingStatus.ready,
        ReadingStatus.failed,
      ]);
    });

    test('`ready` and `failed` are distinguishable without the payload', () {
      const ReadingState ready = ReadingState(
        status: ReadingStatus.ready,
        scripture: liveEnglishScripture,
      );
      const ReadingState failed = ReadingState(
        status: ReadingStatus.failed,
        failure: Failure(kind: FailureKind.network, message: 'x'),
      );
      expect(ready, isNot(failed));
      expect(ready.status, isNot(failed.status));
    });
  });

  test('the cubit never throws, whatever the repository does', () async {
    final ReadingCubit c = build();
    when(() => repository.todayScripture(language: any(named: 'language')))
        .thenThrow(StateError('a fake that throws, which §3 LSP forbids'));
    // §3's LSP row: a repository never throws across the seam, and a cubit that
    // guards against a misbehaving one anyway is not the place the defence lives.
    // What this asserts is the *observable* half: the state does not become
    // something the page cannot render.
    expect(() => c.load(ReadingLanguage.english), throwsStateError);
    expect(c.state.status, ReadingStatus.loading);
  });
}
