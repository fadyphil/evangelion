import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';

/// Turns the leaderboard response body into a [LeaderboardBoard].
///
/// ## THE PAYLOAD SPEAKS TWO KEY CASINGS IN ONE OBJECT
///
/// Measured from the live endpoint, `GET /api/v1/leaderboard?window=weekly`:
///
/// ```json
/// {"group_id":3,"window":"weekly","total_ranked":0,"my_standing":null,
///  "leaderboard":[]}
/// ```
///
/// and a populated row is `{"userId":…,"score":…,"rank":…,"full_name":…,"current_streak":…}`
/// — `userId` in **camelCase** while `full_name` and `current_streak` are snake_case,
/// inside the same array. That is the server's shape, not a typo to be smoothed over,
/// and it is why this mapper reads keys as literals in one place instead of
/// normalising case: a case-folding reader would hide a future rename instead of
/// failing on it.
///
/// **Two of those five keys are never read**, deliberately: `userId` and
/// `current_streak`. See [LeaderboardRow] for why each is dropped rather than mapped.
///
/// ## WHAT A BAD ROW DOES HERE, WHICH IS NOT WHAT A BAD VERSE DOES
///
/// `TodayReadingMapper` lets one unreadable verse cost only that verse, because a
/// missing line is a shorter passage. **A leaderboard fails as a whole if any row is
/// unreadable**, because a skipped row leaves its neighbours' `rank` values gapped —
/// 1, 2, 4 — and a ranking with a hole in it is worse than an error with a retry,
/// since it reads as authoritative while being wrong.
///
/// The rows are also homogeneous by construction: the server builds them all in one
/// `.map()` over one array, so there is no realistic payload where row 4 is malformed
/// and rows 1-3 are fine. The strictness costs nothing in practice and removes a class
/// of silently-wrong screen.
final class LeaderboardMapper {
  /// Creates a mapper. Stateless and `const`.
  const LeaderboardMapper();

  /// The endpoint, including the `/api/v1` prefix.
  ///
  /// Here and not in `AppConfig`, for the reason `dio_client.dart`'s doc gives: the
  /// base URL is the host, and a deployment behind a path-prefixed proxy has to stay
  /// reachable.
  static const String endpoint = '/api/v1/leaderboard';

  /// The path for [window] and [limit].
  ///
  /// `limit` is interpolated unencoded because the server's querystring schema types
  /// it as `type: 'string'` and parses it with `parseInt` — it is a number that
  /// travels as text, so the one place that knows it is this one. A non-positive
  /// value is **not** validated here: the server would return an empty ranking for
  /// `limit=0`, and inventing a client-side rejection would be a rule the endpoint
  /// does not have.
  static String pathFor({
    required LeaderboardWindow window,
    required int limit,
  }) => '$endpoint?window=${window.code}&limit=$limit';

  /// What a name that yields no initials is labelled.
  ///
  /// `'?'` rather than `''` or a blank space, because a row with an empty monogram
  /// renders as a mysterious gap in a list of three others that all have one.
  static const String unknownInitials = '?';

  /// Maps [body] to a [LeaderboardBoard].
  ///
  /// Never throws, and the [Failure.message] on every rejection names the key and what
  /// was expected — so the message a reader sees is a statement about the response
  /// rather than a Dart type error.
  Result<LeaderboardBoard> map(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<LeaderboardBoard>.failure(_notAnObject(body));
    }

    // Wire order, so the message on a body with several problems names the key a
    // reader meets first in the JSON.
    final Result<int> groupId = _int(body, 'group_id');
    final Result<LeaderboardWindow> window = _window(body, 'window');
    final Result<List<Object?>> rawRows = _list(body, 'leaderboard');
    final Result<LeaderboardStanding?> standing = _standing(
      body,
      'my_standing',
    );

    final Result<void> scalars = _firstFailure(<Result<Object?>>[
      groupId,
      window,
      rawRows,
      standing,
    ]);
    if (scalars case FailureResult<void>(:final Failure failure)) {
      return Result<LeaderboardBoard>.failure(failure);
    }

