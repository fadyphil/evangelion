import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/live_payloads.dart';

/// [TodayReadingMapper] — red-first (AGENT_CONTEXT §6: "API models and mappers").
///
/// ## WHY THE MAPPER OWNS THE FAILURE, RATHER THAN THE REPOSITORY
///
/// A `Result` is returned rather than an entity or a thrown exception, because
/// §3's LSP row says a repository **never throws** and **always returns a
/// `Result`** — and "the response arrived with a 200 and its body cannot be read"
/// is a failure the repository has to produce. `failure.dart` already has the
/// vocabulary for it: `FailureKind.serialization`, "a 2xx response body could not
/// be parsed into a domain entity". Making the mapper report it keeps the
/// repository's body to two arms (`DioException` → mapper; body → mapper) instead
/// of three, and puts the shape knowledge next to the field that is malformed.
///
/// ## AND WHY THERE IS NO INTERMEDIATE MODEL CLASS
///
/// `08-build-phases.md` §Phase 7 asks for "the remote data source and its
/// mapper". A separate `TodayReadingModel` would hold the raw `verses` array and
/// `questions` array and add a second declaration of the payload for a reader to
/// keep in step, in exchange for nothing: this projection reads six top-level
/// scalars, one list's length, one list's first element, and a count. The
/// `ApiErrorMapper` precedent is one `const` class per direction, and that is the
/// shape used.
void main() {
  const TodayReadingMapper mapper = TodayReadingMapper();

  /// The success value, or a failure whose message names [body]'s problem.
  TodayReading entityOf(Result<TodayReading> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: result.isFailure
          ? 'expected a success, got ${result.failureOrElse(const Failure(kind: FailureKind.unknown, message: '?'))}'
          : null,
    );
    return (result as Success<TodayReading>).value;
  }

  Failure failureOf(Result<TodayReading> result) {
    expect(result.isFailure, isTrue, reason: 'expected a failure, got $result');
    return (result as FailureResult<TodayReading>).failure;
  }

  group('the live English payload', () {
    late TodayReading reading;

    setUp(() => reading = entityOf(mapper.map(liveReadingEn())));

    test('reads every scalar the projection declares', () {
      expect(reading.readingId, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(reading.groupId, 3);
      expect(reading.scheduledDate, '2026-10-03');
      expect(reading.reference, 'John 3:1-5');
      // The parenthetical edition is kept. A reader choosing a reading wants to
      // know which translation, and dropping it would be a content decision.
      expect(reading.translation, 'NKJV (New King James Version)');
      expect(reading.pointsEarnedToday, 10);
      expect(reading.isFullyCompleted, isTrue);
      // The reading endpoint's **own** streak copy, which is `4` and disagrees
      // with `streak/summary`'s `0`. Carried, documented, and read by nothing.
      expect(reading.currentStreak, 4);
    });

    test('counts the verses rather than keeping them', () {
      expect(reading.verseCount, 5);
    });

    test('resolves the language through ReadingLanguage.fromCode', () {
      expect(reading.language, ReadingLanguage.english);
    });

    test('counts the questions and the answered ones', () {
      expect(reading.questionCount, 1);
      expect(reading.answeredQuestionCount, 1);
    });

    test('and takes the preview from `text`, because `text_clean` is ABSENT', () {
      // AGENT_CONTEXT §5, trap 2: the English localized response has no
      // `text_clean` key **at all**. Not null — absent. So the mapper cannot
      // ask for it and cannot distinguish "absent" from "present and empty"
      // unless it tests the key's presence, which is what it does.
      final Map<String, Object?> body = liveReadingEn();
      final List<Object?> verses = body['verses']! as List<Object?>;
      expect(
        (verses.first! as Map<String, Object?>).containsKey('text_clean'),
        isFalse,
        reason:
            'the fixture must reproduce the live ENGLISH shape. If this fails, '
            'the payload changed and the AR-only branch is no longer the only '
            'one that has to handle the key.',
      );

      expect(
        reading.firstVerseText,
        'There was a man of the Pharisees, named Nicodemus, a ruler of the '
        'Jews:',
      );
    });
  });

  group('the live Arabic payload', () {
    late TodayReading reading;

    setUp(() => reading = entityOf(mapper.map(liveReadingAr())));

    test('resolves to the Arabic arm', () {
      expect(reading.language, ReadingLanguage.arabic);
    });

    test('keeps the reference verbatim, spacing and all', () {
      // `يوحنا 3: 1-5` has a space after the colon and the English arm does not.
      // That difference is the server's, and normalising it would be the client
      // editing a citation.
      expect(reading.reference, 'يوحنا 3: 1-5');
      expect(reading.translation, 'Smith & Van Dyck (فانديك)');
    });

    test(
      'and prefers `text_clean` for the preview, because the key EXISTS',
      () {
        // The visible consequence, stated in `TodayReading.firstVerseText`: Arabic
        // shows a vowel-marked, diacritic-stripped-clean text and English shows the
        // bare one. That difference is the point of the branch.
        expect(
          reading.firstVerseText,
          'كان إنسان من الفريسيين اسمه نيقوديموس، رئيس',
        );
        expect(
          reading.firstVerseText.contains('كَانَ'),
          isFalse,
          reason: 'the vowel-marked `text` must not be what the preview shows',
        );
      },
    );

    test('and counts identically', () {
      expect(reading.verseCount, 5);
      expect(reading.questionCount, 1);
      expect(reading.answeredQuestionCount, 1);
    });
  });

  group('the counted fields', () {
    test('counts only `already_answered == true`', () {
      final TodayReading reading = entityOf(
        mapper.map(
          withQuestions(liveReadingEn(), <Map<String, Object?>>[
            aQuestion(alreadyAnswered: true),
            aQuestion(),
            aQuestion(alreadyAnswered: true),
            aQuestion(),
          ]),
        ),
      );

      expect(reading.questionCount, 4);
      expect(reading.answeredQuestionCount, 2);
    });

    test('treats a missing `already_answered` as not answered', () {
      // The key omitted entirely, which is a different thing from `false`. The
      // reading endpoint always sends it, so this arm is defensive — and it
      // resolves to "not answered", which is the reading a *missing* flag has to
      // have: a question the panel cannot prove is answered is one the reader
      // should still see as open.
      final TodayReading reading = entityOf(
        mapper.map(
          withQuestions(liveReadingEn(), <Map<String, Object?>>[
            aQuestion(alreadyAnswered: null),
          ]),
        ),
      );

      expect(reading.questionCount, 1);
      expect(reading.answeredQuestionCount, 0);
    });

    test('rejects a `questions` value that is not a list of objects', () {
      // Not silently zero. `questionCount` drives the bead row, and a row of zero
      // beads next to a button is the "silent gap" the panel's doc records; a
      // malformed list has to arrive as an error rather than as an empty reading.
      final Failure failure = failureOf(
        mapper.map(withKey(liveReadingEn(), 'questions', 'none')),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('questions'));
    });

    test(
      'and an empty question list is a valid reading with nothing to answer',
      () {
        // Distinct from a malformed one: zero questions is a real reading, and the
        // panel has a deliberate rendering for it (a line in place of the bead row)
        // rather than an error.
        final TodayReading reading = entityOf(
          mapper.map(withQuestions(liveReadingEn(), <Map<String, Object?>>[])),
        );

        expect(reading.questionCount, 0);
        expect(reading.answeredQuestionCount, 0);
      },
    );
  });

  group('the verses', () {
    test('rejects an empty `verses` list', () {
      // There is no preview to show, and an empty paragraph in the panel is worse
      // than an error a reader can retry.
      final Failure failure = failureOf(
        mapper.map(withVerses(liveReadingEn(), <Map<String, Object?>>[])),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('verses'));
    });

    test('rejects a first verse that is not an object', () {
      // A list holding a bare string — what a malformed response looks like.
      final Failure failure = failureOf(
        mapper.map(
          withKey(liveReadingEn(), 'verses', <Object?>['not an object']),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
    });

    test('rejects a first verse with no readable text', () {
      final Failure failure = failureOf(
        mapper.map(
          withVerses(liveReadingEn(), <Map<String, Object?>>[
            <String, Object?>{'book_number': 43, 'chapter': 3, 'verse': 1},
          ]),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('text'));
    });

    test('falls back to `text` when `text_clean` is present but empty', () {
      // The third shape of the same key: present, and carrying nothing. §5's
      // trap is that the key is *absent* in English; "present but empty" is a
      // different case and must not produce an empty preview.
      final TodayReading reading = entityOf(
        mapper.map(
          withVerses(liveReadingEn(), <Map<String, Object?>>[
            <String, Object?>{'text': 'bare', 'text_clean': ''},
          ]),
        ),
      );

      expect(reading.firstVerseText, 'bare');
    });

    test('and `text: \'\'` MAPS, deliberately — the widget is what is total', () {
      // ## THE OTHER HALF OF THE `''` DECISION, AND IT IS THE ONE THAT BIT
      //
      // `_preview`'s doc used to assert the opposite — "neither falls through to
      // `''`, because an empty preview renders an empty paragraph in the panel" — and
      // it did fall through. `previewText('')` is `''`, the panel's
      // `preview.substring(0, 1)` is a `RangeError` out of `build`, and because the
      // panel's two controls are that widget's own children the exception took
      // **`Continue` → `/reading` and `Start reflection` → `/quiz`** with it.
      //
      // So this test states the mapper's half — it maps, and `firstVerseText` is
      // `''` — and `home_page_test.dart`'s `an empty first verse still renders BOTH
      // controls` states the widget's half. **Neither half is enough alone**: a fix
      // on only one of them would leave the other untested, which is precisely how the
      // two halves drifted apart in the first place.
      //
      // ## AND WHY MAPPING IS THE RIGHT ANSWER RATHER THAN REFUSING
      //
      // The verse text is the one field a reader cannot be shown without; everything
      // else in this payload is a label *over* content. A payload missing its label
      // should cost the label, not the passage — refusing here would have turned one
      // cosmetic upstream defect into "the reader cannot open today's reading at
      // all", which is a strictly worse outcome than an empty paragraph and a
      // reachable `Continue`.
      final TodayReading reading = entityOf(
        mapper.map(
          withVerses(liveReadingEn(), <Map<String, Object?>>[
            <String, Object?>{'text': ''},
          ]),
        ),
      );

      expect(reading.firstVerseText, isEmpty);
      // The rest of the payload is unaffected: the reading is openable, which is the
      // whole claim, so its reference and bead count are asserted rather than assumed.
      expect(reading.reference, 'John 3:1-5');
      expect(reading.verseCount, 1);
      expect(reading.language, ReadingLanguage.english);
    });
  });

  group('the scalar policy: refused as impossible, or passed through', () {
    // The class doc's table, asserted. It was two unstated habits until the review
    // asked which scalars the mapper refuses and which it takes on trust, and the
    // honest answer turned out to be **one** refusal (`current_streak` negative)
    // against every other scalar — not "empty is refused", which is the rule a first
    // pass reaches for and which would have made `current_streak: 0` a failure on
    // every cold launch.

    test('a NEGATIVE current_streak is refused', () {
      // The one refusal that is not about a *missing* value. A streak counts days
      // completed, so `-5` has no reading, and `/` draws the number in the top bar
      // beside a sentence that says the streak is glowing or resting. `-5` there is
      // not a fact about the reader, and "the server said so" does not survive being
      // shown to one.
      final Failure failure = failureOf(
        mapper.map(withKey(liveReadingEn(), 'current_streak', -5)),
      );

      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('current_streak'));
      expect(
        failure.message,
        contains('0 or more'),
        reason: 'the message must say what was expected, not only that it was wrong',
      );
    });

    test('a streak of ZERO is not a failure, because it is the live value', () {
      // The counterweight, and the reason the rule is about *negatives* rather than
      // about `0`. §5's live payload is `current_streak: 0` on every cold launch; a
      // mapper that refused small numbers would refuse the ordinary case.
      expect(
        entityOf(mapper.map(withKey(liveReadingEn(), 'current_streak', 0)))
            .currentStreak,
        0,
      );
    });

    test('an empty `reference` is PASSED THROUGH, not refused', () {
      // `reference` is a heading *over* the passage. Refusing it would make today's
      // reading unreachable over a missing label — the same argument as `text: ''`,
      // and the two are deliberately consistent rather than one of each.
      final TodayReading reading = entityOf(
        mapper.map(withKey(liveReadingEn(), 'reference', '')),
      );

      expect(reading.reference, isEmpty);
      expect(reading.firstVerseText, isNotEmpty);
    });

    test('an empty `translation` is PASSED THROUGH', () {
      // An edition name, read by nothing on `/`. Phase 7's sanctuary is where an
      // edition belongs, and an absent one there is a missing label, not a broken
      // reading.
      expect(
        entityOf(mapper.map(withKey(liveReadingEn(), 'translation', '')))
            .translation,
        isEmpty,
      );
    });

    test('a very large positive streak is PASSED THROUGH', () {
      // No upper bound is invented, because this client has seen none and a bound
      // would be a claim about a payload it has not seen — the same argument the
      // class doc makes against *defaults*, applied symmetrically.
      //
      // What keeps that safe is layout rather than a rule, and
      // `home_page_test.dart`'s `a TWELVE-DIGIT streak overflows nothing` is the
      // witness: `AppTopBar` puts the wordmark in an `Expanded` with
      // `TextOverflow.ellipsis`, so the number is absorbed by truncating the
      // wordmark. **That claim is the reason this arm of the policy is defensible,
      // and it lives in the widget's suite because the widget is where it is true.**
      expect(
        entityOf(
          mapper.map(withKey(liveReadingEn(), 'current_streak', 999999999999)),
        ).currentStreak,
        999999999999,
      );
    });

    test('a negative POINTS total is passed through, unlike a negative streak', () {
      // The asymmetry is recorded rather than smoothed over, because smoothing it is
      // how the first version of this table ended up with two unstated habits.
      // `pointsEarnedToday` is rendered nowhere on `/`, so an impossible value there
      // is inert rather than loud, and refusing it would add a rule with no
      // reader-visible consequence. The streak is drawn beside a sentence that
      // describes it; points are drawn nowhere.
      expect(
        entityOf(
          mapper.map(
            withKey(liveReadingEn(), 'total_points_earned_today', -10),
          ),
        ).pointsEarnedToday,
        -10,
      );
    });
  });

  group('the language field', () {
    test('rejects a language this app does not ship', () {
      // The whole reason `ReadingLanguage.fromCode` returns nullable. Defaulting
      // would build an entity that claims to be English scripture and is not,
      // and every layer above it would behave correctly about a lie.
      final Failure failure = failureOf(
        mapper.map(withKey(liveReadingEn(), 'language', 'fr')),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('language'));
    });

    test('rejects a capitalised code, which is a different string', () {
      expect(
        failureOf(mapper.map(withKey(liveReadingEn(), 'language', 'EN'))).kind,
        FailureKind.serialization,
      );
    });
  });

  group('every other required key', () {
    // Walked rather than sampled: a mapper that read `group_id` with a default
    // would fail only that one case, and a suite that sampled would not notice.
    const Map<String, String> required = <String, String>{
      'reading_id': 'a String',
      'group_id': 'an int',
      'scheduled_date': 'a String',
      'reference': 'a String',
      'translation': 'a String',
      'is_fully_completed': 'a bool',
      'total_points_earned_today': 'an int',
      'current_streak': 'an int',
    };

    for (final String key in required.keys) {
      test('a body without `$key` is a serialization failure', () {
        final Failure failure = failureOf(
          mapper.map(withoutKey(liveReadingEn(), key)),
        );
        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains(key));
      });
    }
  });

  group('a body that is not an object', () {
    test('is a serialization failure, never an exception', () {
      for (final Object? body in <Object?>[null, 'a string', 42, <Object?>[]]) {
        expect(
          failureOf(mapper.map(body)).kind,
          FailureKind.serialization,
          reason: 'body was $body (${body.runtimeType})',
        );
      }
    });

    test('and the message names the body, not a Dart type', () {
      // A `TypeError` caught and reported would read `type 'Null' is not a
      // subtype of type 'Map<String, dynamic>'`, which tells a reader nothing
      // about what the server sent.
      final Failure failure = failureOf(mapper.map(null));
      expect(failure.message, isNot(contains('subtype')));
      expect(failure.message, isNot(contains('Null')));
    });
  });

  group('the mapper itself', () {
    test(
      'is `const`, so it registers as a singleton and allocates nothing',
      () {
        expect(const TodayReadingMapper(), same(const TodayReadingMapper()));
      },
    );

    test('maps the same body to equal entities', () {
      // A mapper that rebuilt a `DateTime` or an identity-holding object would
      // make two equal responses look like two different readings, and bloc state
      // would emit for nothing.
      expect(mapper.map(liveReadingEn()), mapper.map(liveReadingEn()));
    });
  });
}
