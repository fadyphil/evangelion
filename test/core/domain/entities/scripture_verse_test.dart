import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Verse`, `ScriptureText` and `verseDisplayText` — red-first (AGENT_CONTEXT §6:
/// "domain entities").
///
/// The load-bearing assertions here are the ones about **absence**: AGENT_CONTEXT
/// §5's trap 2 and trap 9 both say `text_clean` is *absent* rather than null in the
/// English payload, and Phase 7's own verify item is that the mapper keeps the two
/// apart. So `textClean` is `null` for an absent key and `''` for a present empty
/// one, and every test below is written to fail if those two collapse.
void main() {
  group('verseDisplayText — Phase 6\'s rule, in one place', () {
    test('prefers `text_clean` when it carries something', () {
      expect(
        verseDisplayText(text: 'كَانَ', textClean: 'كان'),
        'كان',
        reason: 'the Arabic arm carries text_clean and it is a preview string',
      );
    });

    test('falls back to `text` when `text_clean` is ABSENT', () {
      expect(
        verseDisplayText(text: 'There was a man', textClean: null),
        'There was a man',
      );
    });

    test('falls back to a NON-EMPTY `text` when `text_clean` is empty', () {
      // The neighbouring case, and the reason the field and the rule are separate:
      // `''` is present-but-empty and renders exactly like absence — but the
      // *field* still says which happened.
      expect(verseDisplayText(text: 'كَانَ', textClean: ''), 'كَانَ');
    });

    test('prefers an empty `text_clean` over an empty `text`', () {
      // Not a decision anybody asked for; it pins the order of the check, so a
      // rewrite that inverts it is visible.
      expect(verseDisplayText(text: '', textClean: 'x'), 'x');
      expect(verseDisplayText(text: '', textClean: ''), '');
      expect(verseDisplayText(text: '', textClean: null), '');
    });
  });

  group('Verse', () {
    const Verse arabic = Verse(
      bookNumber: 43,
      chapter: 3,
      number: 1,
      text: 'كَانَ إِنْسَانٌ',
      textClean: 'كان إنسان',
    );
    const Verse english = Verse(
      bookNumber: 43,
      chapter: 3,
      number: 1,
      text: 'There was a man of the Pharisees',
    );

    test('a verse with no `text_clean` has a null one, not an empty one', () {
      expect(english.textClean, isNull);
      expect(arabic.textClean, isNotNull);
    });

    test('`displayText` is the shared rule and differs per arm', () {
      expect(english.displayText, english.text);
      expect(arabic.displayText, arabic.textClean);
    });

    test('`book_number` is carried, and `reference` is never parsed against it', () {
      expect(english.bookNumber, 43);
      expect(
        english.chapter,
        3,
        reason:
            'so a caller could rebuild a title — and `ReadingPage` records why '
            'it does not',
      );
    });

    test('equality covers every field, so no two can be confused', () {
      expect(
        english,
        const Verse(
          bookNumber: 43,
          chapter: 3,
          number: 1,
          text: 'There was a man of the Pharisees',
        ),
      );
      expect(
        english.hashCode,
        const Verse(
          bookNumber: 43,
          chapter: 3,
          number: 1,
          text: 'There was a man of the Pharisees',
        ).hashCode,
      );
      for (final Verse other in <Verse>[
        english.copyWith(bookNumber: 44),
        english.copyWith(chapter: 4),
        english.copyWith(number: 2),
        english.copyWith(text: 'other'),
        arabic,
      ]) {
        expect(
          english,
          isNot(other),
          reason: '$other must differ from $english',
        );
      }
    });

    test('`copyWith` CANNOT clear `textClean`, and says so', () {
      // The nullable-field hazard `AuthState.copyWith` documents, reached from a
      // different direction. Asserted as behaviour rather than as a comment, because
      // a comment is what the hazard was written as once already.
      final Verse narrowed = arabic.copyWith(textClean: '');
      expect(narrowed.textClean, '', reason: 'an explicit empty is settable');
      expect(
        arabic.copyWith().textClean,
        'كان إنسان',
        reason: 'and omitting the argument keeps the current value',
      );
    });
  });

  group('ScriptureText — the counts and the narrowing', () {
    ScriptureText passage({List<Verse>? verses, List<Question>? questions}) =>
        ScriptureText(
          readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          groupId: 3,
          scheduledDate: '2026-10-03',
          language: ReadingLanguage.english,
          reference: 'John 3:1-5',
          translation: 'NKJV (New King James Version)',
          verses:
              verses ??
              const <Verse>[
                Verse(
                  bookNumber: 43,
                  chapter: 3,
                  number: 1,
                  text: 'There was a man of the Pharisees,',
                ),
                Verse(
                  bookNumber: 43,
                  chapter: 3,
                  number: 2,
                  text: 'The same came to Jesus by night,',
                ),
              ],
          questions:
              questions ??
              const <Question>[
                Question(
                  id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
                  sortOrder: 1,
                  type: 'mcq',
                  prompt: 'Who came to Jesus by night?',
                  options: <String, String>{'A': 'Nicodemus'},
                  pointsValue: 10,
                  alreadyAnswered: true,
                  userAnswer: 'A',
                  isCorrect: true,
                ),
                Question(
                  id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
                  sortOrder: 2,
                  type: 'mcq',
                  prompt: 'Second?',
                  options: <String, String>{'A': 'Yes'},
                  pointsValue: 10,
                  alreadyAnswered: false,
                ),
              ],
          isFullyCompleted: false,
          pointsEarnedToday: 10,
          currentStreak: 4,
        );

    test('counts the verses and the questions it actually holds', () {
      expect(passage().verseCount, 2);
      expect(passage().questionCount, 2);
      expect(passage().answeredQuestionCount, 1);
    });

    test('`firstVerseText` is the FIRST verse\'s `displayText`', () {
      expect(passage().firstVerseText, 'There was a man of the Pharisees,');
      // And through the AR arm it is `text_clean`, which is the whole reason the
      // rule is a function and not an inline `??`.
      expect(
        passage(
          verses: const <Verse>[
            Verse(
              bookNumber: 43,
              chapter: 3,
              number: 1,
              text: 'كَانَ',
              textClean: 'كان',
            ),
          ],
        ).firstVerseText,
        'كان',
      );
    });

    test(
      '`firstVerseText` is empty rather than a RangeError with no verses',
      () {
        // Decision 40, measured: `preview.substring(0, 1)` on an empty preview threw
        // out of a widget's `build` and took two controls to `/reading` and `/quiz`
        // with it. The mapper refuses an empty `verses` list, so this is unreachable
        // from the wire — and unreachable is not the same as total.
        expect(passage(verses: const <Verse>[]).firstVerseText, '');
      },
    );

    test('toTodayReading carries every scalar across verbatim', () {
      final ScriptureText source = passage();
      final TodayReading narrow = source.toTodayReading();

      expect(narrow.readingId, source.readingId);
      expect(narrow.groupId, source.groupId);
      expect(narrow.scheduledDate, source.scheduledDate);
      expect(narrow.language, source.language);
      expect(narrow.reference, source.reference);
      expect(narrow.translation, source.translation);
      expect(narrow.isFullyCompleted, source.isFullyCompleted);
      expect(narrow.pointsEarnedToday, source.pointsEarnedToday);
      expect(narrow.currentStreak, source.currentStreak);
      expect(narrow.verseCount, 2);
      expect(narrow.questionCount, 2);
      expect(narrow.answeredQuestionCount, 1);
    });

    test('the two streaks stay two, and narrowing changes neither', () {
      // Recorded decision 22: `readings/today` says `4`, `streak/summary` says `0`,
      // and no client line reconciles them. The narrowing is the one place a
      // reader could "helpfully" have picked a winner, so it is asserted not to.
      expect(passage().toTodayReading().currentStreak, 4);
    });

    test(
      'an empty passage narrows to an empty reading rather than throwing',
      () {
        final TodayReading narrow = passage(
          verses: const <Verse>[],
          questions: const <Question>[],
        ).toTodayReading();
        expect(narrow.verseCount, 0);
        expect(narrow.firstVerseText, '');
        expect(narrow.questionCount, 0);
      },
    );

    test('`copyWith` replaces the lists wholesale', () {
      final ScriptureText source = passage();
      expect(source.copyWith().verses, same(source.verses));
      expect(source.copyWith(verses: const <Verse>[]).verseCount, 0);
      expect(source.copyWith(questions: const <Question>[]).questionCount, 0);
    });

    test('equality covers every field', () {
      expect(passage(), passage());
      expect(passage().hashCode, passage().hashCode);
      for (final ScriptureText other in <ScriptureText>[
        passage().copyWith(readingId: 'other'),
        passage().copyWith(groupId: 4),
        passage().copyWith(scheduledDate: '2026-10-04'),
        passage().copyWith(language: ReadingLanguage.arabic),
        passage().copyWith(reference: 'John 3:1-6'),
        passage().copyWith(translation: 'other'),
        passage().copyWith(verses: const <Verse>[]),
        passage().copyWith(questions: const <Question>[]),
        passage().copyWith(isFullyCompleted: true),
        passage().copyWith(pointsEarnedToday: 0),
        passage().copyWith(currentStreak: 0),
      ]) {
        expect(passage(), isNot(other), reason: '$other must differ');
      }
    });
  });

  group('Question', () {
    const Question answered = Question(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      sortOrder: 1,
      type: 'mcq',
      prompt: 'Who came to Jesus by night?',
      options: <String, String>{'A': 'Nicodemus', 'B': 'Paul'},
      pointsValue: 10,
      alreadyAnswered: true,
      userAnswer: 'A',
      isCorrect: true,
    );
    const Question unanswered = Question(
      id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      sortOrder: 2,
      type: 'mcq',
      prompt: 'Second?',
      options: <String, String>{'A': 'Yes'},
      pointsValue: 10,
      alreadyAnswered: false,
    );

    test('the live answered shape carries BOTH the letter and the verdict', () {
      // Verified live against `HEAD = 4a1c834`: the reading response itself puts
      // `user_answer: 'A'` and `is_correct: true` inside the question. The entity
      // has to carry them or Phase 8 re-parses the body.
      expect(answered.userAnswer, 'A');
      expect(answered.isCorrect, isTrue);
      expect(answered.alreadyAnswered, isTrue);
    });

    test('the live unanswered shape carries NEITHER, and that is `null` not false', () {
      // §5's response shape shows `"is_correct": null` beside `"user_answer": null`.
      // "Not answered" and "answered wrongly" are different facts, and a `bool`
      // would have to invent one of them.
      expect(unanswered.userAnswer, isNull);
      expect(unanswered.isCorrect, isNull);
      expect(unanswered.alreadyAnswered, isFalse);
    });

    test('`type` is the wire string, unvalidated, and that is recorded', () {
      expect(answered.type, 'mcq');
      const Question other = Question(
        id: 'x',
        sortOrder: 1,
        type: 'free_text',
        prompt: 'p',
        options: <String, String>{},
        pointsValue: 0,
        alreadyAnswered: false,
      );
      expect(
        other.type,
        'free_text',
        reason:
            'an unknown type must construct, not fail the whole reading — '
            'Phase 8 owns the enumeration',
      );
    });

    test('equality covers every field, including the two nullable ones', () {
      expect(
        answered,
        const Question(
          id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
          sortOrder: 1,
          type: 'mcq',
          prompt: 'Who came to Jesus by night?',
          options: <String, String>{'A': 'Nicodemus', 'B': 'Paul'},
          pointsValue: 10,
          alreadyAnswered: true,
          userAnswer: 'A',
          isCorrect: true,
        ),
      );
      for (final Question other in <Question>[
        answered.copyWith(id: 'other'),
        answered.copyWith(sortOrder: 2),
        answered.copyWith(type: 'other'),
        answered.copyWith(prompt: 'other'),
        answered.copyWith(options: const <String, String>{}),
        answered.copyWith(pointsValue: 20),
        answered.copyWith(alreadyAnswered: false),
        unanswered,
      ]) {
        expect(answered, isNot(other), reason: '$other must differ');
      }
    });

    test(
      '`copyWith` cannot clear the nullable pair, and the doc admits it',
      () {
        expect(answered.copyWith(isCorrect: false).isCorrect, isFalse);
        expect(
          answered.copyWith(userAnswer: '').userAnswer,
          '',
          reason: 'an explicit empty is settable',
        );
        expect(answered.copyWith().userAnswer, 'A');
      },
    );
  });

  group('the failures a caller can hit', () {
    test(
      'a Question with a non-String option value cannot be built by mistake',
      () {
        // Not a runtime assertion — a compile-time one, expressed as documentation:
        // `options` is `Map<String, String>`, so the mapper is the only place that can
        // ever produce one, and it has to decide what a `Map<String, dynamic>` means.
        const Map<String, String> options = <String, String>{'A': 'x'};
        expect(
          () => const Question(
            id: 'x',
            sortOrder: 1,
            type: 'mcq',
            prompt: 'p',
            options: options,
            pointsValue: 0,
            alreadyAnswered: false,
          ),
          returnsNormally,
        );
        // And the failure vocabulary a mapper would use is already there, which is
        // what this assertion is really pinning: the entity never carries a Failure.
        expect(
          const Failure(kind: FailureKind.serialization, message: 'x').kind,
          FailureKind.serialization,
        );
      },
    );
  });
}
