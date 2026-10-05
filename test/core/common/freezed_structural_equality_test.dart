import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/quiz/domain/refreshed_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/submit_answer.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/freezed_types.dart';

/// Structural equality over **every** class the `freezed` migration converted.
///
/// ## WHY THIS FILE EXISTS
///
/// AGENT_CONTEXT §2.1, hazard 3: "`freezed` generates `const` constructors,
/// which adds new `const`-canonicalisation surfaces", against a project that has
/// already shipped **eight** canonicalisation bugs. The two gates that hazard asks
/// for are this one and
/// `test/core/common/no_identical_on_converted_types_test.dart`.
///
/// ## TWO CLAIMS PER TYPE, AND THE SECOND ONE IS THE ONE WITH TEETH
///
/// 1. **two structurally-equal instances compare equal**, after asserting they are
///    not the same object — see the construction note below;
/// 2. **changing _any one_ field makes them unequal**, and the list of fields is
///    **exhaustive**: `_differsInEveryField` is handed the field count and fails if
///    the list is shorter.
///
/// ## 2 IS NOT A NICETY. THE FIRST VERSION SAMPLED, AND THE MUTATION GOT THROUGH.
///
/// It asserted `isCorrect` and `currentStreak` for `SubmitResult`, and dropping
/// `readingCompleted` from the generated `==` — the exact mutation this file
/// exists to catch — left the whole file **green**. Two of seven fields is a
/// sample, and a sample is a gate with a hole in it shaped like the fields nobody
/// thought to name. Every call below now lists one variant per declared field and
/// passes the count, so a new field is a compile-time-shaped omission rather than
/// a silent one.
///
/// ## WHAT IT DOES **NOT** CLAIM
///
/// Nothing about `freezed`'s output being *correct*: freezed derives `==` from the
/// constructor, so claim 1 says the fields are still declared and claim 2 says a
/// `==` is complete. There are no hand-written `==`s among the converted types —
/// the two in `lib/` (`Failure` and `SignInParams`) are **not** converted, and the
/// one that matters is pinned by `failure_equality_test.dart`. So this file is
/// insurance over a generator's *inputs*, which are hand-written, and it is cheap
/// because it is mechanical.
///
/// ## AND THE CONSTRUCTION IS DELIBERATELY **NOT** `const`
///
/// Every builder returns a fresh object, so two calls are two allocations.
/// `const Verse(...)` written twice is canonicalised by Dart into one instance,
/// `expect(a, b)` becomes `identical`, and every assertion here would pass against
/// a `==` that returned `false`. `identical(…, isFalse)` is asserted **first** in
/// each pair, so a construction change that made the pair one canonicalised
/// instance turns this file red instead of quietly turning it into
/// `expect(x, x)` everywhere.
void main() {
  group('entities', () {
    test('`Verse`', () {
      _equalAndDistinct('Verse', _verse(), _verse());
      _differsInEveryField(
        'Verse',
        _verse(),
        fields: 5,
        variants: <({String field, Verse value})>[
          (field: 'bookNumber', value: _verse(bookNumber: 44)),
          (field: 'chapter', value: _verse(chapter: 4)),
          (field: 'number', value: _verse(number: 2)),
          (field: 'text', value: _verse(text: 'other')),
          (field: 'textClean', value: _verse(textClean: 'clean')),
        ],
      );
    });

    test('`ScriptureText`', () {
      _equalAndDistinct('ScriptureText', _passage(), _passage());
      _differsInEveryField(
        'ScriptureText',
        _passage(),
        fields: 11,
        variants: <({String field, ScriptureText value})>[
          (field: 'readingId', value: _passage(readingId: 'other')),
          (field: 'groupId', value: _passage(groupId: 4)),
          (
            field: 'scheduledDate',
            value: _passage(scheduledDate: '2026-10-05'),
          ),
          (
            field: 'language',
            value: _passage(language: ReadingLanguage.arabic),
          ),
          (field: 'reference', value: _passage(reference: 'John 3:1-6')),
          (field: 'translation', value: _passage(translation: 'NKJV')),
          (field: 'verses', value: _passage(verses: const <Verse>[])),
          (field: 'questions', value: _passage(questions: <Question>[])),
          (field: 'isFullyCompleted', value: _passage(isFullyCompleted: false)),
          (field: 'pointsEarnedToday', value: _passage(pointsEarnedToday: 0)),
          (field: 'currentStreak', value: _passage(currentStreak: 0)),
        ],
      );
    });

    test('`TodayReading`', () {
      _equalAndDistinct('TodayReading', _today(), _today());
      _differsInEveryField(
        'TodayReading',
        _today(),
        fields: 13,
        variants: <({String field, TodayReading value})>[
          (field: 'readingId', value: _today(readingId: 'other')),
          (field: 'groupId', value: _today(groupId: 4)),
          (field: 'scheduledDate', value: _today(scheduledDate: '2026-10-05')),
          (field: 'language', value: _today(language: ReadingLanguage.arabic)),
          (field: 'reference', value: _today(reference: 'John 3:1-6')),
          (field: 'translation', value: _today(translation: 'NKJV')),
          (field: 'verseCount', value: _today(verseCount: 4)),
          (field: 'firstVerseText', value: _today(firstVerseText: 'other')),
          (field: 'questionCount', value: _today(questionCount: 0)),
          (
            field: 'answeredQuestionCount',
            value: _today(answeredQuestionCount: 0),
          ),
          (field: 'isFullyCompleted', value: _today(isFullyCompleted: false)),
          (field: 'pointsEarnedToday', value: _today(pointsEarnedToday: 0)),
          (field: 'currentStreak', value: _today(currentStreak: 0)),
        ],
      );
    });

    test('`Question`', () {
      _equalAndDistinct('Question', _question(), _question());
      _differsInEveryField(
        'Question',
        _question(),
        fields: 9,
        variants: <({String field, Question value})>[
          (field: 'id', value: _question(id: 'question-2')),
          (field: 'sortOrder', value: _question(sortOrder: 2)),
          (field: 'type', value: _question(type: 'bool')),
          (field: 'prompt', value: _question(prompt: 'other')),
          (
            field: 'options',
            value: _question(options: const <String, String>{}),
          ),
          (field: 'pointsValue', value: _question(pointsValue: 20)),
          (field: 'alreadyAnswered', value: _question(alreadyAnswered: true)),
          (field: 'userAnswer', value: _question(userAnswer: 'A')),
          (field: 'isCorrect', value: _question(isCorrect: true)),
        ],
      );
    });

    test('`StreakSummary`', () {
      _equalAndDistinct('StreakSummary', _streak(), _streak());
      _differsInEveryField(
        'StreakSummary',
        _streak(),
        fields: 8,
        variants: <({String field, StreakSummary value})>[
          (field: 'currentStreak', value: _streak(currentStreak: 4)),
          (field: 'longestStreak', value: _streak(longestStreak: 7)),
          (
            field: 'lastCompletedDate',
            value: _streak(lastCompletedDate: '2026-10-02'),
          ),
          (
            field: 'todayStatus',
            value: _streak(todayStatus: StreakTodayStatus.completed),
          ),
          (field: 'todayCompleted', value: _streak(todayCompleted: true)),
          (field: 'todayScheduled', value: _streak(todayScheduled: false)),
          (field: 'nextMilestone', value: _streak(nextMilestone: 5)),
          (field: 'daysToMilestone', value: _streak(daysToMilestone: 0)),
        ],
      );
    });

    test('`SubmitResult`', () {
      _equalAndDistinct('SubmitResult', _submit(), _submit());
      _differsInEveryField(
        'SubmitResult',
        _submit(),
        fields: 7,
        variants: <({String field, SubmitResult value})>[
          (field: 'questionId', value: _submit(questionId: 'question-2')),
          (field: 'isCorrect', value: _submit(isCorrect: false)),
          (field: 'pointsEarned', value: _submit(pointsEarned: 0)),
          (field: 'currentTotalPoints', value: _submit(currentTotalPoints: 0)),
          (field: 'currentStreak', value: _submit(currentStreak: 4)),
          (field: 'longestStreak', value: _submit(longestStreak: 7)),
          (field: 'readingCompleted', value: _submit(readingCompleted: false)),
        ],
        // The field this mutation was caught by. It is the seventh of seven and
        // the list above is the seventh entry — the count assertion is what turns
        // "someone remembered to name it" into "the list is complete".
      );
    });

    test('`AuthSession`', () {
      _equalAndDistinct('AuthSession', _session(), _session());
      _differsInEveryField(
        'AuthSession',
        _session(),
        fields: 6,
        variants: <({String field, AuthSession value})>[
          (field: 'userId', value: _session(userId: _otherUserId())),
          (field: 'email', value: _session(email: 'other@example.com')),
          (field: 'displayName', value: _session(displayName: 'Someone')),
          (field: 'initials', value: _session(initials: 'XX')),
          (field: 'role', value: _session(role: 'adult')),
          // A different **instant**. `DateTime`'s `==` is by value, so this field
          // was never identity-compared — `equatable` used plain `==` and freezed
          // does the same. Worth saying, because "a `DateTime` field" is the one
          // field type where identity and equality genuinely differ.
          (field: 'createdAt', value: _session(createdAt: _laterInstant())),
        ],
      );
    });

    test('`QuizAnswer`', () {
      _equalAndDistinct('QuizAnswer', _answer(), _answer());
      _differsInEveryField(
        'QuizAnswer',
        _answer(),
        fields: 3,
        variants: <({String field, QuizAnswer value})>[
          (field: 'question', value: _answer(question: _question(id: 'other'))),
          (field: 'selectedLetter', value: _answer(selectedLetter: 'B')),
          (field: 'verdict', value: _answer(verdict: _submit())),
        ],
      );
    });

    test('`QuizSession`', () {
      _equalAndDistinct('QuizSession', _session_(), _session_());
      _differsInEveryField(
        'QuizSession',
        _session_(),
        fields: 2,
        variants: <({String field, QuizSession value})>[
          (field: 'readingId', value: _session_(readingId: 'other')),
          (field: 'answers', value: _session_(answers: const <QuizAnswer>[])),
        ],
      );
    });

    test('`RefreshedQuestions`', () {
      _equalAndDistinct('RefreshedQuestions', _refreshed(), _refreshed());
      _differsInEveryField(
        'RefreshedQuestions',
        _refreshed(),
        fields: 2,
        variants: <({String field, RefreshedQuestions value})>[
          (field: 'readingId', value: _refreshed(readingId: 'other')),
          (field: 'questions', value: _refreshed(questions: <Question>[])),
        ],
      );
    });

    test('`SubmitAnswerParams`', () {
      _equalAndDistinct('SubmitAnswerParams', _params(), _params());
      _differsInEveryField(
        'SubmitAnswerParams',
        _params(),
        fields: 3,
        variants: <({String field, SubmitAnswerParams value})>[
          (field: 'readingId', value: _params(readingId: 'other')),
          (field: 'questionId', value: _params(questionId: 'question-2')),
          (field: 'answer', value: _params(answer: 'B')),
        ],
      );
    });
  });

  group('auth', () {
    test('`LoginCredentials`', () {
      _equalAndDistinct('LoginCredentials', _credentials(), _credentials());
      _differsInEveryField(
        'LoginCredentials',
        _credentials(),
        fields: 2,
        variants: <({String field, LoginCredentials value})>[
          (field: 'email', value: _credentials(email: 'a@b.co')),
          (field: 'password', value: _credentials(password: 'another-secret')),
        ],
        note:
            'the secret IS in the equality contract — only printing is masked, '
            'and `secret_masking_test.dart` is what says so',
      );
    });

    test('`LoginValidation`', () {
      _equalAndDistinct('LoginValidation', _valid(), _valid());
      _differsInEveryField(
        'LoginValidation',
        _valid(),
        fields: 2,
        variants: <({String field, LoginValidation value})>[
          (field: 'emailError', value: _invalid()),
          (field: 'passwordError', value: _invalid()),
        ],
        note:
            'it holds MESSAGES about a password, never a password, which is '
            'why the secret gate\'s scan correctly reports nothing here',
      );
    });

    test('`AuthState`', () {
      _equalAndDistinct('AuthState', _authState(), _authState());
      _differsInEveryField(
        'AuthState',
        _authState(),
        fields: 10,
        variants: <({String field, AuthState value})>[
          (
            field: 'status',
            value: _authState(status: AuthSessionStatus.unknown),
          ),
          (field: 'email', value: _authState(email: 'other@example.com')),
          (field: 'password', value: _authState(password: 'another-secret')),
          (
            field: 'isPasswordVisible',
            value: _authState(isPasswordVisible: true),
          ),
          (field: 'emailTouched', value: _authState(emailTouched: true)),
          (field: 'passwordTouched', value: _authState(passwordTouched: true)),
          (
            field: 'emailError',
            value: _authState().withFormError(_requiredMessage()),
          ),
          (
            field: 'passwordError',
            value: _authState().withFormError(_shortMessage()),
          ),
          (field: 'formError', value: _authState().withFormError('boom')),
          (field: 'session', value: _authState(session: _session())),
        ],
        note:
            'the four nullable fields are reachable ONLY through the writers — '
            '`copyWith` is switched off — so these four variants go through '
            '`withFormError`, which is the mechanical half of that decision',
      );

      // The clearing half, asserted as an **equality** rather than a difference:
      // two calls, because `withFormError(null)` on a state that carries no error
      // yet *is* the state, and asserting them unequal would be asserting that a
      // writer did nothing. This is the one writer that can clear a nullable
      // field, so it is asserted here — "switched off" must not quietly become
      // "nobody noticed it was missing".
      _equalAndDistinct(
        'AuthState',
        _authState().withFormError('boom').withFormError(null),
        _authState(),
        reason:
            'clearing a field with the one writer that may leaves a state that '
            'compares equal to the pristine one',
      );
    });
  });

  group('states', () {
    test('`HomeState`', () {
      _equalAndDistinct('HomeState', _homeState(), _homeState());
      _differsInEveryField(
        'HomeState',
        _homeState(),
        fields: 10,
        variants: <({String field, HomeState value})>[
          (
            field: 'readingStatus',
            value: _homeState(readingStatus: HomeSectionStatus.failed),
          ),
          (
            field: 'streakStatus',
            value: _homeState(streakStatus: HomeSectionStatus.failed),
          ),
          (
            field: 'readerStatus',
            value: _homeState(readerStatus: HomeSectionStatus.failed),
          ),
          (
            field: 'greetingPeriod',
            value: _homeState().withGreetingPeriod(GreetingPeriod.evening),
          ),
          (field: 'readerName', value: _homeState(readerName: 'Someone')),
          (field: 'readerInitials', value: _homeState(readerInitials: 'XX')),
          (field: 'reading', value: _homeState(reading: _today())),
          (
            field: 'readingFailure',
            value: _homeState().withReading(
              status: HomeSectionStatus.failed,
              reading: null,
              failure: _failure(),
            ),
          ),
          (field: 'streak', value: _homeState(streak: _streak())),
          (
            field: 'streakFailure',
            value: _homeState().withStreak(
              status: HomeSectionStatus.failed,
              streak: null,
              failure: _failure(),
            ),
          ),
        ],
        note:
            'the three nullable fields are reachable through the three whole-state '
            'writers, which is why `copyWith` is switched off on this class',
      );
    });

    test('`QuizState`', () {
      _equalAndDistinct('QuizState', _quizState(), _quizState());
      _differsInEveryField(
        'QuizState',
        _quizState(),
        fields: 5,
        variants: <({String field, QuizState value})>[
          (field: 'status', value: _quizState(status: QuizStatus.loading)),
          (field: 'session', value: _quizState(session: _session_())),
          (field: 'currentIndex', value: _quizState(currentIndex: 1)),
          (field: 'failure', value: _quizState(failure: _failure())),
          (field: 'lastResult', value: _quizState(lastResult: _submit())),
        ],
      );
    });

    test('`ReadingState`', () {
      _equalAndDistinct('ReadingState', _readingState(), _readingState());
      _differsInEveryField(
        'ReadingState',
        _readingState(),
        fields: 4,
        variants: <({String field, ReadingState value})>[
          (field: 'status', value: _readingState(status: ReadingStatus.failed)),
          (field: 'scripture', value: _readingState(scripture: _passage())),
          (field: 'failure', value: _readingState(failure: _failure())),
          (
            field: 'textSizePanelOpen',
            value: _readingState(textSizePanelOpen: true),
          ),
        ],
      );
    });

    // ## PHASE 9'S TWO, AND THE ONE THAT MATTERS MOST IS THE NULLABLE ONE
    //
    // `UserSettings.language` is the only nullable field in either type, and it is
    // nullable **on purpose** — `null` means "follow the platform", a third answer
    // rather than an absence. So it gets a variant in **both** directions: setting it
    // and clearing it must both produce an unequal instance, and only a *generated*
    // `copyWith` gives the clearing half. That is the §2.1 hazard this file was built
    // for and the reason it lists a variant per field rather than sampling.
    test('`UserSettings`', () {
      _equalAndDistinct('UserSettings', _userSettings(), _userSettings());
      _differsInEveryField(
        'UserSettings',
        _userSettings(),
        fields: 4,
        variants: <({String field, UserSettings value})>[
          (
            field: 'themeMode',
            value: _userSettings(themeMode: AppThemeMode.light),
          ),
          (field: 'fontStep', value: _userSettings(fontStep: 5)),
          (
            field: 'language',
            value: _userSettings(language: ReadingLanguage.arabic),
          ),
          (field: 'reducedMotion', value: _userSettings(reducedMotion: true)),
        ],
      );
    });

    test(
      '`UserSettings.language` is clearable, and clearing it is not identity',
      () {
        final UserSettings arabic = _userSettings(
          language: ReadingLanguage.arabic,
        );
        expect(
          arabic.copyWith(),
          arabic,
          reason: 'omitting the argument keeps it',
        );
        expect(
          arabic.copyWith(language: null),
          _userSettings(),
          reason:
              'passing the sentinel CLEARS it. This is the half a hand-written '
              '`copyWith` with `language ?? this.language` could not express, and it '
              'is what makes "follow the platform" reachable after a choice.',
        );
      },
    );

    test('`SettingsState`', () {
      _equalAndDistinct('SettingsState', _settingsState(), _settingsState());
      _differsInEveryField(
        'SettingsState',
        _settingsState(),
        fields: 3,
        variants: <({String field, SettingsState value})>[
          (
            field: 'status',
            value: _settingsState(status: SettingsStatus.loading),
          ),
          (
            field: 'settings',
            value: _settingsState(
              settings: _userSettings(themeMode: AppThemeMode.system),
            ),
          ),
          (field: 'failure', value: _settingsState(failure: _failure())),
        ],
      );
    });
  });

  group('events', () {
    // Every event below has exactly one field, so each gets one variant and the
    // count is 1. The seven field-less events get the other half of the claim,
    // recorded rather than asserted — see the group below.

    test('the seven events that carry a field', () {
      _differsInEveryField(
        'AuthEmailChanged',
        AuthEmailChanged(_text('a@example.com')),
        fields: 1,
        variants: <({String field, AuthEmailChanged value})>[
          (field: 'email', value: AuthEmailChanged(_text('b@example.com'))),
        ],
      );
      _equalAndDistinct(
        'AuthEmailChanged',
        AuthEmailChanged(_text('a@example.com')),
        AuthEmailChanged(_text('a@example.com')),
      );

      _differsInEveryField(
        'AuthPasswordChanged',
        AuthPasswordChanged(_text('one secret')),
        fields: 1,
        variants: <({String field, AuthPasswordChanged value})>[
          (
            field: 'password',
            value: AuthPasswordChanged(_text('another secret')),
          ),
        ],
        note:
            'the generated `==` carries the secret; the hand-written `toString` is '
            'what keeps it out of the log, and those are two different members',
      );
      _equalAndDistinct(
        'AuthPasswordChanged',
        AuthPasswordChanged(_text('one secret')),
        AuthPasswordChanged(_text('one secret')),
      );

      _oneFieldEvent<HomeStarted>(
        'HomeStarted',
        () => HomeStarted(_language()),
        () => HomeStarted(_arabic()),
      );
      _oneFieldEvent<HomeRetried>(
        'HomeRetried',
        () => HomeRetried(_language()),
        () => HomeRetried(_arabic()),
      );
      _oneFieldEvent<QuizStarted>(
        'QuizStarted',
        () => QuizStarted(_language()),
        () => QuizStarted(_arabic()),
      );
      _oneFieldEvent<QuizRetried>(
        'QuizRetried',
        () => QuizRetried(_language()),
        () => QuizRetried(_arabic()),
      );
      _oneFieldEvent<QuizOptionSelected>(
        'QuizOptionSelected',
        () => QuizOptionSelected(_text('A')),
        () => QuizOptionSelected(_text('B')),
      );
    });

    test('the seven field-less events are told apart by their type', () {
      // Recorded as an assertion rather than a comment because it is the only
      // half of the claim that is writable for these seven, and it is the half
      // with consequences: `bloc` applies `distinct()` to its event stream, so if
      // two field-less events compared equal, a `QuizAdvanced` would be swallowed
      // behind a `QuizAnswerChecked` and the reader's press would do nothing.
      //
      // ## AND THERE IS **NO** "TWO `QuizAnswerChecked`s ARE EQUAL" ASSERTION
      //
      // Because it cannot be written without proving nothing. `const
      // QuizAnswerChecked()` is canonicalised by Dart into ONE instance, so two of
      // them are `identical` and any `==` returns true on that fast path. Building
      // two non-const instances is impossible to spell without an `// ignore:` for
      // `prefer_const_constructors`, and this repository uses none —
      // `home_bloc_test.dart` records the same argument for `HomeCleared`.
      final Set<Object> seven = <Object>{
        const AuthStarted(),
        const AuthPasswordVisibilityToggled(),
        const AuthSubmitted(),
        const AuthSignedOut(),
        const HomeCleared(),
        const QuizAnswerChecked(),
        const QuizAdvanced(),
      };
      expect(
        seven,
        hasLength(7),
        reason:
            'a Set of seven that holds seven elements, so no two of them are '
            'equal — which is the only claim a field-less event can carry',
      );
      expect(
        const AuthStarted(),
        isNot(equals(const AuthSubmitted())),
        reason: 'and named, so a failure says which pair',
      );
      expect(const QuizAnswerChecked(), isNot(equals(const QuizAdvanced())));
      expect(const QuizAdvanced(), isNot(equals(const QuizAnswerChecked())));
    });
  });

  group('the coverage is not vacuous', () {
    // The two-way check, and it is what turns this file from a pile of equality
    // assertions into a gate over the *whole* converted set:
    //
    // * every name asserted above must be a class `freezed` owns — otherwise this
    //   file asserts equality of something the migration never touched; and
    // * every class `freezed` owns must appear in [_assertedTypeNames] — otherwise a
    //   type converted without a word here, and this file reports a clean run over
    //   a smaller set than it claims.
    test('every type asserted above is one freezed declares', () {
      final Set<String> converted = freezedTypeNamesInLib();
      expect(
        converted,
        hasLength(36),
        reason:
            'the converted set moved. 19 classes, 14 events and 3 sealed bases is '
            'what it now holds: the migration produced 17 classes, and Phase 9 added '
            '`UserSettings` and `SettingsState`. If this number moved, the migration '
            'or the phase moved and this file has to be told',
      );
      for (final String name in _assertedTypeNames) {
        expect(
          converted,
          contains(name),
          reason:
              '$name is asserted here but lib/ does not say freezed owns it',
        );
      }
    });

    test('and every type freezed owns is asserted above', () {
      final Set<String> missing = freezedTypeNamesInLib().difference(
        _assertedTypeNames,
      );
      expect(
        missing,
        isEmpty,
        reason:
            'these classes are converted and nothing in this file checks their '
            'equality. Add them: a missing name is a hole in the gate, not a '
            'detail',
      );
    });
  });
}

