import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:fpdart/fpdart.dart';

/// The two question routes' wire shapes, in both directions.
///
/// ## THE ASYMMETRY IS THE WHOLE JOB
///
/// The wire speaks **snake_case** (`reading_id`, `prompt_ar`, `prompt_en`,
/// `correct_answer`, `points_value`, `sort_order`, `is_approved`) and the domain
/// speaks **camelCase**. Every key below is transcribed from
/// `admin.routes.ts:35-50` (the commit schema) and `ai.routes.ts:8-11` (the AI
/// schema).
///
/// ## AND THE DRAFT'S OPTIONS HAVE THE **SAME SHAPE** AS THE COMMIT'S
///
/// `ai.service.ts:9` types `GeneratedQuestionPayload.options` as
/// `Record<string, { ar: string; en: string }>`, and `admin.routes.ts:41-44`
/// types the commit's `options` the same way. That is what makes a draft
/// **editable and committable without a conversion** — the design spec §6.1's
/// third door into a question — and it is why the two bodies are built by the
/// same class.
///
/// ## AND WHY THIS IS ONE CLASS FOR TWO ENDPOINTS
///
/// §3's SRP row: a mapper owns one body. These are two bodies, and they are
/// **one subject** — a question, and the three shapes it travels in. The
/// alternative — a third mapper for the AI route — would put the draft's
/// option shape in a second file, and the two would be free to disagree about
/// what an option is.
final class QuestionMapper {
  /// Creates a mapper. Stateless and `const`.
  const QuestionMapper();

  /// The commit endpoint, including the `/api/v1` prefix.
  static const String commitEndpoint = '/api/v1/admin/questions/commit';

  /// The AI-draft endpoint, including the `/api/v1` prefix.
  static const String aiGenerateEndpoint =
      '/api/v1/admin/questions/ai-generate';

  /// The request body for committing [questions] against [readingId].
  ///
  /// ## AND `options` IS **OMITTED** FOR A QUESTION THAT HAS NONE
  ///
  /// The schema's `options` is optional (`admin.routes.ts:44`) and the server
  /// stores `JSON.stringify(q.options || null)` (`:304`) — so a question with
  /// no options is stored with a **null**, and an empty object would be stored
  /// as `{}`. Omitting the key is how the client says "no options" the way the
  /// server's own default does.
  static Map<String, Object?> commitBodyFor({
    required String readingId,
    required List<QuestionDraft> questions,
  }) => <String, Object?>{
    'reading_id': readingId,
    'questions': <Map<String, Object?>>[
      for (final QuestionDraft question in questions) _questionBody(question),
    ],
  };

  /// One question's own body.
  static Map<String, Object?> _questionBody(QuestionDraft question) {
    final Map<String, Object?> body = <String, Object?>{
      'type': question.type.wireValue,
      'prompt_ar': question.promptAr,
      'prompt_en': question.promptEn,
      'correct_answer': question.correctAnswer,
      'points_value': question.pointsValue,
      'sort_order': question.sortOrder,
      'is_approved': question.isApproved,
    };
    if (question.options.isNotEmpty) {
      body['options'] = <String, Object?>{
        for (final MapEntry<String, QuestionOption> option
            in question.options.entries)
          option.key: <String, Object?>{
            'ar': option.value.ar,
            'en': option.value.en,
          },
      };
    }
    return body;
  }

  /// The request body for an AI draft about [readingId] of [type].
  ///
  /// ## AND A `short_answer` IS **REFUSED HERE**, BEFORE THE REQUEST
  ///
  /// `ai.routes.ts:10` types the request's `type` as
  /// `z.enum(['mcq', 'true_false'])` — a `short_answer` is a **400** there.
  /// The domain's [QuestionType] has three members, because the **commit**
  /// route accepts three (`admin.routes.ts:38`); the AI route is narrower.
  ///
  /// The refusal is made here rather than in the adapter, because here is where
  /// the endpoint's vocabulary is known: a body builder that could build an
  /// invalid body would be a request the server refuses with a message about a
  /// field the client chose deliberately.
  ///
  /// The failure's kind is [FailureKind.validation] — "the request was
  /// malformed" — because that is exactly what it would have been.
  static Result<Map<String, Object?>> aiGenerateBodyFor({
    required String readingId,
    required QuestionType type,
  }) {
    if (type == QuestionType.shortAnswer) {
      return Result<Map<String, Object?>>.left(
        const Failure(
          kind: FailureKind.validation,
          message:
              'The AI draft endpoint only generates multiple-choice and '
              'true/false questions, so a short answer cannot be drafted.',
        ),
      );
    }
    return Result<Map<String, Object?>>.of(<String, Object?>{
      'reading_id': readingId,
      'type': type.wireValue,
    });
  }