    final Result<List<LeaderboardRow>> rows = _rows(
      rawRows.valueOrElse(<Object?>[]),
    );
    if (rows case FailureResult<List<LeaderboardRow>>(:final Failure failure)) {
      return Result<LeaderboardBoard>.failure(failure);
    }

    // `valueOrElse` rather than `!`: the gate above has proved there is no failure
    // arm, so the fallback cannot be reached, and §4 forbids a `!` that is not
    // provably non-null.
    return Result<LeaderboardBoard>.success(
      LeaderboardBoard(
        window: window.valueOrElse(LeaderboardWindow.weekly),
        groupId: groupId.valueOrElse(0),
        rows: rows.valueOrElse(const <LeaderboardRow>[]),
        standing: standing.valueOrElse(null),
      ),
    );
  }

  /// The monogram for [fullName].
  ///
  /// ## THE RULE, AND WHY IT IS NOT `split(' ').take(2)`
  ///
  /// The seeded names are `'David Mina (Grade 5)'`, `'Peter George (Grade 6)'` and
  /// `'Mark Anton (Grade 5)'`, so a naive first-two-tokens split yields `DM` for one
  /// of them by luck and `Da`, `Pe`, `Ma` for the others — the grade annotation
  /// becomes the second initial. Parenthetical spans are therefore **stripped first**,
  /// and the letters are taken from what is left: the first token's and the last
  /// token's.
  ///
  /// ## WHY FIRST-AND-LAST RATHER THAN FIRST-TWO
  ///
  /// Three-part names exist in both scripts this app ships. `'Ana Maria Silva'`
  /// should read `AS`, not `AM` — the family name is the one that distinguishes her
  /// from another Ana in the same cohort, and it is also the convention for a badge.
  ///
  /// ## WHY `runes` AND NOT `[0]`
  ///
  /// Because this app is bilingual and the seeded cohort's `preferred_lang` is `ar` for
  /// two of three children. `name[0]` is a **UTF-16 code unit**, so it splits a
  /// character outside the Basic Multilingual Plane and produces a lone surrogate for
  /// a supplementary character. `runes` yields whole code points. Arabic has no case,
  /// so `toUpperCase()` is correctly a no-op there rather than a bug.
  ///
  /// ## WHY AN EMPTY RESULT IS NOT AN EMPTY STRING
  ///
  /// A name of `''`, `'   '`, or `'()'` leaves nothing after stripping. Returning `''`
  /// would put a blank where every other row has a monogram; [unknownInitials] says
  /// "no initials" where the reader is already looking at a position and a score.
  static String initialsOf(String fullName) {
    final String withoutAnnotations = fullName.replaceAll(
      RegExp(r'\([^)]*\)'),
      ' ',
    );
    final List<String> tokens = withoutAnnotations
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return unknownInitials;
    }
    if (tokens.length == 1) {
      return _initialOf(tokens.first);
    }
    return '${_initialOf(tokens.first)}${_initialOf(tokens.last)}';
  }

  /// The upper-cased first code point of [token], or [unknownInitials] if it has none.
  static String _initialOf(String token) => token.runes.isEmpty
      ? unknownInitials
      : String.fromCharCode(token.runes.first).toUpperCase();

  /// The ranked rows, all-or-nothing.
  ///
  /// An **empty** array is a success with no rows: nobody in the cohort has scored,
  /// which is the seeded backend's real answer and a state the UI has to draw.
  Result<List<LeaderboardRow>> _rows(List<Object?> raw) {
    final List<LeaderboardRow> mapped = <LeaderboardRow>[];
    for (int index = 0; index < raw.length; index++) {
      final Object? entry = raw[index];
      if (entry is! Map<Object?, Object?>) {
        return Result<List<LeaderboardRow>>.failure(
          _bad('leaderboard[$index]', entry, 'a JSON object'),
        );
      }
      final Result<LeaderboardRow> row = _row(entry, index);
      if (row case FailureResult<LeaderboardRow>(:final Failure failure)) {
        return Result<List<LeaderboardRow>>.failure(failure);
      }
      if (row case Success<LeaderboardRow>(:final LeaderboardRow value)) {
        mapped.add(value);
      }
    }
    return Result<List<LeaderboardRow>>.success(mapped);
  }

  /// One row, read under [label] so a failure names **which** row was wrong.
  ///
  /// `leaderboard[1].score` rather than `score`: the rows are a homogeneous array built
  /// by one `.map()` on the server, so "score was not an int" is a statement about the
  /// payload only if the reader knows which of forty entries it came from.
  ///
  /// The label goes in the **message** and not in the lookup — the payload's own keys
  /// are `rank` / `score` / `full_name` at every index, and prefixing the lookup would
  /// make every row fail to find them.
  Result<LeaderboardRow> _row(Map<Object?, Object?> entry, int index) {
    final String where = 'leaderboard[$index]';
    final Result<int> rank = _int(entry, 'rank', where: where);
    final Result<int> score = _int(entry, 'score', where: where);
    final Result<String> fullName = _string(entry, 'full_name', where: where);

    final Result<void> fields = _firstFailure(<Result<Object?>>[
      rank,
      score,
      fullName,
    ]);
    if (fields case FailureResult<void>(:final Failure failure)) {
      return Result<LeaderboardRow>.failure(failure);
    }

    return Result<LeaderboardRow>.success(
      LeaderboardRow(
        rank: rank.valueOrElse(0),
        score: score.valueOrElse(0),
        initials: initialsOf(fullName.valueOrElse('')),
      ),
    );
  }

  /// `my_standing`, which is `null` for the whole object and `{rank: null}` inside it.
  ///
  /// Two different absences that must not be collapsed — see [LeaderboardStanding].
  Result<LeaderboardStanding?> _standing(
    Map<Object?, Object?> body,
    String key,
  ) {
    final Object? value = body[key];
    if (value == null) {
      return const Result<LeaderboardStanding?>.success(null);
    }
    if (value is! Map<Object?, Object?>) {
      return Result<LeaderboardStanding?>.failure(
        _bad(key, value, 'null or a JSON object'),
      );
    }

    final Result<int?> rank = _nullableInt(value, 'rank');
    final Result<int> score = _int(value, 'score');
    final Result<void> fields = _firstFailure(<Result<Object?>>[rank, score]);
    if (fields case FailureResult<void>(:final Failure failure)) {
      return Result<LeaderboardStanding?>.failure(failure);
    }

    return Result<LeaderboardStanding?>.success(
      LeaderboardStanding(
        // The nullable one, and `valueOrElse(null)` is honest here rather than a
        // fabrication: [valueOrElse] is typed `[T]`, so on a `Result<int?>` the
        // fallback's own type is `int?` and this arm cannot be reached anyway —
        // `_nullableInt` reports absence as `Success(null)`, not as a failure.
        //
        // The version this replaces read `rank` as a plain `int` and fell back to `0`,
        // which is the exact failure [LeaderboardStanding] exists to prevent: a child
        // with no score would have been rendered in 0th place.
        rank: rank.valueOrElse(null),
        score: score.valueOrElse(0),
      ),
    );
  }

  /// Reads [key], naming it `<where>.<key>` in a failure message when [where] is given.
  Result<String> _string(
    Map<Object?, Object?> body,
    String key, {
    String? where,
  }) {
    final Object? value = body[key];
    return value is String
        ? Result<String>.success(value)
        : Result<String>.failure(_bad(_at(key, where), value, 'a String'));
  }

  /// An `int`, and not a `num`.
  ///
  /// JSON `6.0` decodes to a Dart `double`, and every field read here is a count.
  /// Accepting it would mean truncating a number the server sent, silently.
  Result<int> _int(Map<Object?, Object?> body, String key, {String? where}) {
    final Object? value = body[key];
    return value is int
        ? Result<int>.success(value)
        : Result<int>.failure(_bad(_at(key, where), value, 'an int'));
  }

  /// `key`, or `<where>.<key>` — the path a reader needs to find the bad field.
  ///
  /// The prefix has to compose with the key rather than replace it. Labelling the
  /// failure `leaderboard[1]` says *the row* is absent when the row is present and its
  /// `rank` is not, which sends the reader to the wrong place. Measured: that message
  /// is what the first version produced, and the test that caught it asserted on the
  /// index, so a reader would have been told to look at a row that was fine.
  static String _at(String key, String? where) =>
      where == null ? key : '$where.$key';

  Result<LeaderboardWindow> _window(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    if (value is! String) {
      return Result<LeaderboardWindow>.failure(_bad(key, value, 'a String'));
    }
    final LeaderboardWindow? window = LeaderboardWindow.fromCode(value);
    return window == null
        ? Result<LeaderboardWindow>.failure(
            _bad(key, value, 'one of weekly, monthly, all_time'),
          )
        : Result<LeaderboardWindow>.success(window);
  }

  /// An `int`, or an explicit `null` that means "unranked".
  ///
  /// Exists because `Result<int>` cannot carry `null` — its `valueOrElse` is typed
  /// `[int]`, so a nullable field read through it needs its own `Result<int?>`. Only
  /// `my_standing.rank` uses this, and using it anywhere else would be a signal that a
  /// count had been made optional.
  ///
  /// ## WHY ABSENT IS **NOT** THE SAME AS `null`, AND WHY BOTH ARE HANDLED
  ///
  /// The server's schema declares `rank` as a property of `my_standing`, and the
  /// measured cold payload emits it: `{"rank":null,"score":0}`. So `null` is the
  /// server's *considered* way of saying "no position" — see
  /// [LeaderboardStanding] for why that is not the same as rank 0.
  ///
  /// A **missing** key is a different thing: the payload no longer has the shape the
  /// schema promises, and reading it as `null` would tell the reader they are
  /// unranked when in fact the server stopped answering the question. Guessing here
  /// produces a confident wrong answer with no way for the reader to notice, which is
  /// the one outcome this mapper exists to prevent — so absence is a
  /// [FailureKind.serialization] and the reader is offered a retry.
  Result<int?> _nullableInt(Map<Object?, Object?> body, String key) {
    if (!body.containsKey(key)) {
      return Result<int?>.failure(
        _bad(key, null, 'an int, or an explicit null'),
      );
    }
    final Object? value = body[key];
    if (value == null) {
      return const Result<int?>.success(null);
    }
    return value is int
        ? Result<int?>.success(value)
        : Result<int?>.failure(_bad(key, value, 'an int or null'));
  }

  Result<List<Object?>> _list(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is List<Object?>
        ? Result<List<Object?>>.success(value)
        : Result<List<Object?>>.failure(_bad(key, value, 'a list'));
  }

  Result<void> _firstFailure(List<Result<Object?>> results) {
    for (final Result<Object?> result in results) {
      if (result case FailureResult<Object?>(:final Failure failure)) {
        return Result<void>.failure(failure);
      }
    }
    return const Result<void>.success(null);
  }

  Failure _notAnObject(Object? body) => Failure(
    kind: FailureKind.serialization,
    message: switch (body) {
      null =>
        'Could not read the leaderboard: the response body was empty. A 200 with '
            'no body is what a proxy returns when it swallows the upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        'Could not read the leaderboard: the response body is an HTML document '
            '(${text.length} characters), not JSON. Something between the app and '
            'the backend answered instead of it.',
      final Object other =>
        'Could not read the leaderboard: the response body is a '
            '${other.runtimeType}, not a JSON object.',
    },
  );

  Failure _bad(String key, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        'Could not read the leaderboard: `$key` is '
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
