import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';

/// Turns one `GET /api/v1/readings/today/{lang}` body into a [TodayReading].
///
/// ## WHY IT RETURNS A `Result` AND NOT AN ENTITY
///
/// Because "the response arrived with a 200 and its body cannot be read" is a
/// failure the repository has to produce, and §3's LSP row says a repository
/// **never throws** and **always returns a `Result`**. `failure.dart` already has
/// the vocabulary for exactly this: `FailureKind.serialization`, documented as
/// "a 2xx response body could not be parsed into a domain entity".
///
/// Making the mapper produce it puts the shape knowledge next to the field that
/// is malformed, which is where a reader debugging a response wants to be. The
/// repository's body is then two arms — a `DioException` and a body — instead of
/// three.
///
/// ## WHY EVERY FIELD IS REQUIRED, AND NOTHING HAS A DEFAULT
///
/// A default is a claim about a payload this client has not seen. `group_id`
/// defaulting to `3` would render the wrong cohort's reading for any group other
/// than 3 while every field around it looked right. `verseCount` defaulting to
/// `0` would draw a panel with no preview and no error. So: a missing key, a wrong
/// type, or an unrecognised enumeration is [FailureKind.serialization], and the
/// message names the key and what was expected.
///
/// The exceptions are stated on the helpers that have them and are narrow: a
/// **missing** `text_clean` on a verse falls back to `text` (§5 trap 2 — the
/// English arm has no such key at all), and a missing or non-`bool`
/// `already_answered` on a question counts as not answered. Both are absences the
/// *live* payloads actually have.
///
/// ## THE SCALAR POLICY, WHICH WAS UNTIL NOW TWO UNSTATED HABITS
///
/// Every scalar below is either **refused as impossible** or **passed through as
/// "the server said so"**, and the line between them is one question: *would this
/// client render the value as something a reader would read as a fact about their
/// own reading?* Nothing else decides it — not "is it empty", not "is it big".
///
/// | field | policy | why |
/// | --- | --- | --- |
/// | `verses` (not a list / empty) | **refused** | no verse to preview and no count to draw a bead for |
/// | `verses[0]` (not an object) | **refused** | the preview is read out of it |
/// | `language` (unknown code) | **refused** | defaulting would build an entity claiming to be English scripture which is not |
/// | `current_streak` (**negative**) | **refused** | a streak counts completed days; `-5` on the flame is not a fact about anyone |
/// | `reading_id`, `group_id`, `scheduled_date` | passed through | identity and scheduling metadata; nothing on `/` renders them, so an odd value is inert |
/// | `translation` | passed through | an edition name; empty is a missing label, not a broken reading |
/// | `reference` (**empty**) | passed through | it is a heading *over* the passage — refusing it would make the passage unreachable over a missing label, the same argument as `_preview` below |
/// | `current_streak` (large positive) | passed through | this client has seen no upper bound, and inventing one is a claim about a payload it has not seen — the same argument this section makes against defaults |
/// | `total_points_earned_today`, `is_fully_completed` | passed through | `0` and `false` are real answers, not absences |
///
/// **Rejected: refusing every empty string.** It is the rule a first pass reaches
/// for and it is wrong twice over — it would refuse `reference: ''` and make today's
/// reading unreachable, and it would make `current_streak: 0` a failure, which is
/// exactly the value the live payload carries on every cold launch.
///
/// **Rejected: refusing a large `current_streak`.** It is bounded by layout rather
/// than by a rule: `AppTopBar` puts the wordmark in an `Expanded` with
/// `TextOverflow.ellipsis`, so the bar absorbs an arbitrarily long number by
/// truncating the wordmark instead of overflowing. `home_page_test.dart` renders a
/// twelve-digit streak and asserts no overflow, so the mitigation is a witness
/// rather than a hope.
///
/// ## AND WHY THERE IS NO INTERMEDIATE MODEL CLASS
///
/// `08-build-phases.md` §Phase 7 asks for "the remote data source and its
/// mapper". A `TodayReadingModel` alongside it would hold the raw `verses` and
/// `questions` arrays — a second declaration of the payload for a reader to keep in
/// step, in exchange for nothing, since this projection reads eight top-level
/// scalars, one list's length, one list's first element and a count.
/// `ApiErrorMapper` is the in-repo precedent for one `const` class per direction,
/// and that is the shape used.
final class TodayReadingMapper {
  /// Creates a mapper. Stateless and `const`.
  const TodayReadingMapper();