/// Asserts [a] and [b] are equal **and** are two objects.
///
/// The `identical` guard comes first so that a construction change which made the
/// pair one canonicalised instance turns this red instead of quietly turning the
/// whole file into `expect(x, x)`.
void _equalAndDistinct<T extends Object>(
  String label,
  T a,
  T b, {
  String? reason,
}) {
  expect(
    identical(a, b),
    isFalse,
    reason:
        '$label: the two operands are the same object, so every assertion '
        'after this one is vacuous',
  );
  expect(a, b, reason: reason ?? '$label: structurally equal is equal');
  expect(
    a.hashCode,
    b.hashCode,
    reason: '$label: equal values must hash alike, or a Set holds two of them',
  );
}

/// Asserts that changing **each** declared field makes the two unequal.
///
/// [fields] is the declared field count, and it is asserted against the list
/// length: without it, a variant nobody remembered to write is a hole shaped like
/// the fields nobody remembered. That hole is not hypothetical — the first version
/// of this file sampled two of `SubmitResult`'s seven fields and a dropped
/// `readingCompleted` sailed through it.
void _differsInEveryField<T extends Object>(
  String label,
  T base, {
  required int fields,
  required List<({String field, T value})> variants,
  String? note,
}) {
  expect(
    variants,
    hasLength(fields),
    reason:
        '$label declares $fields fields and this list names ${variants.length}. '
        'One variant per field, or the "a missed field is invisible" half of '
        'this gate has a hole in it',
  );
  final List<String> missed = <String>[
    for (final ({String field, T value}) variant in variants)
      if (base == variant.value) '`${variant.field}`',
  ];
  expect(
    missed,
    isEmpty,
    reason:
        '$label: changing ${missed.join(', ')} left two instances EQUAL. A `==` '
        'that forgot a field passes the equality check above and fails this one'
        '${note == null ? '' : ' — $note'}',
  );
}