  /// Maps the commit route's `201` body to a [CommitResult].
  ///
  /// Never throws. A 2xx body that cannot be read is
  /// [FailureKind.serialization].
  Result<CommitResult> mapCommitResult(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<CommitResult>.left(_notAnObject(body));
    }

    final Result<String> message = _string(body, 'message');
    final Result<List<String>> questionIds = _stringList(body, 'question_ids');

    final Result<void> gate = _firstFailure(<Result<Object?>>[
      message,
      questionIds,
    ]);
    if (gate case Left<Failure, void>(value: final failure)) {
      return Result<CommitResult>.left(failure);
    }

    return Result<CommitResult>.of(
      CommitResult(
        message: message.getOrElse((_) => ''),
        questionIds: questionIds.getOrElse((_) => const <String>[]),
      ),
    );
  }

  /// Maps the AI route's `200` body to a [QuestionDraft].
  ///
  /// ## AND THE THREE FIELDS THE DRAFT DOES NOT CARRY ARE THE COMMIT SCHEMA'S
  /// **OWN DEFAULTS**
  ///
  /// The AI route returns five fields (`ai.routes.ts:31-40`) and the commit
  /// schema declares three more with defaults — `points_value` 10,
  /// `sort_order` 1, `is_approved` true (`admin.routes.ts:46-48`). The draft
  /// carries those three, which is what makes a draft **committable without a
  /// conversion**: the editor hands the draft straight to the commit body.
  ///
  /// The defaults are the **server's**, not this client's invention — and the
  /// server would apply exactly these if the client sent the keys with the
  /// same values.
  Result<QuestionDraft> mapDraft(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<QuestionDraft>.left(_notAnObject(body));
    }

    final Object? rawDraft = body['draft_question'];
    if (rawDraft is! Map<Object?, Object?>) {
      return Result<QuestionDraft>.left(
        _bad('draft_question', rawDraft, 'a JSON object'),
      );
    }

    final Result<QuestionType> type = _type(rawDraft, 'type');
    final Result<String> promptAr = _string(rawDraft, 'prompt_ar');
    final Result<String> promptEn = _string(rawDraft, 'prompt_en');
    final Result<String> correctAnswer = _string(rawDraft, 'correct_answer');
    final Result<Map<String, QuestionOption>> options = _options(
      rawDraft,
      'options',
    );

    final Result<void> gate = _firstFailure(<Result<Object?>>[
      type,
      promptAr,
      promptEn,
      correctAnswer,
      options,
    ]);
    if (gate case Left<Failure, void>(value: final failure)) {
      return Result<QuestionDraft>.left(failure);
    }

    return Result<QuestionDraft>.of(
      QuestionDraft(
        type: type.getOrElse((_) => QuestionType.mcq),
        promptAr: promptAr.getOrElse((_) => ''),
        promptEn: promptEn.getOrElse((_) => ''),
        options: options.getOrElse((_) => const <String, QuestionOption>{}),
        correctAnswer: correctAnswer.getOrElse((_) => ''),
        // The commit schema's own defaults — `admin.routes.ts:46-48`.
        pointsValue: 10,
        sortOrder: 1,
        isApproved: true,
      ),
    );
  }

  // --- typed reads ----------------------------------------------------------

  /// Reads [key] out of [body] as a string.
  ///
  /// [path] is the **field's path in the body**, and it defaults to [key]
  /// because a top-level field's path *is* its key. A nested field has to
  /// say where it came from: the option's two halves are read by this same
  /// reader, and a refusal that said only `ar` would name the field without
  /// naming the option that carried it — the same sentence for every option
  /// in the draft, and a reader unable to tell which one was wrong.
  Result<String> _string(
    Map<Object?, Object?> body,
    String key, {
    String? path,
  }) {
    final Object? value = body[key];
    return value is String
        ? Result<String>.of(value)
        : Result<String>.left(_bad(path ?? key, value, 'a String'));
  }

  Result<List<String>> _stringList(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    if (value is! List<Object?>) {
      return Result<List<String>>.left(_bad(key, value, 'a list of strings'));
    }
    final List<String> strings = <String>[];
    for (int index = 0; index < value.length; index++) {
      final Object? entry = value[index];
      if (entry is! String) {
        return Result<List<String>>.left(
          _bad('$key[$index]', entry, 'a String'),
        );
      }
      strings.add(entry);
    }
    return Result<List<String>>.of(strings);
  }

  /// The question's type, refused when the client does not know it.
  ///
  /// The server's union is three values (`admin.routes.ts:38`), and a fourth
  /// would be a server change this client has to be told about — not something
  /// to guess. `QuestionType.fromWire` returns `null` for that reason.
  Result<QuestionType> _type(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    if (value is! String) {
      return Result<QuestionType>.left(_bad(key, value, 'a String'));
    }
    final QuestionType? type = QuestionType.fromWire(value);
    return type == null
        ? Result<QuestionType>.left(
            _bad(key, value, 'one of mcq, true_false, short_answer'),
          )
        : Result<QuestionType>.of(type);
  }

  /// The draft's options — `Record<string, {ar, en}>`.
  ///
  /// ## AND A MISSING `options` KEY IS A **FAILURE**, NOT AN EMPTY MAP
  ///
  /// The AI service's response schema marks `options` **required**
  /// (`ai.service.ts:103`), and its own validator refuses a draft without them
  /// (`:140-144`) — and a draft that fails the validator falls back to
  /// `generateLocalFallbackQuestion`, which always produces options
  /// (`:157-184`). So a draft without options is a body **this server cannot
  /// produce**, and reading it as "no options" would turn a server change into
  /// a silently wrong question.
  ///
  /// This is `SubmitResultMapper`'s rule applied unchanged: *"This payload has
  /// no such documented absence, so there is nothing to be lenient about, and a
  /// lenient read here would be a guess about a body nobody can observe."*
  ///
  /// An **empty** map is still legal — it is the domain's one representation of
  /// "a question with no options", and the commit body omits the key for it.
  ///
  /// ## AND EVERY REFUSAL HERE NAMES THE **FIELD'S PATH**
  ///
  /// The option is a map keyed by its **letter**, and the letter is knowable:
  /// it is the key the body carries. So the refusal says `options.A.ar` and
  /// not `ar` — the same spelling `options.A` already had, one level deeper.
  ///
  /// The bare `ar` was a finding and not a design: a draft with four options
  /// and one broken half produced **the same sentence for all four**, and a
  /// reader could not tell which option was wrong. Every other field in the
  /// three mappers names its path — `students[0]`, `reading_ids[0]` — and this
  /// one now does too.
  Result<Map<String, QuestionOption>> _options(
    Map<Object?, Object?> body,
    String key,
  ) {
    final Object? value = body[key];
    if (value == null) {
      return Result<Map<String, QuestionOption>>.left(
        _bad(key, null, 'a JSON object of options'),
      );
    }
    if (value is! Map<Object?, Object?>) {
      return Result<Map<String, QuestionOption>>.left(
        _bad(key, value, 'a JSON object of options'),
      );
    }

    final Map<String, QuestionOption> options = <String, QuestionOption>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final Object? label = entry.key;
      final Object? option = entry.value;
      if (label is! String) {
        return Result<Map<String, QuestionOption>>.left(
          _bad(key, label, 'a String key'),
        );
      }
      if (option is! Map<Object?, Object?>) {
        return Result<Map<String, QuestionOption>>.left(
          _bad('$key.$label', option, 'a JSON object'),
        );
      }
      final Result<String> ar = _string(option, 'ar', path: '$key.$label.ar');
      final Result<String> en = _string(option, 'en', path: '$key.$label.en');
      if (ar case Left<Failure, String>(value: final failure)) {
        return Result<Map<String, QuestionOption>>.left(failure);
      }
      if (en case Left<Failure, String>(value: final failure)) {
        return Result<Map<String, QuestionOption>>.left(failure);
      }
      options[label] = QuestionOption(
        ar: ar.getOrElse((_) => ''),
        en: en.getOrElse((_) => ''),
      );
    }
    return Result<Map<String, QuestionOption>>.of(options);
  }

  /// The first failure among [results], as a `Result<void>` so the caller
  /// pattern-matches once instead of checking every local.
  Result<void> _firstFailure(List<Result<Object?>> results) {
    for (final Result<Object?> result in results) {
      if (result case Left<Failure, Object?>(value: final failure)) {
        return Result<void>.left(failure);
      }
    }
    return const Right<Failure, void>(null);
  }

  /// Why a body that is not an object is named by *what it was*.
  ///
  /// `SubmitResultMapper._notAnObject`'s three named cases, for the same three
  /// reasons, and the wording is the operation's own so a reader can tell which
  /// of this client's requests failed.
  Failure _notAnObject(Object? body) => Failure(
    kind: FailureKind.serialization,
    message: switch (body) {
      null =>
        'Could not read the question from $commitEndpoint: the response body was '
            'empty. A 200 with no body is what a proxy returns when it swallows '
            'the upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        'Could not read the question from $commitEndpoint: the response body is an '
            'HTML document (${text.length} characters), not JSON. Something '
            'between the app and the backend answered instead of it.',
      final Object other =>
        'Could not read the question from $commitEndpoint: the response body is a '
            '${other.runtimeType}, not a JSON object.',
    },
  );

  /// The refusal that names the field that was wrong.
  ///
  /// [path] is the field's **path in the body** — a top-level field's path is
  /// its key, and a nested one says where it came from (`options.A.ar`).
  /// The path is what makes two refusals about the same *kind* of field
  /// distinguishable: `ar` and `en` are the two halves of every option, and a
  /// draft with four options has eight of them.
  Failure _bad(String path, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        'Could not read the question from $commitEndpoint: `$path` is '
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
