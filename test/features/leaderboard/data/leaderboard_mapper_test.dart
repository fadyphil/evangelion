import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Unwraps a [Result] that must have succeeded, with a message that says which
/// expectation failed rather than reporting a cast error three frames away.
T expectSuccess<T>(Result<T> result) {
  switch (result) {
    case Right<Failure, T>(:final T value):
      return value;
    case Left<Failure, T>(value: final failure):
      fail('expected a success, got ${failure.kind}: ${failure.message}');
  }
}

/// Unwraps a [Result] that must have failed.
Failure expectFailure<T>(Result<T> result) {
  switch (result) {
    case Left<Failure, T>(value: final failure):
      return failure;
    case Right<Failure, T>():
      fail('expected a failure, got a success');
  }
}

/// The limit every fixture below is read at, so the twenty-odd `mapper.map` calls do
/// not each carry it.
///
/// [LeaderboardMapper.cohortSizeOf] is the only thing that reads it, and 50 is the
/// server's own default for the querystring parameter — so a fixture read at 50 is "an
/// unspecified request". The one test about a binding cap passes its own.
const int kFixtureLimit = 50;

/// [LeaderboardMapper.map] at [kFixtureLimit], for the same reason.
Result<LeaderboardBoard> mapped(Object? body) =>
    const LeaderboardMapper().map(body, limit: kFixtureLimit);