  /// The endpoint, without the `{lang}` segment.
  ///
  /// The `/api/v1` prefix lives here and not in `AppConfig` for the reason
  /// `dio_client.dart`'s doc gives: the base URL is the host, and a deployment
  /// behind a path-prefixed proxy has to stay reachable.
  static const String todayEndpoint = '/api/v1/readings/today';

  /// The path for [language].
  ///
  /// `ReadingLanguage.code` is the wire value, so this is the only place the enum
  /// meets a URL and there is no `'en'` / `'ar'` literal to drift against `.name`.
  static String pathFor(ReadingLanguage language) =>
      '$todayEndpoint/${language.code}';

  /// Maps [body] to a [TodayReading].
  ///
  /// Never throws. Every rejection is a [Failure] whose [Failure.message] names
  /// the key and what was expected, so the failure a reader sees is a statement
  /// about the response rather than a Dart type error.
  Result<TodayReading> map(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<TodayReading>.failure(_notAnObject(body));
    }

    // Read in **wire order**, so the message on a body with several problems names
    // the key a reader meets first scrolling the JSON. An earlier draft ran the
    // checks in the order the entity declares its fields, which put `verseCount`
    // ahead of `reading_id`.
    final Result<String> readingId = _string(body, 'reading_id');
    final Result<int> groupId = _int(body, 'group_id');
    final Result<String> scheduledDate = _string(body, 'scheduled_date');
    final Result<String> reference = _string(body, 'reference');
    final Result<String> translation = _string(body, 'translation');
    final Result<bool> isFullyCompleted = _bool(body, 'is_fully_completed');
    final Result<int> points = _int(body, 'total_points_earned_today');
    final Result<int> streak = _nonNegativeInt(body, 'current_streak');

    final Result<ReadingLanguage> language = _language(body);

    final Result<List<Object?>> verses = _list(body, 'verses');
    final Result<List<Object?>> questions = _list(body, 'questions');

    // One gate for every check, in the order above. The preview is read after it
    // because it needs `verses`, which the gate has already proved readable.
    final Result<void> scalars = _firstFailure(<Result<Object?>>[
      readingId,
      groupId,
      scheduledDate,
      reference,
      translation,
      isFullyCompleted,
      points,
      streak,
      language,
      verses,
      questions,
    ]);
    if (scalars case FailureResult<void>(:final Failure failure)) {
      return Result<TodayReading>.failure(failure);
    }

    final Result<String> preview = _preview(verses.valueOrElse(<Object?>[]));
    if (preview case FailureResult<String>(:final Failure failure)) {
      return Result<TodayReading>.failure(failure);
    }