/// The whole claim for an event with exactly one field: two equal instances, and
/// one that differs.
void _oneFieldEvent<T extends Object>(
  String label,
  T Function() build,
  T Function() other,
) {
  _equalAndDistinct(label, build(), build());
  _differsInEveryField<T>(
    label,
    build(),
    fields: 1,
    variants: <({String field, T value})>[
      (field: _onlyFieldOf(build()), value: other()),
    ],
  );
}

/// The field name of a one-field event, for the failure message.
///
/// Taken from the class rather than hard-coded per call so a second field added
/// to an event shows up as a wrong name here instead of a silent single variant.
String _onlyFieldOf(Object event) {
  if (event is AuthEmailChanged) return 'email';
  if (event is AuthPasswordChanged) return 'password';
  if (event is HomeStarted) return 'language';
  if (event is HomeRetried) return 'language';
  if (event is QuizStarted) return 'language';
  if (event is QuizRetried) return 'language';
  if (event is QuizOptionSelected) return 'letter';
  throw StateError('no field name is known for $event');
}

/// Every type this file asserts equality for.
///
/// A hand-written list on purpose, and the group above is what keeps it honest:
/// `freezedTypeNamesInLib()` derives the truth from `lib/`, and this file fails if
/// the two disagree in either direction. The alternative — discovering the types
/// here too — would mean discovering the *assertions*, which a scanner cannot do.
const Set<String> _assertedTypeNames = <String>{
  // The 17 classes with fields of their own.
  'Verse',
  'ScriptureText',
  'TodayReading',
  'Question',
  'StreakSummary',
  'SubmitResult',
  'AuthSession',
  'QuizAnswer',
  'QuizSession',
  'RefreshedQuestions',
  'SubmitAnswerParams',
  'LoginCredentials',
  'LoginValidation',
  'AuthState',
  'HomeState',
  'QuizState',
  'ReadingState',
  // Phase 9's two.
  'UserSettings',
  'SettingsState',
  // The 7 events with a field…
  'AuthEmailChanged',
  'AuthPasswordChanged',
  'HomeStarted',
  'HomeRetried',
  'QuizStarted',
  'QuizRetried',
  'QuizOptionSelected',
  // …and the 7 with none.
  'AuthStarted',
  'AuthPasswordVisibilityToggled',
  'AuthSubmitted',
  'AuthSignedOut',
  'HomeCleared',
  'QuizAnswerChecked',
  'QuizAdvanced',
  // And the 3 sealed bases. They carry no fields and are never instantiated, so
  // the only claim made about each is that `lib/` says freezed owns it — see the
  // group above. Listed so the count reconciles.
  'AuthEvent',
  'HomeEvent',
  'QuizEvent',
};

