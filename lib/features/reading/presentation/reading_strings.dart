import 'package:evangelion/features/reading/domain/arabic_digits.dart';
import 'package:flutter/widgets.dart';

/// The bilingual string table for `/reading`.
///
/// ## WHY IT IS HAND-WRITTEN
///
/// `gen_l10n` needs `flutter: generate: true` in `pubspec.yaml`, and AGENT_CONTEXT
/// §8.4 makes an unlisted change a hard stop. So this is Dart, exactly as
/// `LoginStrings` and `HomeStrings` are, and it carries their stated cost: adding a
/// language means adding a class here and **nothing checks that the two arms agree
/// in arity**. `reading_strings_test.dart` checks the property a reader would
/// notice — no Latin script in the Arabic arm, no empty value, the same field
/// names — by walking [fields].
///
/// ## WHAT IS **TRANSCRIBED**, LINE BY LINE
///
/// | field | prototype |
/// | --- | --- |
/// | [beginReflection] | `ReadingEnScreen.tsx:87` — `Begin reflection`; `ReadingArScreen.tsx:85` — `ابدأ التأمل` |
///
/// That is the whole of it, and the shortness is the finding: the prototype's four
/// other strings on this screen are **fake data** or **invented numbers**.
///
/// ## THE FOUR STRINGS THAT ARE **NOT** HERE, AND WHY
///
/// | prototype | what replaced it |
/// | --- | --- |
/// | `Genesis · Chapter 1 · 4 min` (`:31`) | the payload's `translation`, verbatim. **No duration**: `GET /readings/today/{lang}` has no duration field anywhere (verified live against `HEAD = 4a1c834`), and deriving one from a word count is inventing a measurement. |
/// | `The Beginning` (`:38`) / `البداية` (`:42`) | the payload's `reference`, verbatim. **No passage name**: the API returns a citation, not a title. |
/// | `5 questions · about a minute` (`:89`) | [captionFor] — the question count, pluralised. The count is real (`questions.length`); the duration has no source and is gone. |
/// | `التكوين · الإصحاح ١ · ٤ دقائق` (`:36`) | the same, on the Arabic arm. |
///
/// **And `reference` is rendered, never parsed.** It arrives display-formatted per
/// language — `John 3:1-5` against `يوحنا 3: 1-5`, with a space after the Arabic
/// colon — and the tempting move is to split it into book / chapter / verses to
/// build a heading. Rejected: `Verse.bookNumber` is the server's own answer to that
/// question, and a hand-rolled parser for a string the backend already formats is a
/// new failure surface with no second source of truth to check it against.
///
/// ## AND NO ANSWER, NO SCORE AND NO DATE IS HERE
///
/// `Question.prompt`, `Question.options`, `Question.userAnswer`,
/// `Question.isCorrect`, `ScriptureText.pointsEarnedToday` and
/// `ScriptureText.scheduledDate` are all on the payload and none is a string on this
/// screen. The first four because `/reading` renders **verses only** — the reading
/// response ships `user_answer` and `is_correct` with the question (verified live),
/// so drawing them there would spoil `QuizPage` before the reader has chosen. See
/// `question.dart`'s doc and `reading_page_test.dart`'s gate. The last two because a
/// reading screen is not a scoreboard and §2's route table gives `/result` the score.
final class ReadingStrings {
  /// The strings for [locale].
  ///
  /// Falls back to [en] for anything that is not `ar`, for `LoginStrings.of`'s and
  /// `HomeStrings.of`'s reason: `app.dart` declares exactly two `supportedLocales`,
  /// so the fallback is unreachable through `MaterialApp.locale` and exists for a
  /// widget pumped outside one — which several suites do.
  static ReadingStrings of(Locale locale) => switch (locale.languageCode) {
    'ar' => const ReadingStrings.ar(),
    _ => const ReadingStrings.en(),
  };

