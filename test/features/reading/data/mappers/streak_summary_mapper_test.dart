import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/live_payloads.dart';

/// [StreakSummaryMapper] — red-first (AGENT_CONTEXT §6: "API models and mappers").
///
/// ## THE TWO KEYS THIS PAYLOAD HAS AND THIS PROJECTION DOES NOT CARRY
///
/// The live body also carries `user_id` and `group_id`. Both are **deliberately
/// dropped**, and the test says so in the failing direction — because
/// `AGENT_CONTEXT` §3's placement rule pushes the other way for an entity that
/// two features consume, and "we forgot" and "we decided" look identical in a
/// diff.
///
/// The reason is that both are already known: `X-User-Id` and `X-Group-Id` are
/// **request headers** the client sends (`IdentityHeadersInterceptor`), so a
/// response echoing them back adds nothing this app can act on. Carrying them
/// would also put the header constants and the response body in an equality
/// contract, so a server that normalised its echo would look like a different
/// streak to bloc state.
void main() {
  const StreakSummaryMapper mapper = StreakSummaryMapper();

  StreakSummary entityOf(Result<StreakSummary> result) {
    expect(result.isSuccess, isTrue, reason: result.toString());
    return (result as Success<StreakSummary>).value;
  }

  Failure failureOf(Result<StreakSummary> result) {
    expect(result.isFailure, isTrue, reason: 'expected a failure, got $result');
    return (result as FailureResult<StreakSummary>).failure;
  }

  group('the live payload', () {
    late StreakSummary summary;

    setUp(() => summary = entityOf(mapper.map(liveStreakSummary())));

    test('reads every field the projection declares, verbatim', () {
      // These are the numbers AGENT_CONTEXT §5 now records as an observed
      // inconsistency. `currentStreak: 0` here and `4` on
      // `GET /readings/today/en`, same user, same group, same day.
      expect(summary.currentStreak, 0);
      expect(summary.longestStreak, 6);
      expect(summary.lastCompletedDate, '2026-09-29');
      expect(summary.todayStatus, StreakTodayStatus.pending);
      expect(summary.todayCompleted, isFalse);
      expect(summary.todayScheduled, isTrue);
      expect(summary.nextMilestone, 3);
      expect(summary.daysToMilestone, 3);
    });

    test('`last_completed_date` stays the wire string, never a DateTime', () {
      // See `StreakSummary.lastCompletedDate`. `DateTime.parse` on `YYYY-MM-DD`
      // yields *local* midnight, which is a different calendar day for a reader
      // far from UTC, in exchange for nothing.
      expect(summary.lastCompletedDate, isA<String>());
    });
  });

  group('the keys the projection drops', () {
    test('a body with no `user_id` still maps', () {
      // Named because it is a decision, not an oversight: both are request
      // headers this client already sends, so a response that omits them changes
      // nothing about the streak.
      expect(
        entityOf(mapper.map(withoutKey(liveStreakSummary(), 'user_id'))),
        entityOf(mapper.map(liveStreakSummary())),
      );
    });

    test('and a body with no `group_id` still maps', () {
      expect(
        entityOf(mapper.map(withoutKey(liveStreakSummary(), 'group_id'))),
        entityOf(mapper.map(liveStreakSummary())),
      );
    });

    test('and a different `user_id` in the body changes nothing', () {
      // The echo is not evidence. If it were carried, a server that normalised
      // the casing of a UUID would look like a different streak to bloc state.
      expect(
        entityOf(
          mapper.map(withKey(liveStreakSummary(), 'user_id', 'not-a-uuid')),
        ),
        entityOf(mapper.map(liveStreakSummary())),
      );
    });
  });

  group('`today_status`', () {
    test('reads all four values the wire has', () {
      const Map<String, StreakTodayStatus> table = <String, StreakTodayStatus>{
        'completed': StreakTodayStatus.completed,
        'pending': StreakTodayStatus.pending,
        'off_day': StreakTodayStatus.offDay,
        'broken': StreakTodayStatus.broken,
      };
      for (final MapEntry<String, StreakTodayStatus> entry in table.entries) {
        expect(
          entityOf(
            mapper.map(withKey(liveStreakSummary(), 'today_status', entry.key)),
          ).todayStatus,
          entry.value,
          reason: 'wire value ${entry.key}',
        );
      }
    });

    test('rejects a fifth value rather than defaulting it', () {
      // `FailureKind.serialization` is the honest answer to a 2xx this client
      // cannot read. Defaulting to `pending` would report *nothing done today*
      // for a server that said something we do not understand, and Phase 8's
      // streak pill would then draw a claim rather than an error.
      final Failure failure = failureOf(
        mapper.map(withKey(liveStreakSummary(), 'today_status', 'off-day')),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('today_status'));
    });
  });

  group('every required key', () {
    const Map<String, String> types = <String, String>{
      'current_streak': 'int',
      'longest_streak': 'int',
      'last_completed_date': 'String',
      'today_status': 'String',
      'today_completed': 'bool',
      'today_scheduled': 'bool',
      'next_milestone': 'int',
      'days_to_milestone': 'int',
    };

    for (final String key in types.keys) {
      test('a body without `$key` is a serialization failure', () {
        final Failure failure = failureOf(
          mapper.map(withoutKey(liveStreakSummary(), key)),
        );
        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains(key));
      });
    }
  });

  group('wrong types are refused, not coerced', () {
    test('a numeric field arriving as a String', () {
      expect(
        failureOf(
          mapper.map(withKey(liveStreakSummary(), 'current_streak', '0')),
        ).kind,
        FailureKind.serialization,
      );
    });

    test('a boolean field arriving as an int', () {
      // `0` / `1` for `today_completed` is the shape a JSON encoder that was
      // told the wrong type would produce, and accepting it would make a server
      // bug invisible.
      expect(
        failureOf(
          mapper.map(withKey(liveStreakSummary(), 'today_completed', 0)),
        ).kind,
        FailureKind.serialization,
      );
    });

    test('an int field arriving as a double', () {
      // JSON `5.0` decodes to a Dart `double`. It is the same number and a
      // different *type*, and the projection's fields are all counts — so this
      // is refused rather than truncated, and the message says so.
      expect(
        failureOf(
          mapper.map(withKey(liveStreakSummary(), 'longest_streak', 6.0)),
        ).kind,
        FailureKind.serialization,
      );
    });

    test('and the message names the key, so a reader knows which one', () {
      expect(
        failureOf(
          mapper.map(withKey(liveStreakSummary(), 'next_milestone', null)),
        ).message,
        contains('next_milestone'),
      );
    });
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
  });

  group('the mapper itself', () {
    test('is `const`', () {
      expect(const StreakSummaryMapper(), same(const StreakSummaryMapper()));
    });

    test('maps the same body to equal entities', () {
      expect(mapper.map(liveStreakSummary()), mapper.map(liveStreakSummary()));
    });
  });
}