// --- builders ------------------------------------------------------------
//
// Every one takes its fields as parameters and returns a **new** object. None is
// `const`, so no call can be canonicalised against another — which is the whole
// reason these exist instead of `const` literals.

Verse _verse({
  int bookNumber = 43,
  int chapter = 3,
  int number = 1,
  String text = 'In the beginning',
  String? textClean,
}) => Verse(
  bookNumber: _int(bookNumber),
  chapter: _int(chapter),
  number: _int(number),
  text: _text(text),
  textClean: textClean == null ? null : _text(textClean),
);

ScriptureText _passage({
  String readingId = 'reading-1',
  int groupId = 3,
  String scheduledDate = '2026-10-04',
  ReadingLanguage? language,
  String reference = 'John 3:1-5',
  String translation = 'NKJV (New King James Version)',
  List<Verse>? verses,
  List<Question>? questions,
  bool isFullyCompleted = true,
  int pointsEarnedToday = 10,
  int currentStreak = 4,
}) => ScriptureText(
  readingId: _text(readingId),
  groupId: _int(groupId),
  scheduledDate: _text(scheduledDate),
  language: language ?? _language(),
  reference: _text(reference),
  translation: _text(translation),
  verses: verses ?? <Verse>[_verse()],
  questions: questions ?? <Question>[_question()],
  isFullyCompleted: _bool(isFullyCompleted),
  pointsEarnedToday: _int(pointsEarnedToday),
  currentStreak: _int(currentStreak),
);

