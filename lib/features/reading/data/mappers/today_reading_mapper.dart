import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/renderable_text.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
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
/// | `reference` (**empty**) | passed through | it is a heading *over* the passage — refusing it would make the passage unreachable over a missing label, the same argument as `text: ''` below |
/// | `reference`, `translation` (**malformed**) | **blanked to `''`** | a heading over the passage may be missing, but it may not be unpaintable: the engine throws on a lone surrogate from `dart:ui`'s `addText`, so keeping the bytes costs a tofu box and a caught `ArgumentError` on every layout of the title. Blanking reaches a state this table already permits two lines above; refusing it would cost the reader the whole reading |
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

  /// The resource this endpoint hangs off: `/api/v1/readings`.
  ///
  /// ## WHY IT IS A CONSTANT AND NOT PART OF [todayEndpoint]'s LITERAL
  ///
  /// Phase 8 added `POST /api/v1/readings/:id/submit`, whose path is a **sibling**
  /// of the read and not a child of it — `/api/v1/readings/today` and
  /// `/api/v1/readings/{id}/submit` share only this prefix. Writing `/api/v1` and
  /// `/readings` into a second file would put one string in two places with nothing
  /// keeping them equal, which is AGENT_CONTEXT §7's "two implementations of one
  /// invariant".
  ///
  /// It lives here because this is the mapper that already owned the `/api/v1`
  /// prefix for the read (`TodayReadingMapper`'s class doc says so), and §8's "prefer
  /// editing an existing file over creating a new one" cuts the same way.
  static const String readingsRoot = '/api/v1/readings';

  /// The endpoint, without the `{lang}` segment.
  ///
  /// The `/api/v1` prefix lives here and not in `AppConfig` for the reason
  /// `dio_client.dart`'s doc gives: the base URL is the host, and a deployment
  /// behind a path-prefixed proxy has to stay reachable.
  static const String todayEndpoint = '$readingsRoot/today';

  /// The path for [language].
  ///
  /// `ReadingLanguage.code` is the wire value, so this is the only place the enum
  /// meets a URL and there is no `'en'` / `'ar'` literal to drift against `.name`.
  static String pathFor(ReadingLanguage language) =>
      '$todayEndpoint/${language.code}';

  /// Maps [body] to a [ScriptureText] — **the whole passage**, verses and
  /// questions as entities.
  ///
  /// This is the mapper's real body. [map] is this, narrowed by
  /// [ScriptureText.toTodayReading], which is recorded decision 23's resolution
  /// reached from the other end: one data source, one mapper, one set of scalar
  /// rules, and the narrow projection `/`'s panel reads became a view of the wide
  /// payload rather than a second parse of the wire.
  ///
  /// Never throws, and says why the way [map] does: a 200 whose body cannot be
  /// read is [FailureKind.serialization], produced next to the field that is
  /// malformed.
  ///
  /// ## THE STRICTNESS IS **NOT** UNIFORM, AND THE ASYMMETRY IS THE DESIGN
  ///
  /// | what | unreadable | why |
  /// | --- | --- | --- |
  /// | a top-level scalar | **refused** | §5's live payload carries all of them, and the table in the class doc argues each one |
  /// | `verses` not a list, or empty | **refused** | there is no passage to show and no count to draw |
  /// | `verses[0]`, any required field | **refused** | verse 1 opens the passage, feeds `firstVerseText` and is what the drop cap hangs off; a passage whose opening cannot be read cannot be rendered honestly |
  /// | `verses[1…]` | **skipped** | decision 40: a defect in one verse costs that verse, not the passage |
  /// | `questions` not a list | **refused** | Phase 6's rule; there is no question to count. Enforced by [_list], **not** by [_questions] — which is handed a `List<Object?>`, so it has nothing left to refuse |
  /// | any question | **skipped** | a quiz-payload defect is not a scripture defect |
  ///
  /// **The cost of skipping a question is real and is on
  /// `ScriptureText.questionCount`:** a payload of four unreadable questions
  /// reports `0`, where Phase 6's count-only projection reported `4`. Every
  /// Phase-6 fixture that exercises the leniency counts objects, so no Phase-6
  /// assertion moved. The alternative — a wire count beside a readable list — is
  /// two sources for one fact, which is the hazard `TodayReading.isFullyCompleted`
  /// records about the two endpoints disagreeing.
  ///
  /// **Rejected: skip `verses[0]` as well.** Then a passage whose opening verse is
  /// malformed would silently render from verse 2, which is a passage this client
  /// would be showing a reader with its first line missing and nothing saying so.
  Result<ScriptureText> mapScripture(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<ScriptureText>.failure(_notAnObject(body));
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

    // One gate for every check, in the order above.
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
      return Result<ScriptureText>.failure(failure);
    }

    final Result<List<Verse>> mappedVerses = _verses(
      verses.valueOrElse(<Object?>[]),
    );
    if (mappedVerses case FailureResult<List<Verse>>(:final Failure failure)) {
      return Result<ScriptureText>.failure(failure);
    }

    // **A `List<Question>` and not a `Result`,** because [\_questions] cannot fail:
    // an unreadable entry is **skipped**, and the whole question of skipping is
    // settled by the table below. A `Result` here manufactured an arm that nothing
    // could reach — `mappedQuestions case FailureResult<List<Question>>` was dead
    // code, and this file's two remaining uncovered lines were its banner and this
    // arm.
    final List<Question> mappedQuestions = _questions(
      questions.valueOrElse(<Object?>[]),
    );

    // `valueOrElse` from here, not `!`: the gates above have proved there is no
    // failure arm to take, so the fallback can never be reached, and spelling it
    // this way keeps §4's "no `!` unless provably non-null" honest without an
    // ignore.
    return Result<ScriptureText>.success(
      ScriptureText(
        readingId: readingId.valueOrElse(''),
        groupId: groupId.valueOrElse(0),
        scheduledDate: scheduledDate.valueOrElse(''),
        language: language.valueOrElse(ReadingLanguage.english),
        // ## THE TWO LABEL FIELDS, AND WHY THEY ARE BLANKED RATHER THAN REFUSED
        //
        // `renderableTextOrEmpty` and not `valueOrElse('')`: both fields are painted
        // — `reading_header.dart` puts `reference` in the title and `translation` in
        // the metadata row — and the engine throws `ArgumentError: string is not
        // well-formed UTF-16` from `dart:ui`'s `addText` on a lone surrogate, so a
        // verbatim pass-through is not free.
        //
        // The alternative to blanking is not "keep the bytes", it is **refusing the
        // whole reading**, and one malformed label must not cost the reader the
        // passage. Blanking reaches a state this table already permits two rows
        // above: `reference: ''` and `translation: ''` are values the server can send
        // and this mapper has always passed through on purpose. See decision 95 in
        // `renderable_text.dart`.
        reference: renderableTextOrEmpty(reference.valueOrElse('')),
        translation: renderableTextOrEmpty(translation.valueOrElse('')),
        verses: mappedVerses.valueOrElse(<Verse>[]),
        questions: mappedQuestions,
        isFullyCompleted: isFullyCompleted.valueOrElse(false),
        pointsEarnedToday: points.valueOrElse(0),
        // The reading endpoint's **own** streak copy, which reads `4` where
        // `streak/summary` reads `0`. Carried because the payload carries it;
        // `ScriptureText.currentStreak`'s doc says why nothing reads it and why
        // removing it would be worse.
        currentStreak: streak.valueOrElse(0),
      ),
    );
  }

  /// The `verses` list as entities.
  ///
  /// Index 0 is strict; every other index is skipped when unreadable. See
  /// [mapScripture]'s table for why the asymmetry is the design and not an
  /// oversight.
  Result<List<Verse>> _verses(List<Object?> raw) {
    if (raw.isEmpty) {
      return Result<List<Verse>>.failure(
        _bad('verses', raw, 'a non-empty list'),
      );
    }

    final List<Verse> mapped = <Verse>[];
    for (int index = 0; index < raw.length; index++) {
      switch (_verseEntry(raw[index], index)) {
        case Success<Verse>(:final Verse value):
          mapped.add(value);
        case FailureResult<Verse>(:final Failure failure):
          if (index == 0) return Result<List<Verse>>.failure(failure);
      }
    }

    return Result<List<Verse>>.success(mapped);
  }

  /// One entry of the `verses` list.
  ///
  /// The only thing this adds is the non-object refusal, because a bare string in
  /// the `verses` array is what a malformed response looks like and the message
  /// has to name the position — `verses[2]`, not `verses`.
  Result<Verse> _verseEntry(Object? entry, int index) {
    if (entry is! Map<Object?, Object?>) {
      return Result<Verse>.failure(_bad('verses[$index]', entry, 'an object'));
    }
    // The reported key is applied **once**, in [_verse], which already knows the
    // index. Renaming here as well produced `verses[0].verses[0].book_number` on the
    // first run — a message nobody debugging a payload wants to read.
    return _verse(entry, index);
  }

  /// One verse object.
  ///
  /// **`text_clean` is the only field here allowed to be absent**, and §5's trap 2
  /// is the reason: the English localized response has no such key at all. Every
  /// other field is required, because each is either a number the reader sees
  /// beside the verse or the verse itself.
  ///
  /// ## `text` IS ALSO REQUIRED TO BE **RENDERABLE**, AND THAT IS A DIFFERENT
  /// ## QUESTION FROM REQUIRED
  ///
  /// `text: ''` passes this method. `text: '\uD83D…'` does not, and the two
  /// verdicts are both deliberate — see `isRenderableText`'s table.
  ///
  /// The reason the check lives here and not in a widget is that nothing between
  /// this method and `RenderParagraph` can catch it. **The throw is real, and it is
  /// also caught** — both halves matter, and this doc once asserted only the first
  /// and then, for one draft, wrongly denied it.
  ///
  /// Measured on `Flutter 3.47.4`: the engine's `ParagraphBuilder::addText` returns
  /// an error string for a lone surrogate and `dart:ui` turns it into
  /// `ArgumentError: Invalid argument(s): string is not well-formed UTF-16` at
  /// `dart:ui/text.dart:3724`, from inside `RenderParagraph.performLayout`. The
  /// painting library **catches** it, so the frame completes — which is exactly why
  /// a probe that watched for a frame concluded there was no throw. In a test an
  /// exception left untaken fails the test, so the cost is not invisible there
  /// either.
  ///
  /// So the cost the rule removes is real and is **two** things: a tofu box where the
  /// scripture should be, and a caught `ArgumentError` on every layout of that
  /// paragraph. Skipping that row instead costs the reader one missing number. That
  /// is a smaller prize than taking the screen with it and it is still worth having.
  /// Recorded decision 80 deferred this rule to the phase that reads `text_clean`;
  /// this is it, asked once.
  Result<Verse> _verse(Map<Object?, Object?> body, int index) {
    final Result<int> bookNumber = _int(body, 'book_number');
    final Result<int> chapter = _int(body, 'chapter');
    final Result<int> number = _int(body, 'verse');
    final Result<String> text = _string(body, 'text');

    final Result<void> gate = _firstFailure(<Result<Object?>>[
      bookNumber,
      chapter,
      number,
      text,
    ]);
    if (gate case FailureResult<void>(:final Failure failure)) {
      return Result<Verse>.failure(_renamed(failure, 'verses[$index]'));
    }

    final String verseText = text.valueOrElse('');

    // **Paintability is a second gate, and it is a different gate from the type
    // check above.** A `String` that is not renderable throws from `dart:ui`'s
    // `addText` during layout — measured on `Flutter 3.47.4` — so this row is skipped
    // and a malformed verse never reaches a `Text` at all; an empty one renders as an
    // empty numbered line. Both are visible gaps, and the two verdicts are separated
    // because one of them is a sentence the reader is trying to read and the other is
    // a number with nothing beside it. `reference` and `translation` are painted too
    // and are handled by `renderableTextOrEmpty` above rather than by this gate:
    // blanking a label keeps the passage, refusing it would not. See
    // `isRenderableText`'s decision 95.
    if (!isRenderableText(verseText)) {
      return Result<Verse>.failure(
        _renamed(
          _bad('text', verseText, _renderableExpectation),
          'verses[$index]',
        ),
      );
    }

    // **`null` for absence, and the empty string for an empty value.** This is the
    // distinction §5 trap 2 and Phase 7's own verify item are about, and it is why
    // the check is `is String` and not `is String && isNotEmpty`: the *field*
    // reports what arrived and `verseDisplayText` decides what to show. A
    // `text_clean` this client cannot read as a `String` is treated as absent — the
    // same leniency `already_answered` gets, because one object read by one rule is
    // what keeps two fields of it from disagreeing about how strict this is.
    //
    // **And a `text_clean` that cannot be painted is dropped for the same reason a
    // `Verse.text` cannot be**: it reaches a `Text` through `Verse.displayText`, so
    // keeping it would move the throw one field along rather than remove it. §5 trap
    // 9's three-state rule gains a fourth state here — present, a `String`, and
    // unpaintable — and `null` is its answer, which is what `textClean`'s own doc
    // means by "the server sent no clean text". `/`'s preview falls back to `text`
    // and `/reading` renders `text` anyway, so nothing is lost on either arm.
    final Object? clean = body['text_clean'];

    return Result<Verse>.success(
      Verse(
        bookNumber: bookNumber.valueOrElse(0),
        chapter: chapter.valueOrElse(0),
        number: number.valueOrElse(0),
        text: verseText,
        textClean: clean is String && isRenderableText(clean) ? clean : null,
      ),
    );
  }

  /// The `questions` list as entities. **Nothing in here is refused** — see
  /// [mapScripture]'s table, and its "any question → **skipped**" row is the whole
  /// argument for the return type.
  ///
  /// ## WHY IT RETURNS A **LIST** AND NOT A `Result`
  ///
  /// Because it cannot fail, and a `Result` it cannot fail in is a `Failure` arm no
  /// caller can reach. The caller had exactly that:
  /// `if (mappedQuestions case FailureResult<List<Question>>(…)) return …` — dead
  /// code, and the second of this file's three unreachable lines.
  ///
  /// **The table's "`questions` not a list → **refused**" row is still true, and it
  /// is enforced one level up** by `_list(body, 'questions')`, which is where the
  /// type check belongs: this function is handed a `List<Object?>` it can already
  /// trust, and a type it is handed a checked value cannot re-check.
  List<Question> _questions(List<Object?> raw) {
    final List<Question> mapped = <Question>[];
    for (final Object? entry in raw) {
      if (entry is! Map<Object?, Object?>) continue;
      final Result<Question> question = _question(entry);
      if (question case Success<Question>(:final Question value)) {
        mapped.add(value);
      }
    }
    return mapped;
  }

  /// One question object.
  ///
  /// `id`, `sort_order`, `type`, `prompt`, `options` and `points_value` are
  /// **required**; `already_answered`, `user_answer` and `is_correct` are
  /// **lenient** and default to "not answered, no answer, no verdict". That split
  /// is §5's own response shape: it shows the first six on every question and the
  /// last three varying between `true`/`'A'` and `false`/`null`.
  ///
  /// **`prompt` and every option must also be renderable**, and they get the same
  /// verdict a malformed `verse` gets: a **skipped question**. That is not a new
  /// branch — [\_questions] already skips anything this method refuses — it is the
  /// existing skip rule reaching the two fields `/quiz` paints. A question whose
  /// text would throw out of `RenderParagraph` costs the reader that question and
  /// nothing else.
  Result<Question> _question(Map<Object?, Object?> body) {
    final Result<String> id = _string(body, 'id');
    final Result<int> sortOrder = _int(body, 'sort_order');
    final Result<String> type = _string(body, 'type');
    final Result<String> prompt = _string(body, 'prompt');
    final Result<Map<String, String>> options = _options(body);
    final Result<int> pointsValue = _int(body, 'points_value');

    final Result<void> gate = _firstFailure(<Result<Object?>>[
      id,
      sortOrder,
      type,
      prompt,
      options,
      pointsValue,
    ]);
    if (gate case FailureResult<void>(:final Failure failure)) {
      return Result<Question>.failure(failure);
    }

    final String questionPrompt = prompt.valueOrElse('');

    // The paintability gate, and it is a separate `if` from the type gate above for
    // the reason `_verse`'s is: `''` is a question with no wording and a malformed
    // one is a question that takes the screen down, and a rule that collapsed them
    // would have to pick one verdict for both.
    if (!isRenderableText(questionPrompt)) {
      return Result<Question>.failure(
        _bad('prompt', questionPrompt, _renderableExpectation),
      );
    }

    // Lenient reads, and the reasons are §5's: the endpoint sends
    // `already_answered` on every question, and a flag this client cannot read can
    // only mean "not proven answered". §5 trap 3 makes the consequence concrete — a
    // question that has actually been submitted comes back as **409**, so an
    // `already_answered == false` on one that has is visible rather than silent.
    final Object? answered = body['already_answered'];
    final Object? answer = body['user_answer'];
    final Object? correct = body['is_correct'];

    return Result<Question>.success(
      Question(
        id: id.valueOrElse(''),
        sortOrder: sortOrder.valueOrElse(0),
        type: type.valueOrElse(''),
        prompt: questionPrompt,
        options: options.valueOrElse(const <String, String>{}),
        pointsValue: pointsValue.valueOrElse(0),
        alreadyAnswered: answered == true,
        userAnswer: answer is String ? answer : null,
        isCorrect: correct is bool ? correct : null,
      ),
    );
  }

  /// `options` — a **flat** `Map` of letter to option text (§5).
  ///
  /// Every key and every value must be a `String`. A `Map<String, dynamic>` whose
  /// values are not all strings is unreadable rather than coercible, because the
  /// alternative — `'$value'` — would invent an option label the server never sent
  /// and the reader would answer a question that was not asked.
  Result<Map<String, String>> _options(Map<Object?, Object?> body) {
    final Object? value = body['options'];
    if (value is! Map<Object?, Object?>) {
      return Result<Map<String, String>>.failure(
        _bad('options', value, 'an object of String to String'),
      );
    }
    final Map<String, String> mapped = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final Object? key = entry.key;
      final Object? option = entry.value;
      if (key is! String || option is! String) {
        return Result<Map<String, String>>.failure(
          _bad('options', value, 'an object of String to String'),
        );
      }
      // The same paintability gate as `text` and `prompt`, for the same reason:
      // `/quiz` puts every option on screen through a `Text`.
      if (!isRenderableText(option)) {
        return Result<Map<String, String>>.failure(
          _bad('options.$key', option, _renderableExpectation),
        );
      }
      mapped[key] = option;
    }
    return Result<Map<String, String>>.success(mapped);
  }

  /// [body] to a [TodayReading] — `/`'s narrow projection.
  ///
  /// **A narrowing of [mapScripture], and nothing else.** The first version of this
  /// method parsed the body itself, which meant the scalar table in the class doc
  /// existed in two places free to disagree — and `text_clean`'s
  /// absent-versus-empty rule would have had a second spelling. Recorded decision
  /// 23 chose one mapper over two repositories, and this is the shape that choice
  /// takes.
  ///
  /// Never throws; [Failure.message] names the key and what was expected.
  Result<TodayReading> map(Object? body) =>
      mapScripture(body)
          .map((ScriptureText scripture) => scripture.toTodayReading());

  /// [failure] with its reported key rewritten to [prefix].`field`.
  ///
  /// String surgery on a message is the wrong shape in general and the right shape
  /// here, and the reason is that there is exactly **one** message format in this
  /// file: [_bad] is the only producer of a `FailureKind.serialization` whose
  /// message names a key. So there is one template to rewrite and not a family.
  ///
  /// **Why not a `reportKey` parameter on the typed readers instead.** Because
  /// `_int(body, 'chapter')` would then carry two keys — the one it reads and the
  /// one it reports — and every call site would pass both, and the two would drift
  /// apart silently the first time someone typed the reported key where the wire key
  /// belonged. The wire key stays the reader's only argument and the position is
  /// applied once, on the way out.
  Failure _renamed(Failure failure, String prefix) {
    const String open = '`';
    final int start = failure.message.indexOf(open);
    if (start < 0) return failure;
    final int end = failure.message.indexOf(open, start + 1);
    if (end < 0) return failure;
    return Failure(
      kind: failure.kind,
      message: failure.message.replaceRange(
        start,
        end + 1,
        '$open$prefix.${failure.message.substring(start + 1, end)}$open',
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

  /// What [\_bad] says when the value is a `String` that cannot be painted.
  ///
  /// **The diagnosis is named, not just the type.** "a `String` was expected" is
  /// what the reader already knows — the wire sent a string — and it sends them
  /// looking for a schema problem when the actual defect is an encoder that emitted
  /// half a code point. `isRenderableText`'s doc carries the whole argument;
  /// `today_reading_mapper_test.dart` asserts this word is in the message.
  static const String _renderableExpectation =
      'a String that can be rendered (well-formed UTF-16)';
}
