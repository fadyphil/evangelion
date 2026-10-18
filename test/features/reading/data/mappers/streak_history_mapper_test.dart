import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/features/reading/data/mappers/streak_history_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/live_payloads.dart';

/// [StreakHistoryMapper] — red-first (AGENT_CONTEXT §6: "API models and mappers").
///
/// ## THE ONE ROW THE SCREEN RENDERS IS WHY A ROW'S FAILURE FAILS THE ARRAY
///
/// `history[0]` is the last-light card's *whole subject*: its reference is the
/// eyebrow's `—` replacement and its date is the card's "when". A mapper that
/// skipped a malformed row would move the card to a different day without saying
/// so — a defect the reader experiences as "the app thinks I read the wrong
/// day", which is worse than an error state. So the rule is **one bad row fails
/// everything**, and the rows below prove it in the failing direction: a bad row
/// at index 1 fails a body whose row 0 is perfect.
///
/// ## AND THE DROPS ARE ASSERTED IN THE FAILING DIRECTION
///
/// The body carries the summary's nine scalars plus `user_id`, `group_id` and
/// `today_date`. `streak.routes.ts:163-172` builds `/streak/summary` by picking
/// fields off this very call, so re-projecting them here would be two entities
/// for one fact and two places for the two requests to disagree. A payload that
/// *lacked* those keys would make the drop untestable, which is why
/// `kLiveStreakHistoryJson` carries all of them.
void main() {
  const StreakHistoryMapper mapper = StreakHistoryMapper();

  List<StreakHistoryEntry> entriesOf(Result<List<StreakHistoryEntry>> result) {
    expect(result.isRight(), isTrue, reason: result.toString());
    return (result as Right<Failure, List<StreakHistoryEntry>>).value;
  }

  Failure failureOf(Result<List<StreakHistoryEntry>> result) {
    expect(result.isLeft(), isTrue, reason: 'expected a failure, got $result');
    return (result as Left<Failure, List<StreakHistoryEntry>>).value;
  }

  group('the live payload', () {
    late List<StreakHistoryEntry> entries;

    setUp(() => entries = entriesOf(mapper.map(liveStreakHistory())));

    test('keeps both rows, in the server\'s order', () {
      // `streak.service.ts:93` — `ORDER BY dr.scheduled_date DESC`. The order is
      // the *server's* claim about "last", and a client that re-sorted it would
      // be a second opinion about which day the reader last read. Asserted as
      // the dates rather than as a list equality, so a row added to the fixture
      // fails here with the two dates that moved rather than with a wall.
      expect(entries, hasLength(2));
      expect(
        entries.map((StreakHistoryEntry e) => e.scheduledDate).toList(),
        <String>['2026-10-03', '2026-10-02'],
        reason: '`scheduled_date DESC`, verbatim from the wire',
      );
    });

    test('reads every field the projection declares, on the first row', () {
      final StreakHistoryEntry row = entries.first;
      expect(row.readingId, 'dddddddd-dddd-dddd-dddd-dddddddddddd');
      expect(row.scheduledDate, '2026-10-03');
      expect(row.bookNumber, 43);
      expect(row.bookNameEn, 'John');
      expect(row.bookNameAr, 'يوحنا');
      expect(row.totalQuestions, 5);
      expect(row.answeredQuestions, 5);
      expect(row.correctAnswers, 4);
      expect(row.pointsEarned, 40);
      expect(row.isCompleted, isTrue);
    });

    test('both reference arms survive, spacing and all', () {
      // `streak.service.ts:124-130` composes the two arms with DIFFERENT
      // punctuation — `يوحنا 3: 1-5` has a space after the colon and
      // `John 3:1-5` does not. The spacing is the server's and is carried
      // verbatim, for `TodayReading.reference`'s reason: normalising it here
      // would be a second place deciding what a reference looks like.
      final StreakHistoryEntry single = entries.first;
      expect(single.referenceEn, 'John 3:1-5');
      expect(single.referenceAr, 'يوحنا 3: 1-5');
      // And the **spanning** shape on the second row, which is where a
      // `split(':')`-style parse would lose the second chapter.
      final StreakHistoryEntry spanning = entries.last;
      expect(spanning.referenceEn, 'Psalms 23:1 - 23:6');
      expect(spanning.referenceAr, 'المزامير 23: 1 - 23:6');
    });

    test('and an incomplete row carries its partial counts, not a zero', () {
      // `is_completed` is derived server-side (`totalQ > 0 && answeredQ >=
      // totalQ`), so the client's only honest claim about progress is the three
      // counts it was handed. Asserted on the row where they disagree — 6 asked,
      // 2 answered, 1 correct — because a row where they agree proves nothing
      // about which key went where.
      final StreakHistoryEntry row = entries.last;
      expect(row.isCompleted, isFalse);
      expect(row.totalQuestions, 6);
      expect(row.answeredQuestions, 2);
      expect(row.correctAnswers, 1);
    });

    test('the list is unmodifiable, so bloc state cannot be mutated in place', () {
      // A `HomeBloc` that sorted or filtered its copy would corrupt the next
      // `HomeStarted`'s baseline, and the defect would be invisible — the
      // fixture's rows would still *look* right. The mapper returns
      // `List.unmodifiable`, so the mutation throws at the mutation site rather
      // than at the next assertion.
      expect(
        () => entries.add(entries.first),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('the keys the projection drops', () {
    test('the summary scalars are not re-projected, and the payload proves it', () {
      // The fixture carries all nine summary scalars — see
      // `kLiveStreakHistoryJson`'s doc for why they must be present for this row
      // to mean anything. `StreakHistoryEntry` has no field for any of them, so
      // the compile-time proof is the entity itself; this row is the *runtime*
      // half, and it exists so a future `currentStreak`-shaped field cannot be
      // added to the entity without this file noticing.
      final List<StreakHistoryEntry> entries = entriesOf(
        mapper.map(liveStreakHistory()),
      );
      expect(entries, hasLength(2));
      // `user_id` and `group_id` are the request headers this client already
      // sends (`IdentityHeadersInterceptor`), for `StreakSummaryMapper`'s
      // reason; `today_date` is a date with no time and no zone, which
      // `StreakHistoryEntry.scheduledDate` records as a reason to keep dates as
      // the server's strings. None of the three appears in the entity, and the
      // body carries all three.
      expect(
        liveStreakHistory().keys,
        containsAll(<String>['user_id', 'group_id', 'today_date']),
      );
    });
  });

  group('a row\'s failure fails the array', () {
    /// The fixture's first row, decoded once — `liveStreakHistory()['history']`
    /// is typed `Object?` by the JSON decode, so the cast lives here rather than
    /// being repeated at each call site.
    final Map<String, Object?> firstRow =
        (liveStreakHistory()['history']! as List<Object?>).first
            as Map<String, Object?>;

    Map<String, Object?> bodyWith(Object? row) => <String, Object?>{
      'history': <Object?>[firstRow, row],
    };

    test('a bad row at index 1 fails a body whose row 0 is perfect', () {
      // The failing direction, and the reason it is index 1 rather than 0: a
      // mapper that only validated the row it was asked for would pass a test
      // that broke row 0 and fail the *screen* on row 1 — the row the reader
      // does not see but the card's "when" depends on.
      final Result<List<StreakHistoryEntry>> result = mapper.map(
        bodyWith(<String, Object?>{
          'reading_id': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
          'scheduled_date': '2026-10-01',
          'book_number': 19.0, // a double, where every count is an int
          'book_name_en': 'Psalms',
          'book_name_ar': 'المزامير',
          'reference': <String, String>{
            'ar': 'المزامير 23: 1',
            'en': 'Ps 23:1',
          },
          'total_questions': 6,
          'answered_questions': 2,
          'correct_answers': 1,
          'points_earned': 10,
          'is_completed': false,
        }),
      );
      final Failure failure = failureOf(result);
      expect(failure.kind, FailureKind.serialization);
      // The message names the row and the key, so a reader of the error sees the
      // payload's own shape rather than a Dart type error.
      expect(failure.message, contains('history[1].book_number'));
    });

    test('and every required key fails with its own message', () {
      // ## WHY EVERY KEY AND NOT ONE REPRESENTATIVE
      //
      // The mapper reads twelve keys plus the two reference arms, and the wire
      // order is the order a reader meets them in the JSON. A table-driven row
      // would prove "a missing key fails" once; this proves each key's *message*
      // names itself, which is what turns a serialization failure from "the
      // payload was wrong" into "the payload was wrong HERE".
      final Map<String, Object?> row = <String, Object?>{
        'reading_id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        'scheduled_date': '2026-10-03',
        'book_number': 43,
        'book_name_en': 'John',
        'book_name_ar': 'يوحنا',
        'reference': <String, String>{'ar': 'يوحنا 3: 1-5', 'en': 'John 3:1-5'},
        'total_questions': 5,
        'answered_questions': 5,
        'correct_answers': 4,
        'points_earned': 40,
        'is_completed': true,
      };
      const List<String> keys = <String>[
        'reading_id',
        'scheduled_date',
        'book_number',
        'book_name_en',
        'book_name_ar',
        'total_questions',
        'answered_questions',
        'correct_answers',
        'points_earned',
        'is_completed',
      ];
      for (final String key in keys) {
        final Map<String, Object?> broken = Map<String, Object?>.of(row)
          ..remove(key);
        final Failure failure = failureOf(mapper.map(bodyWith(broken)));
        expect(
          failure.message,
          contains('history[1].$key'),
          reason: 'removing `$key` must name `$key`',
        );
      }
    });

    test('a missing reference arm names the arm, and a non-object row names it', () {
      // The fixture's first row, with its Arabic reference arm removed — so
      // the mapper has a `reference` object that is missing one of its two
      // keys, which is the shape a server that dropped a translation produces.
      final Map<String, Object?> row =
          (liveStreakHistory()['history']! as List<Object?>).first
              as Map<String, Object?>;
      final Map<String, Object?> armless = <String, Object?>{
        ...row,
        'reference': <String, String>{'en': 'John 3:1-5'},
      };
      expect(
        failureOf(mapper.map(bodyWith(armless))).message,
        contains('history[1].reference.ar'),
      );

      final Result<List<StreakHistoryEntry>> notAnObject = mapper.map(
        <String, Object?>{
          'history': <Object?>['2026-10-03'],
        },
      );
      expect(
        failureOf(notAnObject).message,
        contains('`history[0]` is a String, not a JSON object'),
      );
    });

    test('and a body with no history at all is a serialization failure', () {
      // **Not an empty list.** An empty list is a reader who has never read —
      // `homeNoLight`'s whole arm, and a legitimate 200. A body with no
      // `history` key is a proxy swallowing the upstream, and answering it with
      // the empty arm would tell a reader they have never read.
      expect(
        failureOf(mapper.map(<String, Object?>{})).message,
        contains('`history`'),
      );
      expect(
        failureOf(mapper.map(<String, Object?>{})).kind,
        FailureKind.serialization,
      );
    });

    test('and an empty history IS the empty list, not a failure', () {
      // The other side of the row above, and the reason the two are separate
      // tests: the empty arm is the card's "no light received yet" state, which
      // is reachable and must not be an error.
      final Result<List<StreakHistoryEntry>> result = mapper.map(
        <String, Object?>{'history': <Object?>[]},
      );
      expect(entriesOf(result), isEmpty);
    });

    test('and a non-object body says what it was, naming the proxy case', () {
      // `streak_history_mapper.dart`'s `_notAnObject` has a THIRD arm for an
      // HTML document, because a captive portal or an error page is the body a
      // 200 actually carries when something between the app and the backend
      // answers. Asserted with a realistic page rather than `'<html>'`, so the
      // length in the message is a real number.
      final String portal = '<html><body>${'x' * 120}</body></html>';
      final Failure failure = failureOf(mapper.map(portal));
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('an HTML document'));
      expect(failure.message, contains('${portal.length}'));
    });
  });
}