TodayReading _today({
  String readingId = 'reading-1',
  int groupId = 3,
  String scheduledDate = '2026-10-04',
  ReadingLanguage? language,
  String reference = 'John 3:1-5',
  String translation = 'NKJV (New King James Version)',
  int verseCount = 5,
  String firstVerseText = 'In the beginning',
  int questionCount = 1,
  int answeredQuestionCount = 1,
  bool isFullyCompleted = true,
  int pointsEarnedToday = 10,
  int currentStreak = 4,
}) => TodayReading(
  readingId: _text(readingId),
  groupId: _int(groupId),
  scheduledDate: _text(scheduledDate),
  language: language ?? _language(),
  reference: _text(reference),
  translation: _text(translation),
  verseCount: _int(verseCount),
  firstVerseText: _text(firstVerseText),
  questionCount: _int(questionCount),
  answeredQuestionCount: _int(answeredQuestionCount),
  isFullyCompleted: _bool(isFullyCompleted),
  pointsEarnedToday: _int(pointsEarnedToday),
  currentStreak: _int(currentStreak),
);

Question _question({
  String id = 'question-1',
  int sortOrder = 1,
  String type = 'mcq',
  String prompt = 'Who is speaking?',
  Map<String, String>? options,
  int pointsValue = 10,
  bool alreadyAnswered = false,
  String? userAnswer,
  bool? isCorrect,
}) => Question(
  id: _text(id),
  sortOrder: _int(sortOrder),
  type: _text(type),
  prompt: _text(prompt),
  options:
      options ??
      <String, String>{
        _text('A'): _text('Nicodemus'),
        _text('B'): _text('John'),
      },
  pointsValue: _int(pointsValue),
  alreadyAnswered: _bool(alreadyAnswered),
  userAnswer: userAnswer == null ? null : _text(userAnswer),
  isCorrect: isCorrect == null ? null : _bool(isCorrect),
);

