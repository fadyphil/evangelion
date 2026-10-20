/// The quiz's verdict haptics — `eva/redesign.html:1428` and `:1429`.
///
/// ## WHAT THIS FILE PROVES, AND WHY IT IS NOT PART OF `quiz_page_test.dart`
///
/// `quiz_page_test.dart` is about the **screen**: the spoiler boundary, the
/// verdict's colour, the live region. The haptic is none of those — it is a
/// **platform call** that happens at one moment, and the moment is the only
/// thing worth asserting about it.
///
/// ## THE THREE CLAIMS, AND THEY FAIL DIFFERENTLY
///
/// * **the right answer is the firm bump and the wrong one is the buzz** —
///   `:1428`'s `haptic(30)` and `:1429`'s `haptic([40,60,40])`. A suite that
///   only checked "a haptic happened" would pass against a client that buzzed
///   for a right answer, and the reader is the only one who can tell the
///   difference.
/// * **it fires ONCE per check, not once per rebuild** — the prototype fires
///   inside `pick` (`:1423`'s one-shot). A `build`-time call would fire on
///   every frame, and the extra pumps below are what make that observable.
/// * **it fires ONCE, and only on a check** — the payload's `is_correct` is on
///   the wire from the first frame (§5 trap 10), so a client that graded on
///   the payload would buzz before the reader committed to anything.
///
/// ## AND THE READER'S OWN SWITCH IS **NOT** DECORATION
///
/// `UserSettings.haptics` is the Workshop's own switch (`:689`), and
/// `ritualHapticsEnabled` is the app's own answer for reading it without
/// registering a dependency — which is what a listener's callback needs.
/// The "off" arm is asserted here so the switch is a claim rather than a
/// comment.
library;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/contract_payloads.dart';
import '../../../../support/quiz_harness.dart';
import '../../../../support/settings_harness.dart';

/// The English strings, once, for the whole file.
final AppLocalizations en = AppLocalizationsEn();

/// The letter this suite taps.
///
/// **The reader's choice, not the payload's answer key** — `quiz_page_test.dart`
/// records why: the open payload carries no answer key, and a suite that took
/// the letter from the fixture would be reading the field it is trying to
/// prove is not read.
const String theAnsweredLetter = 'A';

void main() {
  /// The platform's haptic calls.
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
  });

  /// Records the platform's haptic calls for the duration of one test.
  ///
  /// **Only the haptics.** The platform channel also carries the app's own
  /// `SystemChrome` calls, and a recorder that kept those would be counting the
  /// framework's housekeeping rather than the quiz's.
  void recordPlatformCalls(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
  }

  /// Registers the reader's settings, so `ritualHapticsEnabled` has an answer.
  ///
  /// **The handle is what the locator publishes**, and the quiz reads the
  /// switch through it. A suite that never registered one would see "no
  /// haptics" for every test — which is the honest answer for a reader who has
  /// asked for nothing, and the reason the "on" arm has to install one.
  void installSettings({required bool haptics}) {
    settingsHarness(initial: UserSettings(haptics: haptics));
  }

  /// A bloc over the open English payload, answering with [submission].
  QuizBloc blocOver({Result<SubmitResult>? submission}) => quizBloc(
    const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
    submission: submission,
  );

  /// Taps the option and presses "Check answer".
  Future<void> checkTheAnswer(WidgetTester tester) async {
    await tester.tap(
      find.text(liveEnglishQuestion.options[theAnsweredLetter]!),
    );
    await pumpQuizFrames(tester, 2);
    await tester.tap(find.text(en.quizCheckAnswer));
    await pumpQuizFrames(tester, 6);
  }

  group('a correct answer', () {
    testWidgets('is the prototype\'s firm bump', (WidgetTester tester) async {
      installSettings(haptics: true);
      recordPlatformCalls(tester);
      final QuizBloc bloc = blocOver(
        submission: const Right<Failure, SubmitResult>(
          contractSubmitAnswerFixture,
        ),
      );
      await pumpQuiz(tester, bloc: bloc);

      await checkTheAnswer(tester);

      expect(calls, hasLength(1));
      // `:1428` — `haptic(30)`, and 30 ms is a medium impact under the
      // magnitude rule `core/domain/entities/ritual_haptic.dart` records.
      expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
    });
  });

  group('a wrong answer', () {
    testWidgets('is the prototype\'s buzz', (WidgetTester tester) async {
      installSettings(haptics: true);
      recordPlatformCalls(tester);
      final QuizBloc bloc = blocOver(
        submission: const Right<Failure, SubmitResult>(
          contractWrongAnswerFixture,
        ),
      );
      await pumpQuiz(tester, bloc: bloc);

      await checkTheAnswer(tester);

      expect(calls, hasLength(1));
      // `:1429` — `haptic([40,60,40])`, whose peak of 60 ms is a heavy impact.
      expect(calls.single.arguments, 'HapticFeedbackType.heavyImpact');
    });
  });

  group('the reader\'s own switch', () {
    testWidgets('keeps the verdict silent when haptics are off', (
      WidgetTester tester,
    ) async {
      installSettings(haptics: false);
      recordPlatformCalls(tester);
      final QuizBloc bloc = blocOver(
        submission: const Right<Failure, SubmitResult>(
          contractSubmitAnswerFixture,
        ),
      );
      await pumpQuiz(tester, bloc: bloc);

      await checkTheAnswer(tester);

      expect(calls, isEmpty);
    });
  });

  group('when it fires', () {
    testWidgets('not on the load, and not on the choice', (
      WidgetTester tester,
    ) async {
      installSettings(haptics: true);
      recordPlatformCalls(tester);
      final QuizBloc bloc = blocOver(
        submission: const Right<Failure, SubmitResult>(
          contractSubmitAnswerFixture,
        ),
      );
      await pumpQuiz(tester, bloc: bloc);

      // The load, and the choice: **neither is a check.** The payload carries
      // `is_correct` from the first frame (§5 trap 10), so a client that
      // graded on the payload would fire here.
      expect(calls, isEmpty);

      await tester.tap(
        find.text(liveEnglishQuestion.options[theAnsweredLetter]!),
      );
      await pumpQuizFrames(tester, 2);

      expect(calls, isEmpty);
    });

    testWidgets('once, and not again on every rebuild', (
      WidgetTester tester,
    ) async {
      installSettings(haptics: true);
      recordPlatformCalls(tester);
      final QuizBloc bloc = blocOver(
        submission: const Right<Failure, SubmitResult>(
          contractSubmitAnswerFixture,
        ),
      );
      await pumpQuiz(tester, bloc: bloc);

      await checkTheAnswer(tester);
      expect(calls, hasLength(1));

      // ## AND THE REBUILD IS **FORCED**, NOT HOPED FOR
      //
      // Pumping more frames is not a rebuild: the bloc has not emitted and
      // nothing has changed, so `_QuizBody.build` does not run and a
      // `build`-time call would not have fired again. **Pumping the tree
      // again is** — `pumpQuiz` builds a fresh widget tree over the *same*
      // bloc, and every element on the way down is updated with a new widget
      // instance, so `QuizPage.build` runs and so does `_QuizBody.build`.
      //
      // That is the mutation this arm exists for: a haptic fired from `build`
      // rather than from the verdict's arrival would add one call here, and
      // the count is the only thing that can tell the two apart.
      await pumpQuiz(tester, bloc: bloc);

      expect(calls, hasLength(1));
    });
  });
}