void main() {
  /// The payload the live endpoint returns with nothing scored, copied from
  /// `GET /api/v1/leaderboard?window=weekly` with `X-Group-Id: 3`.
  const Map<String, Object?> emptyBoard = <String, Object?>{
    'group_id': 3,
    'window': 'weekly',
    'total_ranked': 0,
    'my_standing': null,
    'leaderboard': <Object?>[],
  };

  /// One populated row, with the **camelCase `userId`** the server really sends
  /// beside the snake_case keys — the inconsistency `LeaderboardMapper` documents.
  Map<String, Object?> row({
    Object? userId = '22222222-2222-2222-2222-222222222222',
    Object? score = 80,
    Object? rank = 1,
    Object? fullName = 'Peter George (Grade 6)',
    Object? currentStreak = 7,
  }) => <String, Object?>{
    'userId': userId,
    'score': score,
    'rank': rank,
    'full_name': fullName,
    'current_streak': currentStreak,
  };

  Map<String, Object?> board({
    Object? groupId = 3,
    Object? window = 'weekly',
    Object? totalRanked = 2,
    Object? myStanding,
    Object? rows,
  }) => <String, Object?>{
    'group_id': groupId,
    'window': window,
    'total_ranked': totalRanked,
    'my_standing': myStanding,
    'leaderboard':
        rows ??
        <Object?>[
          row(),
          row(rank: 2, score: 50, fullName: 'David Mina (Grade 5)'),
        ],
  };

  group('pathFor', () {
    test('is the endpoint with the window and limit the server expects', () {
      expect(
        LeaderboardMapper.pathFor(window: LeaderboardWindow.weekly, limit: 50),
        '/api/v1/leaderboard?window=weekly&limit=50',
      );
    });

    test('sends `all_time` and not the member name `allTime`', () {
      // The value `.name` would give is `allTime`, and the server's enum rejects it
      // with 400 — so this asserts the code, not the spelling that looks right.
      expect(
        LeaderboardMapper.pathFor(window: LeaderboardWindow.allTime, limit: 3),
        contains('window=all_time'),
      );
    });
  });

  group('fromCode', () {
    test('names all three windows the server accepts', () {
      expect(LeaderboardWindow.fromCode('weekly'), LeaderboardWindow.weekly);
      expect(LeaderboardWindow.fromCode('monthly'), LeaderboardWindow.monthly);
      expect(LeaderboardWindow.fromCode('all_time'), LeaderboardWindow.allTime);
    });

    test('and returns null for anything else, so the mapper can refuse', () {
      expect(LeaderboardWindow.fromCode('yearly'), isNull);
      expect(LeaderboardWindow.fromCode('allTime'), isNull);
      expect(LeaderboardWindow.fromCode(''), isNull);
    });
  });

  group('the seeded empty board is a success, not a failure', () {
    test('and carries no rows', () {
      final LeaderboardBoard parsed = expectSuccess(mapped(emptyBoard));
      expect(parsed.rows, isEmpty);
      expect(parsed.window, LeaderboardWindow.weekly);
      expect(parsed.groupId, 3);
      expect(parsed.standing, isNull);
    });

    test('because nobody scoring is a product state the UI has to draw', () {
      // The regression this forbids: treating "no rows" as an error puts an error
      // panel on every Home in the seeded environment, which is *every* screen for
      // as long as submissions cannot complete.
      expect(mapped(emptyBoard), isA<Result<LeaderboardBoard>>());
    });
  });

  group('a populated board', () {
    test('maps rows in order, with rank and score from the payload', () {
      final LeaderboardBoard parsed = expectSuccess(mapped(board()));
      expect(parsed.rows, hasLength(2));
      expect(parsed.rows.first.rank, 1);
      expect(parsed.rows.first.score, 80);
      expect(parsed.rows.last.rank, 2);
      expect(parsed.rows.last.score, 50);
    });

    test('reads userId, full_name and current_streak for every row', () {
      final LeaderboardBoard parsed = expectSuccess(mapped(board()));
      final LeaderboardRow first = parsed.rows.first;
      expect(first.userId, '22222222-2222-2222-2222-222222222222');
      expect(first.fullName, 'Peter George (Grade 6)');
      expect(first.currentStreak, 7);
      expect(first.initials, 'PG');
    });

    test('takes the window from the response, not from the request', () {
      // Echoing is the only place the two can be compared; a client that assumed its
      // own request was honoured would label a monthly board "this week".
      final LeaderboardBoard parsed = expectSuccess(
        mapped(board(window: 'monthly')),
      );
      expect(parsed.window, LeaderboardWindow.monthly);
    });

    test('and drops `total_ranked`, which is the returned count and not the cohort', () {
      // The board has no field to render "3 of N" from. Asserted structurally: the
      // entity has no such member, and this test fails if one is added.
      expect(mapped(board()), isA<Result<LeaderboardBoard>>());
      // There is deliberately **no** `expect(parsed.totalRanked, …)` here, and the
      // absence is the test: Dart will not compile a reference to a member the entity
      // does not have. A "the field is not mapped" assertion cannot be written in a
      // statically typed language — which is exactly why dropping the field beats
      // mapping it and documenting what it really means.
      final LeaderboardBoard parsed = expectSuccess(mapped(board()));
      expect(
        parsed.toString(),
        isNot(contains('totalRanked')),
        reason: 'the returned row count must not travel into the entity',
      );
    });
  });

  group('`my_standing`: two different absences, kept apart', () {
    test('a null rank is a standing with no position, not no standing', () {
      final LeaderboardBoard parsed = expectSuccess(
        mapped(board(myStanding: <String, Object?>{'rank': null, 'score': 0})),
      );
      final LeaderboardStanding standing = parsed.standing!;
      expect(standing.rank, isNull);
      expect(standing.score, 0);
    });

    test('a null object is no standing at all', () {
      final LeaderboardBoard parsed = expectSuccess(mapped(board()));
      expect(parsed.standing, isNull);
    });

    test('and a real position is carried through', () {
      final LeaderboardBoard parsed = expectSuccess(
        mapped(board(myStanding: <String, Object?>{'rank': 2, 'score': 50})),
      );
      expect(parsed.standing!.rank, 2);
      expect(parsed.standing!.score, 50);
    });

    test('a missing `rank` key is a failure, not an implicit null', () {
      // Absent and present-but-null are different payloads. Only the second is the
      // server's way of saying "unranked"; the first means the shape changed.
      final Failure failure = expectFailure(
        mapped(board(myStanding: <String, Object?>{'score': 0})),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('rank'));
    });

    test('and a non-object `my_standing` is refused', () {
      final Failure failure = expectFailure(mapped(board(myStanding: 7)));
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('null or a JSON object'));
    });
  });

  group('a bad row fails the whole board, and here is why that differs from a verse', () {
    test('a missing rank anywhere refuses the board', () {
      // Skipping row 2 would leave ranks 1, 3 — a ranking with a hole in it, which
      // reads as authoritative while being wrong. See the mapper's class doc.
      final Failure failure = expectFailure(
        mapped(
          board(
            rows: <Object?>[
              row(),
              <String, Object?>{
                'score': 50,
                'full_name': 'David Mina (Grade 5)',
              },
            ],
          ),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('rank'));
    });

    test('and the message names the index, so the bad row can be found', () {
      final Failure failure = expectFailure(
        mapped(
          board(
            rows: <Object?>[
              row(),
              row(rank: 2, score: 'eighty'),
            ],
          ),
        ),
      );
      expect(failure.message, contains('leaderboard[1]'));
      expect(failure.message, contains('an int'));
    });

    test('a row that is not an object is refused too', () {
      final Failure failure = expectFailure(
        mapped(board(rows: <Object?>['Peter'])),
      );
      expect(failure.message, contains('leaderboard[0]'));
    });

    test('and a `score` of 6.0 is refused rather than truncated', () {
      // JSON `6.0` decodes to a Dart `double`. Accepting it means silently
      // truncating a number the server sent.
      final Failure failure = expectFailure(
        mapped(board(rows: <Object?>[row(score: 6.0)])),
      );
      expect(failure.message, contains('an int'));
    });

    test('a missing userId refuses the row, naming the key', () {
      final Failure failure = expectFailure(
        mapped(board(rows: <Object?>[row(userId: null)])),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('leaderboard[0].userId'));
      expect(failure.message, contains('a String'));
    });

    test('a missing full_name refuses the row, naming the key', () {
      final Failure failure = expectFailure(
        mapped(board(rows: <Object?>[row(fullName: null)])),
      );
      expect(failure.message, contains('leaderboard[0].full_name'));
    });

    test('a missing current_streak refuses the row, naming the key', () {
      final Failure failure = expectFailure(
        mapped(board(rows: <Object?>[row(currentStreak: null)])),
      );
      expect(failure.message, contains('leaderboard[0].current_streak'));
      expect(failure.message, contains('an int'));
    });

    test('a wrong-typed userId and current_streak are refused too', () {
      expect(
        expectFailure(mapped(board(rows: <Object?>[row(userId: 7)]))).message,
        contains('a String'),
      );
      expect(
        expectFailure(
          mapped(board(rows: <Object?>[row(currentStreak: 'seven')])),
        ).message,
        contains('an int'),
      );
    });
  });

  group('an unreadable body', () {
    test('null names the proxy that swallowed it', () {
      final Failure failure = expectFailure(mapped(null));
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('empty'));
    });

    test('an HTML document is named as one, with its length', () {
      final Failure failure = expectFailure(
        mapped('<!DOCTYPE html><html>502</html>'),
      );
      expect(failure.message, contains('HTML'));
      expect(failure.message, contains('31'));
    });

    test('an unknown window is refused rather than defaulted to weekly', () {
      // The dangerous version of this test asserts `weekly`: a server that grew a
      // fourth window would then be reported as "this week", which is a wrong answer
      // presented confidently.
      final Failure failure = expectFailure(mapped(board(window: 'yearly')));
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('weekly, monthly, all_time'));
    });

    test('a missing `leaderboard` key is a failure', () {
      final Map<String, Object?> body = board()..remove('leaderboard');
      final Failure failure = expectFailure(mapped(body));
      expect(failure.message, contains('leaderboard'));
    });

    test('a non-object body names its runtime type', () {
      final Failure failure = expectFailure(mapped(<Object?>[]));
      expect(failure.message, contains('not a JSON object'));
    });
  });

  group('initialsOf', () {
    test('takes first and last, and drops the grade annotation', () {
      // The seeded names. `split(' ').take(2)` would give `Da`/`Pe`/`Ma` here.
      expect(LeaderboardMapper.initialsOf('David Mina (Grade 5)'), 'DM');
      expect(LeaderboardMapper.initialsOf('Peter George (Grade 6)'), 'PG');
      expect(LeaderboardMapper.initialsOf('Mark Anton (Grade 5)'), 'MA');
    });

    test('handles a name with no annotation at all', () {
      expect(LeaderboardMapper.initialsOf('Servant Michael'), 'SM');
    });

    test('uses the LAST token for a three-part name', () {
      // The family name is what distinguishes one Ana from another in a cohort.
      expect(LeaderboardMapper.initialsOf('Ana Maria Silva'), 'AS');
    });

    test('gives one initial for a one-word name', () {
      // The server's own enrichment fallback is the bare string `Student`.
      expect(LeaderboardMapper.initialsOf('Student'), 'S');
    });

    test('is a placeholder, never an empty string', () {
      expect(
        LeaderboardMapper.initialsOf(''),
        LeaderboardMapper.unknownInitials,
      );
      expect(
        LeaderboardMapper.initialsOf('   '),
        LeaderboardMapper.unknownInitials,
      );
      expect(
        LeaderboardMapper.initialsOf('()'),
        LeaderboardMapper.unknownInitials,
      );
    });

    test('works on Arabic, which has no case to upper-case', () {
      // Two of the three seeded children have `preferred_lang: 'ar'`. `toUpperCase()`
      // is correctly a no-op on these, so the letters must survive unchanged.
      expect(LeaderboardMapper.initialsOf('مريم الحسن'), 'ما');
      expect(LeaderboardMapper.initialsOf('شخص (صف 5)'), 'ش');
    });

    test('takes a whole code point, not a UTF-16 unit', () {
      // `[0]` splits a supplementary-plane character and yields a lone surrogate.
      // A name made only of one: it must come back whole, not as half a character.
      const String supplementary = '\u{1D4A0}';
      expect(LeaderboardMapper.initialsOf(supplementary), supplementary);
      expect(LeaderboardMapper.initialsOf(supplementary).runes, hasLength(1));
    });

    test('survives a name that is only an annotation', () {
      expect(
        LeaderboardMapper.initialsOf('(Grade 6)'),
        LeaderboardMapper.unknownInitials,
      );
    });
  });

  group('cohortSize — the size rule that survives the ZCARD change', () {
    test(
      'is exact when the cap did not bind, and the cap is `rows < limit`',
      () {
        // 5 children, `limit=50`: ZREVRANGE returned all of them, so the cohort is 5.
        expect(
          LeaderboardMapper.cohortSizeOf(
            reportedTotal: 5,
            rowsReturned: 5,
            limit: 50,
          ),
          5,
        );
      },
    );

    test('is null when the rows exactly fill the limit', () {
      // 50 rows for `limit=50` is ambiguous: the cohort is 50, or 500. Saying 50 would
      // be a guess, and a guess here becomes "3rd of 3" on a cohort of sixty.
      expect(
        LeaderboardMapper.cohortSizeOf(
          reportedTotal: 50,
          rowsReturned: 50,
          limit: 50,
        ),
        isNull,
      );
    });

    test(
      "is today's server: a cohort of 60 at limit 50 answers null, not 50",
      () {
        // `total_ranked` is `enrichedEntries.length` today, so it reports 50 and there
        // is no way to tell 50 from 600.
        expect(
          LeaderboardMapper.cohortSizeOf(
            reportedTotal: 50,
            rowsReturned: 50,
            limit: 50,
          ),
          isNull,
        );
      },
    );

    test('and is the TRUE 60 the moment the route sends a ZCARD', () {
      // Same 50 rows, same limit. The only difference is that `total_ranked` now
      // exceeds the rows returned, which is the proof that it is counting something
      // the page does not contain. No line of this mapper changes when the backend
      // fixes the route.
      expect(
        LeaderboardMapper.cohortSizeOf(
          reportedTotal: 60,
          rowsReturned: 50,
          limit: 50,
        ),
        60,
      );
    });

    test('a cohort of 3 answers 3 under BOTH server versions', () {
      for (final int reported in <int>[3, 3]) {
        expect(
          LeaderboardMapper.cohortSizeOf(
            reportedTotal: reported,
            rowsReturned: 3,
            limit: 50,
          ),
          3,
        );
      }
    });

    test('an empty cohort is 0, not null — nobody scoring IS a known size', () {
      // The distinction that keeps the empty state honest: 0 ranked children is a fact
      // about the cohort, while `null` is a fact about the response.
      expect(
        LeaderboardMapper.cohortSizeOf(
          reportedTotal: 0,
          rowsReturned: 0,
          limit: 50,
        ),
        0,
      );
    });

    test('and it rides through `map`, on the seeded empty board', () {
      expect(expectSuccess(mapped(emptyBoard)).cohortSize, 0);
    });

    test('a board whose rows fill the limit reports no size at all', () {
      final List<Object?> rows = <Object?>[
        for (int i = 1; i <= 3; i++) row(rank: i, score: 100 - i),
      ];
      final LeaderboardBoard parsed = expectSuccess(
        const LeaderboardMapper().map(board(rows: rows), limit: 3),
      );
      expect(parsed.rows, hasLength(3));
      expect(parsed.cohortSize, isNull);
    });
  });

  group('rows carry the name, the streak and the id the screen now draws', () {
    test('a mapped row carries all three, and initials still come from the name', () {
      // The privacy requirement was structural in Phase 1 and is superseded by
      // ADR-0022 `:110-113`; the veil (`:243-245`) is the rendering-time control.
      final LeaderboardRow row = expectSuccess(mapped(board())).rows.first;
      expect(row.fullName, 'Peter George (Grade 6)');
      expect(row.currentStreak, 7);
      expect(row.userId, '22222222-2222-2222-2222-222222222222');
      // The monogram is derived from the same string, so the two cannot disagree.
      expect(row.initials, LeaderboardMapper.initialsOf(row.fullName));
    });
  });
}