StreakSummary _streak({
  int currentStreak = 0,
  int longestStreak = 6,
  String lastCompletedDate = '2026-10-03',
  StreakTodayStatus todayStatus = StreakTodayStatus.pending,
  bool todayCompleted = false,
  bool todayScheduled = true,
  int nextMilestone = 3,
  int daysToMilestone = 3,
}) => StreakSummary(
  currentStreak: _int(currentStreak),
  longestStreak: _int(longestStreak),
  lastCompletedDate: _text(lastCompletedDate),
  todayStatus: todayStatus,
  todayCompleted: _bool(todayCompleted),
  todayScheduled: _bool(todayScheduled),
  nextMilestone: _int(nextMilestone),
  daysToMilestone: _int(daysToMilestone),
);

SubmitResult _submit({
  String questionId = 'question-1',
  bool isCorrect = true,
  int pointsEarned = 10,
  int currentTotalPoints = 40,
  int currentStreak = 0,
  int longestStreak = 6,
  bool readingCompleted = true,
}) => SubmitResult(
  questionId: _text(questionId),
  isCorrect: _bool(isCorrect),
  pointsEarned: _int(pointsEarned),
  currentTotalPoints: _int(currentTotalPoints),
  currentStreak: _int(currentStreak),
  longestStreak: _int(longestStreak),
  readingCompleted: _bool(readingCompleted),
);