  /// The English arm.
  const ReadingStrings.en()
    : back = 'Back',
      textSize = 'Text size',
      bookmark = 'Bookmark',
      beginReflection = 'Begin reflection',
      unavailableSuffix = 'unavailable in this build',
      passage = 'Scripture passage',
      verse = 'Verse',
      retry = 'Try again',
      questionSingular = 'question',
      questionPlural = 'questions';

  /// The Arabic arm.
  ///
  /// Written, not transcribed: `HomeStrings.ar` says the same, and the reason is
  /// that the prototype is English only. Every field is checked for Latin script by
  /// `reading_strings_test.dart`, which walks [fields].
  const ReadingStrings.ar()
    : back = 'رجوع',
      textSize = 'حجم الخط',
      bookmark = 'إشارة مرجعية',
      beginReflection = 'ابدأ التأمل',
      unavailableSuffix = 'غير متاح في هذه النسخة',
      passage = 'نص الآية',
      verse = 'الآية',
      retry = 'حاول مرة أخرى',
      // Arabic has no separate singular and plural *count noun* the way English
      // does, and the full agreement classes are 1 / 2 / 3–10 / 11+. See
      // [captionFor] for exactly what is implemented and what is not.
      questionSingular = 'سؤال واحد',
      questionPlural = 'أسئلة';

  /// The back control's accessible name. `ReadingEnScreen.tsx:14-16` and
  /// `ReadingArScreen.tsx:26-28` are `<button>`s wrapping an inline `<svg>`
  /// chevron with nothing at all — §14's first row, verbatim.
  final String back;

  /// The `Aa` control's accessible name.
  ///
  /// **Not `Aa`.** §14's first row lists `Aa` among the icon-only buttons that have
  /// no accessible name, and `IconActionButton`'s own doc names it as one of "the
  /// `Aa` and bookmark controls Phase 7 composes" — which is why this control is
  /// that widget with a `Text size` tooltip rather than a text button whose label is
  /// its own name.
  final String textSize;

  /// The bookmark control's accessible name, before any suffix.
  final String bookmark;

  /// The sticky CTA. `ReadingEnScreen.tsx:87` — `ButtonPrimary` with
  /// `Begin reflection`; `ReadingArScreen.tsx:85` — `ابدأ التأمل`.
  final String beginReflection;

  /// Appended to a control's name while that control is inert.
  ///
  /// The same wording, and the same reasoning, as `LoginStrings` and `HomeStrings`:
  /// a reader should be told **why** a control cannot be pressed, not only that it
  /// cannot. The bookmark has no endpoint and no port (`ReadingEnScreen.tsx:19-21`
  /// draws one with no handler), so it ships inert and says so.
  final String unavailableSuffix;

  /// `ScriptureBlock`'s accessible name.
  final String passage;

  /// The prefix for a verse marker's accessible name, as in `Verse 3`.
  final String verse;

  /// `ErrorView.retryLabel`. The prototype has no error state at all — `eva/src`
  /// has no data layer that can fail — so this is written.
  final String retry;

  /// The caption's noun when the count is exactly **one**.
  ///
  /// English's singular. Arabic's is a **phrase**, `سؤال واحد` ("one question"),
  /// because the numeral `١` alone plus a plural noun is ungrammatical and a
  /// numeral plus a bare singular noun reads as a label rather than a count.
  final String questionSingular;

  /// The caption's noun for every other count. English's plural, and Arabic's
  /// 3–10 plural `أسئلة` — the class `ReadingArScreen.tsx:87`'s `٥ أسئلة` is in.
  final String questionPlural;

