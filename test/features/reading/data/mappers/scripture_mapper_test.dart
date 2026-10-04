import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/live_payloads.dart';

/// `TodayReadingMapper.mapScripture` — red-first (AGENT_CONTEXT §6: "API models
/// and mappers").
///
/// ## WHAT IS **NEW** IN PHASE 7, AND WHAT IS PHASE 6'S CODE STILL
///
/// `map()` used to be the whole mapper. It is now `mapScripture()` followed by
/// `ScriptureText.toTodayReading()`, which is recorded decision 23's resolution
/// reached from the other end: **one** data source, **one** mapper, **one** set of
/// scalar rules, and the narrow projection became a read of the wide payload.
///
/// The consequence for this file is that every scalar refusal Phase 6 wrote is
/// now *also* the wide mapper's refusal — and `today_reading_mapper_test.dart`
/// still asserts all of them, unchanged. What this file adds is the part Phase 6
/// had no reason to have: `verses` as entities, `questions` as entities, and the
/// **`text_clean` absent-versus-empty** distinction that `08-build-phases.md`
/// §Phase 7 names as this phase's own verify item.
///
/// ## AND THE PAYLOAD IS NOT SYMMETRIC, WHICH IS THE POINT
///
/// The English verse keys are `[book_number, chapter, verse, text]` and the Arabic
/// ones are `[book_number, chapter, verse, text, text_clean]`. Both are frozen in
/// `test/support/live_payloads.dart` with the absence being a real absence, so the
/// AR-only branch cannot be satisfied by accident and the EN-only path cannot be
/// satisfied by spelling `null`.
void main() {
  const TodayReadingMapper mapper = TodayReadingMapper();

  ScriptureText scriptureOf(Result<ScriptureText> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: result.isFailure
          ? 'expected a success, got ${(result as FailureResult<ScriptureText>).failure}'
          : null,
    );
    return (result as Success<ScriptureText>).value;
  }

  TodayReading entityOf(Result<TodayReading> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: result.isFailure
          ? 'expected a success, got ${(result as FailureResult<TodayReading>).failure}'
          : null,
    );
    return (result as Success<TodayReading>).value;
  }

  Failure failureOf(Result<ScriptureText> result) {
    expect(result.isFailure, isTrue, reason: 'expected a failure, got $result');
    return (result as FailureResult<ScriptureText>).failure;
  }

  group('the live English payload, wide', () {
    late ScriptureText passage;

    setUp(() => passage = scriptureOf(mapper.mapScripture(liveReadingEn())));

    test('reads the same scalars the narrow projection read', () {
      expect(passage.readingId, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(passage.groupId, 3);
      expect(passage.scheduledDate, '2026-10-03');
      expect(passage.reference, 'John 3:1-5');
      expect(passage.translation, 'NKJV (New King James Version)');
      expect(passage.language, ReadingLanguage.english);
      expect(passage.isFullyCompleted, isTrue);
      expect(passage.pointsEarnedToday, 10);
      expect(passage.currentStreak, 4);
    });

    test('keeps every verse, with its numbers', () {
      expect(passage.verses, hasLength(5));
      expect(passage.verseCount, 5);
      expect(passage.verses.map((Verse verse) => verse.number), <int>[
        1,
        2,
        3,
        4,
        5,
      ], reason: 'the server\'s order and numbering, neither re-sorted');
      for (final Verse verse in passage.verses) {
        expect(verse.bookNumber, 43);
        expect(verse.chapter, 3);
      }
    });

    test('`text_clean` maps to null for ENGLISH, where the key is ABSENT', () {
      // ## THE VERIFY ITEM, `08-build-phases.md` §Phase 7.
      //
      // "a mapper test asserting `text_clean` maps to `null` for the English
      // payload, where the key is **absent** rather than empty (§5, trap 2)".
      //
      // The fixture assertion first: if the frozen EN payload ever grew the key,
      // every assertion below would be about a shape the server does not send.
      final Map<String, Object?> body = liveReadingEn();
      final List<Object?> raw = body['verses']! as List<Object?>;
      expect(
        (raw.first! as Map<String, Object?>).containsKey('text_clean'),
        isFalse,
        reason: 'the live English verse has NO text_clean key at all',
      );
      for (final Verse verse in passage.verses) {
        expect(verse.textClean, isNull, reason: 'verse ${verse.number}');
        expect(
          verse.displayText,
          verse.text,
          reason: 'and therefore displayText is the text',
        );
      }
    });

    test('the first verse is the live first verse, in full', () {
      expect(
        passage.verses.first.text,
        'There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:',
      );
    });

    test('keeps the question, with the answer the server shipped', () {
      // Verified live against `HEAD = 4a1c834`: `GET /readings/today/en` puts
      // `user_answer: 'A'` and `is_correct: true` inside the question object.
      expect(passage.questions, hasLength(1));
      final Question question = passage.questions.single;
      expect(question.id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
      expect(question.sortOrder, 1);
      expect(question.type, 'mcq');
      expect(
        question.prompt,
        'What was the name of the Pharisee who came to Jesus by night?',
      );
      expect(question.options, <String, String>{
        'A': 'Nicodemus',
        'B': 'Paul',
        'C': 'Peter',
        'D': 'Lazarus',
      });
      expect(question.pointsValue, 10);
      expect(question.alreadyAnswered, isTrue);
      expect(question.userAnswer, 'A');
      expect(question.isCorrect, isTrue);
    });

    test('and the counts agree with the narrow projection', () {
      expect(passage.questionCount, 1);
      expect(passage.answeredQuestionCount, 1);
    });
  });

  group('the live Arabic payload, wide', () {
    late ScriptureText passage;

    setUp(() => passage = scriptureOf(mapper.mapScripture(liveReadingAr())));

    test(
      '`text_clean` maps to the STRING for Arabic, where the key EXISTS',
      () {
        final Map<String, Object?> body = liveReadingAr();
        final List<Object?> raw = body['verses']! as List<Object?>;
        expect(
          (raw.first! as Map<String, Object?>).containsKey('text_clean'),
          isTrue,
          reason: 'the live Arabic verse DOES carry text_clean',
        );
        expect(passage.verses.first.textClean, isNotNull);
        expect(
          passage.verses.first.textClean,
          isNot(passage.verses.first.text),
          reason: 'the two differ — that is the whole of the branch',
        );
        for (final Verse verse in passage.verses) {
          expect(verse.textClean, isNotNull, reason: 'verse ${verse.number}');
        }
      },
    );

    test('`displayText` therefore differs from `text` on every verse', () {
      // The rule is `verseDisplayText`, one function, and it is the same one
      // `TodayReading.firstVerseText` reads. Both arms disagree with `text` here,
      // which is why the two must not be able to answer the question differently.
      for (final Verse verse in passage.verses) {
        expect(verse.displayText, verse.textClean);
      }
    });

    test('the reference keeps its space after the Arabic colon', () {
      expect(passage.reference, 'يوحنا 3: 1-5');
      expect(passage.translation, 'Smith & Van Dyck (فانديك)');
      expect(passage.language, ReadingLanguage.arabic);
    });

    test('the question keeps its Arabic prompt and options', () {
      final Question question = passage.questions.single;
      expect(question.prompt, 'ما اسم الفريسي الذي جاء إلى يسوع ليلاً؟');
      expect(question.options['A'], 'نيقوديموس');
      expect(question.userAnswer, 'A');
    });
  });

  group('`text_clean`: absent is not empty, and empty is not absent', () {
    Map<String, Object?> arabicWithClean(String? clean) =>
        withVerses(liveReadingAr(), <Map<String, Object?>>[
          <String, Object?>{
            'book_number': 43,
            'chapter': 3,
            'verse': 1,
            'text': 'كَانَ',
            if (clean case final String value) 'text_clean': value,
          },
          <String, Object?>{
            'book_number': 43,
            'chapter': 3,
            'verse': 2,
            'text': 'x',
          },
        ]);

    test('an ABSENT key is null', () {
      final Verse verse = scriptureOf(
        mapper.mapScripture(arabicWithClean(null)),
      ).verses.first;
      expect(verse.textClean, isNull);
    });

    test('a PRESENT-EMPTY key is the empty string, not null', () {
      // The distinction the whole nullable field exists for. Collapsing `''` to
      // `null` would erase the only evidence of *which* shape arrived, and the two
      // have different causes: a re-encoder that dropped the content, versus a
      // server that never had a clean text.
      final Verse verse = scriptureOf(mapper.mapScripture(arabicWithClean('')))
          .verses
          .first;
      expect(verse.textClean, '');
      expect(
        verse.textClean,
        isNotNull,
        reason: 'and this is the assertion a `clean?.isNotEmpty == true` write misses',
      );
      // The rendered string is the same either way, which is the honest outcome.
      expect(verse.displayText, 'كَانَ');
    });

    test('a `text_clean` this client cannot read as a String is null', () {
      // The same leniency `already_answered` gets, and stated for the same reason:
      // one object, one rule, so the two fields cannot disagree about how strict
      // this mapper is.
      final Verse verse = scriptureOf(
        mapper.mapScripture(
          withVerses(liveReadingAr(), <Map<String, Object?>>[
            <String, Object?>{
              'book_number': 43,
              'chapter': 3,
              'verse': 1,
              'text': 'كَانَ',
              'text_clean': 42,
            },
          ]),
        ),
      ).verses.first;
      expect(verse.textClean, isNull);
      expect(verse.displayText, 'كَانَ');
    });
  });

  group('the refusals Phase 6 wrote, unchanged', () {
    // Every row here is a Phase-6 rule that now lives in the wide mapper. They are
    // asserted through `mapScripture` because that is where the decision is made
    // now; `today_reading_mapper_test.dart` asserts the same bodies through `map`,
    // so a rule that is dropped fails in one file or the other.
    test('a body that is not an object', () {
      for (final Object? body in <Object?>[null, 'a string', 42, <Object?>[]]) {
        final Failure failure = failureOf(mapper.mapScripture(body));
        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains("Could not read today's reading"));
      }
    });

    test('a missing required scalar', () {
      final Failure failure = failureOf(
        mapper.mapScripture(withoutKey(liveReadingEn(), 'reading_id')),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('reading_id'));
    });

    test('a negative `current_streak`', () {
      final Failure failure = failureOf(
        mapper.mapScripture(withKey(liveReadingEn(), 'current_streak', -5)),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('current_streak'));
    });

    test('an unknown `language`', () {
      final Failure failure = failureOf(
        mapper.mapScripture(withKey(liveReadingEn(), 'language', 'fr')),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('language'));
    });

    test('an empty `verses` list', () {
      final Failure failure = failureOf(
        mapper.mapScripture(
          withVerses(liveReadingEn(), <Map<String, Object?>>[]),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('verses'));
    });

    test('a first verse that is not an object', () {
      final Failure failure = failureOf(
        mapper.mapScripture(
          withKey(liveReadingEn(), 'verses', <Object?>['not an object']),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('verses[0]'));
    });

    test('a first verse with no readable `text`', () {
      // **Strict**, while verses 2+ are lenient — and the asymmetry is the point of
      // the group below. Verse 1 opens the passage, feeds the preview, and is what
      // the drop cap hangs off; a passage whose opening cannot be read is a passage
      // this client cannot render honestly.
      final Failure failure = failureOf(
        mapper.mapScripture(
          withVerses(liveReadingEn(), <Map<String, Object?>>[
            <String, Object?>{'book_number': 43, 'chapter': 3, 'verse': 1},
          ]),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('verses[0].text'));
    });

    test('a `questions` value that is not a list', () {
      final Failure failure = failureOf(
        mapper.mapScripture(withKey(liveReadingEn(), 'questions', 'none')),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('questions'));
    });
  });

  group('the strictness asymmetry, and the skip that pays for it', () {
    test('a malformed verse AFTER the first is skipped, not fatal', () {
      final ScriptureText passage = scriptureOf(
        mapper.mapScripture(
          withVerses(liveReadingEn(), <Object>[
            <String, Object?>{
              'book_number': 43,
              'chapter': 3,
              'verse': 1,
              'text': 'first',
            },
            'not an object',
            <String, Object?>{
              'book_number': 43,
              'chapter': 3,
              'verse': 3,
              'text': 'third',
            },
            // No `book_number` — a second unreadable field on a verse after the
            // first, so the skip branch is reached for a reason that is not
            // "not an object" alone.
            <String, Object?>{'chapter': 3, 'verse': 4, 'text': 'fourth'},
          ]),
        ),
      );
      expect(
        passage.verses.map((Verse verse) => verse.number),
        <int>[1, 3],
        reason:
            'and the gap is VISIBLE — `Verse.number` is the server\'s, not a '
            'renumbering, so a reader sees that a verse is missing',
      );
      expect(passage.verseCount, 2);
    });

    test('a malformed QUESTION is skipped, because a quiz defect is not a passage', () {
      // Decision 40's argument, applied to the list Phase 6 only counted: the verse
      // text is the one field a reader cannot be shown without, and every other
      // field is a label *over* content. A malformed quiz payload costs a question,
      // not the scripture.
      final ScriptureText passage = scriptureOf(
        mapper.mapScripture(
          withQuestions(liveReadingEn(), <Object>[
            'not an object',
            <String, Object?>{'id': 'x', 'sort_order': 1, 'type': 'mcq'},
            aQuestion(alreadyAnswered: true),
          ]),
        ),
      );
      expect(passage.questions, hasLength(1));
      expect(passage.questionCount, 1);
      expect(passage.answeredQuestionCount, 1);
      expect(passage.verseCount, 5, reason: 'and the passage is untouched');
    });

    test('`questionCount` is the READABLE count, which is the cost, stated', () {
      // Phase 6 reported `questionCount: 4` for four unreadable questions, because
      // it had a count and no list. `ScriptureText` has a list, so the count is
      // `questions.length` and the four are gone. Every Phase-6 fixture that
      // exercises the leniency counts objects, so no Phase-6 assertion moved — and
      // the alternative, a wire count beside a readable list, is two sources for
      // one fact.
      final ScriptureText passage = scriptureOf(
        mapper.mapScripture(
          withQuestions(liveReadingEn(), <Object>[
            'not an object',
            'also not an object',
          ]),
        ),
      );
      expect(passage.questionCount, 0);
    });

    test('a question with a missing required field is skipped', () {
      final ScriptureText passage = scriptureOf(
        mapper.mapScripture(
          withQuestions(liveReadingEn(), <Map<String, Object?>>[
            <String, Object?>{
              'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
              'sort_order': 1,
              'type': 'mcq',
              'prompt': 'p',
              // `options` and `points_value` absent.
            },
          ]),
        ),
      );
      expect(passage.questions, isEmpty);
    });

    test('a question with a non-String option value is skipped', () {
      final ScriptureText passage = scriptureOf(
        mapper.mapScripture(
          withQuestions(liveReadingEn(), <Map<String, Object?>>[
            <String, Object?>{
              'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
              'sort_order': 1,
              'type': 'mcq',
              'prompt': 'p',
              'options': <String, Object?>{'A': 7},
              'points_value': 10,
              'already_answered': false,
            },
          ]),
        ),
      );
      expect(passage.questions, isEmpty);
    });
  });

  group('the lenient reads, which are the payload\'s own shapes', () {
    test('a missing `already_answered` counts as NOT answered', () {
      final ScriptureText passage = scriptureOf(
        mapper.mapScripture(
          withQuestions(liveReadingEn(), <Map<String, Object?>>[
            aQuestion(alreadyAnswered: null),
          ]),
        ),
      );
      expect(passage.questions.single.alreadyAnswered, isFalse);
      expect(passage.answeredQuestionCount, 0);
    });

    test(
      'a missing `user_answer` / `is_correct` are null, and so is a wrong type',
      () {
        final ScriptureText absent = scriptureOf(
          mapper.mapScripture(
            withQuestions(liveReadingEn(), <Map<String, Object?>>[aQuestion()]),
          ),
        );
        expect(absent.questions.single.userAnswer, isNull);
        expect(absent.questions.single.isCorrect, isNull);

        final ScriptureText wrongType = scriptureOf(
          mapper.mapScripture(
            withQuestions(liveReadingEn(), <Map<String, Object?>>[
              <String, Object?>{
                ...aQuestion(),
                'user_answer': 3,
                'is_correct': 'yes',
              },
            ]),
          ),
        );
        expect(wrongType.questions.single.userAnswer, isNull);
        expect(wrongType.questions.single.isCorrect, isNull);
      },
    );

    test('`is_correct: false` is false and is NOT the same as absent', () {
      // §5's shape has `null` beside `null`; "answered wrongly" and "not answered"
      // are different facts and a `bool?` is what keeps them apart.
      final ScriptureText passage = scriptureOf(
        mapper.mapScripture(
          withQuestions(liveReadingEn(), <Map<String, Object?>>[
            <String, Object?>{
              ...aQuestion(),
              'already_answered': true,
              'user_answer': 'B',
              'is_correct': false,
            },
          ]),
        ),
      );
      expect(passage.questions.single.isCorrect, isFalse);
      expect(passage.questions.single.isCorrect, isNotNull);
      expect(passage.questions.single.userAnswer, 'B');
    });
  });

  group('the relationship between the two entry points', () {
    test('`map` is `mapScripture` narrowed, for both live bodies', () {
      for (final Map<String, Object?> body in <Map<String, Object?>>[
        liveReadingEn(),
        liveReadingAr(),
      ]) {
        final ScriptureText wide = scriptureOf(mapper.mapScripture(body));
        final TodayReading narrow = entityOf(mapper.map(body));
        expect(narrow, wide.toTodayReading());
        // And the specific values Phase 6 pinned, so "the same answers" is not
        // merely "an equal-looking object".
        expect(narrow.verseCount, 5);
        expect(narrow.questionCount, 1);
        expect(narrow.answeredQuestionCount, 1);
      }
    });

    test('and a failure in the wide mapper is the failure `map` reports', () {
      // Otherwise `/` and `/reading` would disagree about whether a payload is
      // readable, which is the whole reason the narrow projection became a read of
      // the wide one rather than a second parse.
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        withoutKey(liveReadingEn(), 'verses'),
        withoutKey(liveReadingEn(), 'reading_id'),
        withKey(liveReadingEn(), 'current_streak', -5),
        withVerses(liveReadingEn(), <Map<String, Object?>>[]),
      ]) {
        final Failure wide = failureOf(mapper.mapScripture(broken));
        expect(mapper.map(broken).isFailure, isTrue);
        expect(mapper.map(broken).failureOrElse(wide), wide);
      }
    });
  });
}