AuthSession _session({
  String? userId,
  String email = 'reader@example.com',
  String displayName = 'David Mina',
  String initials = 'DM',
  String role = 'kid',
  DateTime? createdAt,
}) => AuthSession(
  userId: _text(userId ?? _userId()),
  email: _text(email),
  displayName: _text(displayName),
  initials: _text(initials),
  role: _text(role),
  createdAt: createdAt ?? _firstInstant(),
);

QuizAnswer _answer({
  Question? question,
  String? selectedLetter,
  SubmitResult? verdict,
}) => QuizAnswer(
  question: question ?? _question(),
  selectedLetter: selectedLetter == null ? null : _text(selectedLetter),
  verdict: verdict,
);

QuizSession _session_({
  String readingId = 'reading-1',
  List<QuizAnswer>? answers,
}) => QuizSession(
  readingId: _text(readingId),
  answers: answers ?? <QuizAnswer>[_answer()],
);

RefreshedQuestions _refreshed({
  String readingId = 'reading-1',
  List<Question>? questions,
}) => RefreshedQuestions(
  readingId: _text(readingId),
  questions: questions ?? <Question>[_question()],
);

SubmitAnswerParams _params({
  String readingId = 'reading-1',
  String questionId = 'question-1',
  String answer = 'A',
}) => SubmitAnswerParams(
  readingId: _text(readingId),
  questionId: _text(questionId),
  answer: _text(answer),
);

