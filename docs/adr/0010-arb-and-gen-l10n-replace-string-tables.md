# ADR-0010: Replace the hand-rolled string tables with ARB and gen_l10n

- **Status:** accepted
- **Date decided:** 2026-10-05
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §2.1 decision 8b, decisions 101–111

## Context

Five hand-rolled `*Strings` tables — `LoginStrings`, `HomeStrings`, `QuizStrings`,
`ReadingStrings`, `ResultStrings` — each a Dart class of `static const String`, each
resolving through `X.of(Localizations.localeOf(ctx))`. A sixth feature, `/settings`,
never had one. Three claims were written down **before** the migration, and **all
three turned out to be wrong**. That correction is the substance of this ADR.

## Decision

`lib/l10n/app_en.arb` and `app_ar.arb` replace the tables; the three generated
`app_localizations*.dart` files replace `X.of(...)`. Every key carries its feature
as a prefix (`homeRetry`, `quizRetry`, `readingRetry`; `authUnavailableSuffix`,
`homeUnavailableSuffix`, `quizUnavailableSuffix`, `readingUnavailableSuffix`;
`authWordmark`, `homeWordmark`).

This migration changed `pubspec.yaml` by **exactly one line**, `generate: true`, and
added **no dependency**: `flutter_localizations` (`pubspec.yaml:22`) and `intl`
(`:24`) were already declared.

Key count: **72 at migration**, measured from decisions 101 and 111. As of
2026-10-11 both ARB files carry **111** keys — the leaderboard feature added its
own. Neither figure is load-bearing; the rule is about prefixing, not counting.

## Alternatives considered

### Prefix only the three colliding names

- **Why not:** it is the cheaper rename and it leaves 66 keys that look unowned
  beside 6 that do not. The next collision would then be resolved by whoever hits
  it, under time, with no rule in the file to follow.

### One `lib/l10n/derived.dart` for the non-string logic

- **Why not:** `greetingWord` needs `GreetingPeriod`, which the placement test puts
  in `features/home/domain/`, so a shared file would make the shared kernel
  feature-dependent. **Gate 2 would not have caught it** — that is §3 forbidding
  it, which is worth knowing about the gate.

### `NumberFormat` from `intl` for the numeral system

- **Why not:** it would make a translatable key carry a locale's digits with no
  single function the tests could pin. `arabicIndicDigits` is already that
  function, and it lives in `core/domain/`.

## Consequences

### Better

- **ICU plurals, which the hand-rolled tables did not have.** This was a
  correctness gap, not an ergonomic one, and it paid off a recorded debt on arrival:
  the old `captionFor(2)` returned `٢ أسئلة` where correct Arabic is `٢ سؤالان`. The
  migration description for `readingCaptionFor` records all four Arabic agreement
  classes the old table lacked (dual `سؤالان`, 3–10 plural `أسئلة`, 11–99 singular
  accusative `سؤالًا`). Two counts became plurals — `readingCaptionFor` and
  `resultTotalCaption` — and decision 104 audited every other count and named it
  with a reason: streak days are a *label form*, verse counts name an index rather
  than count a set, quiz progress has no agreeing noun, and `days_to_milestone` is
  carried on `StreakSummary` and rendered nowhere. A third plural
  (`leaderboardRowSemantics`) arrived with the leaderboard feature.
- **The plural takes two placeholders**, `count` (int, the ICU selector) and
  `digits` (String, the rendered numeral). `gen_l10n` compiles `{count, plural, …}`
  by interpolating the raw Dart `int` — the generated Arabic arm literally reads
  `'$count أسئلة'` — so a single-placeholder ARB renders **Latin digits on the
  Arabic arm**, silently undoing `arabicIndicDigits`.

### Worse

- **"Compile-time key checking" was half true, and the half that is false matters.**
  A key missing from a locale file makes `flutter gen-l10n` print a hint and
  **exit 0**, emitting the template's **English** value into the Arabic class, and
  `dart analyze` reports nothing. Measured: deleting a key from `app_ar.arb` is
  caught by `test/l10n/app_localizations_test.dart`'s "both arms carry exactly the
  same keys" assertion — **2 failures**. **A missing key is a warning, not a build
  error**, and the test is what makes it red.
- **The generated `*.dart` files are committed, formatted, and `build_runner` does
  not produce them.** `gen_l10n`'s raw output is not `dart format`-clean, so the
  committed copies are the formatted ones or the formatting gate is red on a fresh
  clone. `dart run build_runner build` produces the freezed, auto_route and
  injectable outputs and **does not run `gen_l10n`**; neither does `flutter test`.
  Only `flutter gen-l10n`, `flutter pub get` and `flutter build` do.

### Neutral / noted

- **The manual locale re-dispatch did not die; the claim that it would was wrong and
  the code was left alone.** `HomePage` and `QuizPage`'s `didChangeDependencies`
  branch is `if (_requested != _language) _load()` — `quiz_page.dart:224` — and it
  is a **corpus re-fetch**, not a string resolution: a locale change must re-ask
  the API for the other arm's scripture and questions. Emptying it fails **56**
  tests. What died is the resolution *pattern*: `X.of(Localizations.localeOf(ctx))`
  in five `build` methods became `context.l10n`, and `rg 'of\(Localizations' lib/`
  now returns nothing. `didPopNext` is untouched and still load-bearing
  (`home_page.dart:326`).
- **Every key carries its reasoning and its citations, because `gen_l10n` discards
  `@key` descriptions after using them for tooling** (decision 110). Two gates hold
  it: every key needs a description over 40 characters, and 17 keys are pinned to
  the exact `file:line` they must still name. Proven by mutation — removing
  `HomeScreen.tsx:30` from one description fails one test by name.
- **Known debt, recorded and not fixed:** `progress_beads.dart:146` composes
  `': N of M complete'` in English inside `core/`, so that semantics label reaches
  a screen reader in English on the Arabic arm.

## Traceability

- `AGENT_CONTEXT.md` §2.1 decision 8b and the corrected `gen_l10n` bullets
- `AGENT_CONTEXT.md` decisions 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111
- `AGENT_CONTEXT.md` §7, "Two codegen commands, and they are not interchangeable"
- `lib/features/quiz/presentation/pages/quiz_page.dart:224`,
  `lib/features/home/presentation/pages/home_page.dart:326`
- `lib/core/design_system/widgets/progress_beads.dart:146`
- `pubspec.yaml:22,24,116`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `test/l10n/app_localizations_test.dart`
- `tool/gates/citation_check.py` — the prototype `file:line` claims in those
  descriptions are a gate, not a convention