    // `valueOrElse` from here, not `!`: the gate above has proved there is no
    // failure arm to take, so the fallback can never be reached, and spelling it
    // this way keeps §4's "no `!` unless provably non-null" honest without an
    // ignore.
    return Result<TodayReading>.success(
      TodayReading(
        readingId: readingId.valueOrElse(''),
        groupId: groupId.valueOrElse(0),
        scheduledDate: scheduledDate.valueOrElse(''),
        language: language.valueOrElse(ReadingLanguage.english),
        reference: reference.valueOrElse(''),
        translation: translation.valueOrElse(''),
        verseCount: verses.valueOrElse(<Object?>[]).length,
        firstVerseText: preview.valueOrElse(''),
        questionCount: questions.valueOrElse(<Object?>[]).length,
        answeredQuestionCount: _answeredCount(
          questions.valueOrElse(<Object?>[]),
        ),
        isFullyCompleted: isFullyCompleted.valueOrElse(false),
        pointsEarnedToday: points.valueOrElse(0),
        // The reading endpoint's **own** streak copy, which reads `4` where
        // `streak/summary` reads `0`. Carried because the payload carries it;
        // `TodayReading.currentStreak`'s doc says why nothing reads it and why
        // removing it would be worse.
        currentStreak: streak.valueOrElse(0),
      ),
    );
  }

  /// `language`, through [ReadingLanguage.fromCode].
  ///
  /// The nullable wire lookup, so an unknown code is `null` and becomes a
  /// serialization failure. That function's doc gives the whole argument; the
  /// short version is that defaulting would build an entity claiming to be
  /// English scripture which is not.
  Result<ReadingLanguage> _language(Map<Object?, Object?> body) {
    final Object? value = body['language'];
    final ReadingLanguage? language = value is String
        ? ReadingLanguage.fromCode(value)
        : null;
    return language == null
        ? Result<ReadingLanguage>.failure(
            _bad('language', value, 'one of ${ReadingLanguage.values}'),
          )
        : Result<ReadingLanguage>.success(language);
  }

  /// The first verse's preview text.
  ///
  /// `text_clean` where the key **exists and carries something**, `text`
  /// otherwise. Both absences are live: the English payload has no `text_clean`
  /// key at all, and "present but empty" is a third shape a proxy or a
  /// re-encoder can produce.
  ///
  /// ## AND IT DELIBERATELY DOES **NOT** RULE ON AN EMPTY VERSE
  ///
  /// `text_clean` empty falls through to `text`, and `text` empty maps to `''`.
  ///
  /// **This doc used to claim the opposite** — "neither falls through to `''`,
  /// because an empty preview renders an empty paragraph in the panel" — and the
  /// panel did not render an empty paragraph. `_Preview` called
  /// `preview.substring(0, 1)` on the result, which is a `RangeError` out of
  /// `TodayReadingPanel.build`, and because the panel's two controls are that
  /// widget's own children the error took **`Continue` → `/reading` and
  /// `Start reflection` → `/quiz`** with it. A doc claim contradicted by the file
  /// it lives in, three directories away, and 1520 tests green throughout.
  ///
  /// **Refusing here was rejected, and the reason is worth keeping.** The verse
  /// text is the one field on `/` a reader cannot be shown without; every other
  /// field is a label *over* content (a reference, a completion flag, a bead
  /// count). A payload missing its label should cost the label, not the passage —
  /// so `text: ''` maps, `firstVerseText` is `''`, and `_Preview` renders an empty
  /// paragraph and **both its controls stay**. The alternative — treating an empty
  /// verse as unparseable — would have made one cosmetic upstream defect into "the
  /// reader cannot open today's reading at all".
  ///
  /// The division of labour this records: **the mapper says what the payload
  /// means, the widget says it renders whatever it is handed.** Neither guesses for
  /// the other, and the widget's totality is asserted rather than assumed.
  Result<String> _preview(List<Object?>? verses) {
    if (verses == null || verses.isEmpty) {
      return Result<String>.failure(_bad('verses', verses, 'a non-empty list'));
    }
    final Object? first = verses.first;
    if (first is! Map<Object?, Object?>) {
      return Result<String>.failure(_bad('verses[0]', first, 'an object'));
    }

    final Object? clean = first['text_clean'];
    if (clean is String && clean.isNotEmpty) {
      return Result<String>.success(clean);
    }

    final Object? text = first['text'];
    if (text is! String) {
      return Result<String>.failure(_bad('verses[0].text', text, 'a String'));
    }
    return Result<String>.success(text);
  }

  /// How many of [questions] carry `already_answered == true`.
  ///
  /// A question that is not an object, or whose flag is not a `bool`, counts as
  /// **not answered** rather than failing the whole reading. That is the opposite
  /// of the scalars, and deliberately so: a flag this client cannot read is a
  /// question it cannot claim is done, so the panel's bead row shows one more
  /// open bead rather than an error over a reading the reader can still open.
  ///
  /// The cost is stated because it is a real difference in strictness: a payload
  /// whose questions are *all* malformed maps successfully with
  /// `answeredQuestionCount == 0`. `questions` not being a list at all **is**
  /// rejected, because then there is no question to draw a bead for.
  int _answeredCount(List<Object?> questions) {
    int answered = 0;
    for (final Object? question in questions) {
      if (question is Map<Object?, Object?> &&
          question['already_answered'] == true) {
        answered++;
      }
    }
    return answered;
  }

  // --- typed reads ----------------------------------------------------------

  Result<String> _string(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is String
        ? Result<String>.success(value)
        : Result<String>.failure(_bad(key, value, 'a String'));
  }

  /// An `int`, and not a `num`.
  ///
  /// JSON `6.0` decodes to a Dart `double`, and the fields read here are counts.
  /// Accepting it would mean truncating a number the server sent, silently, and
  /// the failure would be a verse count that is one off for a reader with no way
  /// to tell why.
  Result<int> _int(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is int
        ? Result<int>.success(value)
        : Result<int>.failure(_bad(key, value, 'an int'));
  }

  /// A count that cannot be negative.
  ///
  /// **One caller, and it is a different rule from [_int].** `current_streak`
  /// counts days completed, so there is no negative reading of it, and `/` draws
  /// the number in the top bar next to a sentence that says the streak is glowing
  /// or resting. A `-5` there is not a fact about the reader, and a "the server
  /// said so" defence does not survive being shown to one: §13's colour-only rule
  /// has nothing to say about a value that is arithmetically impossible and
  /// visually loud.
  ///
  /// **Not applied to `total_points_earned_today`.** Points earned in a day are
  /// `0` or more by the same argument, and that one is left alone: it is rendered
  /// nowhere on `/`, so an impossible value there is inert rather than loud, and
  /// refusing it would add a rule with no reader-visible consequence. The
  /// difference is recorded in the class doc's table, which is where the two
  /// decisions belong together.
  Result<int> _nonNegativeInt(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    if (value is! int) {
      return Result<int>.failure(_bad(key, value, 'an int'));
    }
    if (value < 0) {
      return Result<int>.failure(
        _bad(key, value, 'an int of 0 or more — a count of completed days'),
      );
    }
    return Result<int>.success(value);
  }

  Result<bool> _bool(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is bool
        ? Result<bool>.success(value)
        : Result<bool>.failure(_bad(key, value, 'a bool'));
  }

  Result<List<Object?>> _list(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is List<Object?>
        ? Result<List<Object?>>.success(value)
        : Result<List<Object?>>.failure(_bad(key, value, 'a list'));
  }

  /// The first failure among [results], as a `Result<void>` so the caller
  /// pattern-matches it once instead of checking eleven locals.
  Result<void> _firstFailure(List<Result<Object?>> results) {
    for (final Result<Object?> result in results) {
      if (result case FailureResult<Object?>(:final Failure failure)) {
        return Result<void>.failure(failure);
      }
    }
    return const Result<void>.success(null);
  }

  /// Why a body that is not an object is named by *what it was*, not by a type.
  ///
  /// A `catch` around a `Map<String, dynamic>` cast would report
  /// `type 'Null' is not a subtype of type 'Map<String, dynamic>'` or an HTML
  /// string's first thousand characters, and neither tells a reader whether the
  /// backend sent nothing, sent a proxy's error page, or sent a number. Three
  /// named cases and a fallback beat all four being spelled `X is not a Y`.
  Failure _notAnObject(Object? body) => Failure(
    kind: FailureKind.serialization,
    message: switch (body) {
      null =>
        "Could not read today's reading: the response body was empty. A 200 with "
            'no body is what a proxy returns when it swallows the upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        "Could not read today's reading: the response body is an HTML document "
            '(${text.length} characters), not JSON. Something between the app and '
            'the backend answered instead of it.',
      final Object other =>
        "Could not read today's reading: the response body is a "
            '${other.runtimeType}, not a JSON object.',
    },
  );

  Failure _bad(String key, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        "Could not read today's reading: `$key` is "
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