LoginCredentials _credentials({
  String email = 'reader@example.com',
  String password = 'correct-horse-battery-staple',
}) => LoginCredentials(email: _text(email), password: _text(password));

LoginValidation _valid() => LoginValidation(
  // Both reached through a call, which keeps this out of constant-folded
  // territory: a `const LoginValidation(emailError: null, passwordError: null)`
  // would be canonicalised and the pair above would be `identical`. That is this
  // file's whole subject, applied to its own fixtures.
  emailError: _absent(),
  passwordError: _absent(),
);

LoginValidation _invalid() => LoginValidation(
  emailError: _text(_requiredMessage()),
  passwordError: _text(_shortMessage()),
);

AuthState _authState({
  AuthSessionStatus status = AuthSessionStatus.signedOut,
  String email = 'reader@example.com',
  String password = 'correct-horse-battery-staple',
  bool isPasswordVisible = false,
  bool emailTouched = false,
  bool passwordTouched = false,
  AuthSession? session,
}) => AuthState(
  status: status,
  email: _text(email),
  password: _text(password),
  isPasswordVisible: _bool(isPasswordVisible),
  emailTouched: _bool(emailTouched),
  passwordTouched: _bool(passwordTouched),
  session: session,
);

HomeState _homeState({
  HomeSectionStatus readingStatus = HomeSectionStatus.ready,
  HomeSectionStatus streakStatus = HomeSectionStatus.ready,
  HomeSectionStatus readerStatus = HomeSectionStatus.ready,
  String? readerName,
  String? readerInitials,
  TodayReading? reading,
  StreakSummary? streak,
}) => HomeState(
  readingStatus: readingStatus,
  streakStatus: streakStatus,
  readerStatus: readerStatus,
  readerName: readerName == null ? null : _text(readerName),
  readerInitials: readerInitials == null ? null : _text(readerInitials),
  reading: reading,
  streak: streak,
);

QuizState _quizState({
  QuizStatus status = QuizStatus.ready,
  QuizSession? session,
  int currentIndex = 0,
  Failure? failure,
  SubmitResult? lastResult,
}) => QuizState(
  status: status,
  session: session,
  currentIndex: _int(currentIndex),
  failure: failure,
  lastResult: lastResult,
);

/// `ReadingState`'s builder, with **no** font step.
///
/// The parameter and the variant are gone because Phase 9 deleted the field: the
/// reader's step is `UserSettings.fontStep`, installed app-wide by `MaterialApp`,
/// and holding a second copy in cubit state is the "two sources of truth for one
/// fact" the class doc rejects. So `fields: 4` below is not a smaller sample — it is
/// the field count the class actually has, and `_differsInEveryField`'s exhaustive
/// check is what proved the fifth one is gone.
ReadingState _readingState({
  ReadingStatus status = ReadingStatus.ready,
  ScriptureText? scripture,
  Failure? failure,
  bool textSizePanelOpen = false,
}) => ReadingState(
  status: status,
  scripture: scripture,
  failure: failure,
  textSizePanelOpen: _bool(textSizePanelOpen),
);

UserSettings _userSettings({
  AppThemeMode themeMode = AppThemeMode.dark,
  int fontStep = kDefaultFontStep,
  ReadingLanguage? language,
  bool reducedMotion = false,
}) => UserSettings(
  themeMode: themeMode,
  fontStep: _int(fontStep),
  language: language,
  reducedMotion: _bool(reducedMotion),
);

SettingsState _settingsState({
  SettingsStatus status = SettingsStatus.ready,
  UserSettings? settings,
  Failure? failure,
}) => SettingsState(
  status: status,
  settings: settings ?? _userSettings(),
  failure: failure,
);

// --- values --------------------------------------------------------------

String _userId() => '11111111-1111-4111-8111-111111111111';

String _otherUserId() => '22222222-2222-4222-8222-222222222222';

DateTime _firstInstant() => DateTime.utc(2026, 10, 4);

DateTime _laterInstant() => DateTime.utc(2026, 10, 5);

/// A `Failure` for the three states that carry one.
///
/// `Failure` is **not** converted — it keeps hand-written equality on purpose
/// (§2.1 hazard 2) — so it is built here rather than varied field by field.
Failure _failure() => Failure(
  kind: FailureKind.server,
  message: _text('boom'),
  statusCode: _int(500),
);

String _requiredMessage() => 'This field is required';

String _shortMessage() => "That password's too short";

// --- the anti-canonicalisation helpers -----------------------------------
//
// Each returns its argument through a function call, so the value cannot be a
// compile-time constant and `prefer_const_constructors` stays quiet without an
// `// ignore:` — which this repository uses none of.

int _int(int value) => value;

String _text(String value) => value;

bool _bool(bool value) => value;

/// `null`, reached through a call so the class built with it is not a constant
/// expression and cannot be canonicalised against another.
String? _absent() => null;

ReadingLanguage _language() => ReadingLanguage.english;

ReadingLanguage _arabic() => ReadingLanguage.arabic;