  /// The sticky CTA's caption for [count] questions.
  ///
  /// ## PLURALISED, AND THE BOUNDARY IS `== 1`
  ///
  /// `ReadingEnScreen.tsx:89` hard-codes `5 questions` and the live reading carries
  /// **one** question, so the prototype's literal is false by a factor of five and a
  /// hard-coded `5` would be fake data that happens to match nothing the server
  /// sends. Both arms therefore derive the string from `questions.length`.
  ///
  /// ## WHAT IS DELIBERATELY **NOT** IMPLEMENTED, AND IT IS A LIMITATION
  ///
  /// **Arabic plural agreement has four classes** — `1` singular, `2` dual
  /// (`سؤالان`), `3…10` plural (`أسئلة`), `11…99` singular accusative
  /// (`سؤالًا`) — and this table implements the **one** boundary, `== 1`. So
  /// `captionFor(2)` is `٢ أسئلة`, where correct Arabic is `٢ سؤالان`.
  ///
  /// That is a real gap and it is chosen, because:
  ///
  /// * `HomeStrings.streakLabel` already declined the same decision — "inventing
  ///   Arabic dual and plural forms is a localisation decision this phase may not
  ///   make" — and this is the same decision with a bigger table;
  /// * the live payload carries **one** question, so the one class this table
  ///   implements is the class the app is actually in;
  /// * every other class needs a number this client has never seen, and inventing
  ///   grammar for a payload you have not seen is the same error as inventing a
  ///   duration.
  ///
  /// Phase 9 owns `/settings`' reading preferences and is where a localisation pass
  /// belongs. **This is recorded as debt, not claimed as correct**, and the test
  /// above states the boundary rather than leaving it to be discovered.
  ///
  /// ## AND THE NUMERAL IS **ARABIC-INDIC** ON THE ARABIC ARM
  ///
  /// `ReadingArScreen.tsx:86-87` writes `٥`. Transcribed through
  /// `arabicIndicDigits`, which is also why this string must be rendered in
  /// `Amiri`: **U+0665 is an Arabic-block codepoint**, so it is tofu in Space Mono
  /// for the same reason the scripture is.
  ///
  /// **A count below one takes the plural arm.** `questionCount == 0` is reachable —
  /// `TodayReadingMapper` maps an empty `questions` list rather than refusing it —
  /// and `0 questions` is the honest English for it. Arabic's `٠ أسئلة` is in the
  /// same agreement class as `٥ أسئلة`.
  String captionFor(int count) => count == 1
      ? _count(count) + _space + questionSingular
      : _count(count) + _space + questionPlural;

  /// The count, in this arm's numerals.
  ///
  /// A method and not an `if` inside [captionFor] because the *only* difference
  /// between the arms is which digits they use, and one named function is where a
  /// reader looks for that.
  String _count(int value) => isArabic ? arabicIndicDigits(value) : '$value';

  /// Whether this arm renders Arabic-Indic numerals.
  ///
  /// **Not a stored field.** A `bool` field would be a second source of truth for
  /// the same fact as [questionSingular] / [questionPlural] being Arabic, and the two
  /// could disagree — the numeral system of the caption and its noun are one
  /// decision. Comparing the noun against the English one is the same fact read
  /// from the other side, and it cannot drift from the strings it governs.
  bool get isArabic =>
      questionPlural == const ReadingStrings.ar().questionPlural;

  /// The space between the count and the noun.
  ///
  /// A constant and not a literal in [captionFor] because §4's "named constants"
  /// habit and because a bilingual table is the one place a reader will look for
  /// "is this arm's spacing right". `HomeStrings.greetingSeparator` is the
  /// precedent, and it is a **field** there because the two arms genuinely differ
  /// there; here they do not, so a constant is honest.
  static const String _space = ' ';

  /// Every `(name, value)` pair, for the arm-comparison test.
  ///
  /// `home_strings_test.dart` has the same accessor and the same reason for it: a
  /// hand-written list inside a test is a second declaration of the table, free to
  /// drift from it, and a field added here without a row would be invisible.
  List<(String, String)> get fields => <(String, String)>[
    ('back', back),
    ('textSize', textSize),
    ('bookmark', bookmark),
    ('beginReflection', beginReflection),
    ('unavailableSuffix', unavailableSuffix),
    ('passage', passage),
    ('verse', verse),
    ('retry', retry),
    ('questionSingular', questionSingular),
    ('questionPlural', questionPlural),
  ];
}
