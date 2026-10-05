import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
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
/// ## THE ONE THING THIS CUBIT OWNS, AND WHY IT IS ONE
///
/// The plan says the cubit owns "font scale and verse numbers, which come from
/// `SettingsRepository`". Phase 7 delivered **neither** — the font scale as cubit
/// state and no verse-number field at all — and Phase 9 settled both:
///
/// * **The font scale is not here any more.** It is `UserSettings.fontStep`, persisted
///   in `shared_preferences` and installed app-wide at `MaterialApp.builder`. The
///   `ReadingCubit.setFontStep` method and the `ReadingState.fontStep` field are
///   **deleted**, and the group below that tested them is replaced by one that asserts
///   they are gone — a `Cubit` that held a second copy of a preference is the
///   "two sources of truth for one fact" defect, and it would have disagreed with
///   `app.dart` for the one window between the reader's gesture and the store's write.
///   The persistence claim this file used to refuse to make is now made, in
///   `test/core/domain/repositories/settings_repository_test.dart`.
///
/// * **Verse numbers are still not state.** The prototype's reading screens draw a
///   `<sup>` on every verse of both arms (`ReadingEnScreen.tsx:48`,
///   `ReadingArScreen.tsx:49`) and draw **no control** for turning them off. Phase 9
///   built `/settings`, whose prototype screen *does* have the switch
///   (`SettingsScreen.tsx:92`), and still did not ship it — for a **scope** reason
///   rather than a writer reason, recorded on `SettingsPage`: `ScriptureBlock` has no
///   `showVerseNumbers` parameter and its marker is load-bearing for four gates this
///   phase does not own.
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
    test('is loading, with nothing on screen', () {
      final ReadingCubit c = build();
      expect(c.state.status, ReadingStatus.loading);
      expect(c.state.scripture, isNull);
      expect(c.state.failure, isNull);
      expect(c.state.textSizePanelOpen, isFalse);
    });

    test('and it holds **NO** font step, which is Phase 9\'s deletion', () {
      // The failing direction, and it is the only way to assert an ABSENCE about a
      // generated class: `ReadingState` is `freezed`, so the field cannot be read at
      // all any more, and this file no longer compiles if it reappears.
      //
      // What that cannot express is "and the default is still the table's identity" —
      // so that claim moved to `user_settings_test.dart`, where `kDefaultFontStep`
      // lives, and it is asserted there against `evaScalerFor`.
      final ReadingCubit c = build();
      expect(c.state, const ReadingState());
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
          .having((ReadingState s) => s.failure?.message, 'message', 'Gone.'),
    ],
  );

  group('the font step left this cubit, and what replaced it', () {
    test('`toggleTextSizePanel` is still the only writer of the disclosure', () {
      // The one thing that **is** a property of this visit, and therefore still
      // cubit state. `reading_page_test.dart` asserts it opens and closes and asserts
      // nothing about surviving a navigation — which is now the *contrast* that makes
      // the step's persistence legible: one flag on screen, one preference on disk.
      final ReadingCubit c = build();
      expect(c.state.textSizePanelOpen, isFalse);
      c.toggleTextSizePanel();
      expect(c.state.textSizePanelOpen, isTrue);
      c.toggleTextSizePanel();
      expect(c.state.textSizePanelOpen, isFalse);
    });

    test('the disclosure survives a load AND a failure', () async {
      // `ReadingState`'s doc claims it does, and the claim used to be about the step
      // too. The step is gone; the flag is not, so the assertion stays and names the
      // flag instead of a field that is no longer here.
      final ReadingCubit c = build()..toggleTextSizePanel();
      await c.load(ReadingLanguage.english);
      expect(c.state.textSizePanelOpen, isTrue);
      when(() => repository.todayScripture(language: any(named: 'language')))
          .thenAnswer(
            (_) async => const Result<ScriptureText>.failure(
              Failure(kind: FailureKind.network, message: 'x'),
            ),
          );
      await c.retry(ReadingLanguage.english);
      expect(
        c.state.textSizePanelOpen,
        isTrue,
        reason: 'opening the Aa panel must not close itself on a network fault',
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
        base.copyWith(textSizePanelOpen: true),
      ]) {
        expect(base, isNot(other), reason: '$other must differ');
      }
      // `freezed_structural_equality_test.dart` asserts the same property over the
      // **whole** converted set with an exhaustive per-field variant list, so this
      // copy is the local restatement and that file is the gate.
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
