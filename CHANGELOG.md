# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The full history is in the commit log. It spans 81 commits from 2026-10-02 to
2026-10-11, one branch per build phase merged to `main` at each gate.

## [Unreleased]

### Changed

A major UI overhaul is planned, and the design-system decisions behind it are
still under review. Nothing in the `1.0.0` section below is deprecated, and
nothing should be treated as such yet — no decision in this project has been
reversed. The plan is tracked in [`ROADMAP.md`](ROADMAP.md), and the four
affected decisions are
[ADR-0016](docs/adr/0016-dark-glassmorphic-design-system.md) through
[ADR-0019](docs/adr/0019-performance-budget.md), each carrying the status
`accepted — under review`.

## [1.0.0] - 2026-10-11

First and only release so far. Everything below shipped; there are no
unreleased notes folded in here.

### Added

Everything below is new in this release. The eleven build phases are listed in
delivery order, followed by the leaderboard and role work that landed after
them and the gate suite that holds all of it in place.

#### Screens

All seven screens shipped, each a routed page.

| Route | Screen | Where its data comes from |
| --- | --- | --- |
| `/login` | Onboarding and sign-in | Local. No backend call exists. |
| `/` | Home — greeting, streak, today's reading, leaderboard preview | Live API |
| `/reading` | Reading sanctuary, English and Arabic | Live API |
| `/quiz` | Quiz with per-question feedback | Live API |
| `/result` | Score, streak, stat tiles | The quiz submit response |
| `/settings` | Appearance, reading, about | Local, `shared_preferences` |
| `/leaderboard` | Group ranking by window | Live API |

#### Architecture

Feature-first clean architecture with the dependency direction held strictly
inward: `presentation → domain ← data`.

- A pure-Dart shared kernel at `lib/core/domain/` holding the four repository
  ports — `ReadingRepository`, `StreakRepository`, `AuthRepository`,
  `SettingsRepository` — and every entity consumed by two or more features.
- Every `features/*/domain/` is pure Dart: no Flutter, no Dio, no HTTP.
- A mechanically enforced rule that no feature imports another feature, and
  that `lib/core/` and `lib/l10n/` import no feature at all.

#### Error handling

Three pieces, one of them a `typedef` rather than a class.

- `Result<T>`, a `typedef` over `fpdart`'s `Either<Failure, T>`, so a `switch`
  over a result is still an exhaustive switch expression with no `default`
  arm.
- A hand-written `Failure` that keeps its own `==` and `hashCode` — excluding
  `details` — and a `toString` that omits `details`.
- A dual-shape API error mapper. The second shape is **defensive** and is
  labelled as such in the test group that covers it, because no response the
  server can currently produce has it.

#### State, dependency injection, and routing

Immutable state, a locator, and a router.

- `freezed` for immutable states, events, and domain entities — 34 types, of
  which 17 are classes, 14 are events, and 3 are sealed event bases.
- `get_it` with `injectable` for DI, across seven DI modules.
- `auto_route` for the router: seven routed routes, a catch-all redirect, and
  nine route-name constants.

#### Localization

Localization moved from hand-written tables to the framework's own
pipeline, which is what made Arabic plurals correct rather than
hand-counted.

- ARB files plus `flutter gen-l10n`, replacing five hand-rolled `*Strings`
  tables.
- 111 keys per locale across `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`,
  including 3 ICU plural forms. Arabic now gets real plural categories instead
  of hand-counted strings, which also fixed at least one wrong Arabic plural
  the old table had baked in.
- The three generated `lib/l10n/app_localizations*.dart` files are committed
  and formatted, so a fresh clone passes the format gate.

#### Design system

The visual system, its tokens, its bundled fonts, and its motion.

- A dark glassmorphic system: 23 widgets in `lib/core/design_system/widgets/`
  and 8 token files in `lib/core/design_system/tokens/`.
- Five bundled font families as 20 static TTFs — Cormorant Garamond, EB
  Garamond, DM Sans, Amiri, and Space Mono — shipped in the binary rather than
  fetched at runtime.
- A neural background, glass surfaces, and a decorative effects tier that is
  kept off the accessibility critical path.
- Motion tokens in two families — routine and achievement — behind a single
  `EvaAnimate` wrapper that honours the reduced-motion flag, which the
  underlying animation package does not read.
- A contrast ledger gate that brackets the palette: one test pins the
  sub-AA tokens as deliberately sub-AA, and another asserts every
  text-approved token clears 4.5:1 against the **worst** surface in both
  themes rather than the nominal one.

#### Features

Two features arrived after the eleven build phases.

- **Leaderboard.** Group ranking over weekly, monthly, and all-time windows.
  The cohort size is *derived* from the rows returned rather than read off the
  reported total, so it is correct today and stays correct if the backend later
  starts reporting a true count.
- **Role mechanism.** A typed `UserRole` entity, a session role, a `RoleAccess`
  seam, and a role landing route. This is presentation only — the backend parses
  the role header and enforces nothing.

#### Verification

This is the part that is unusual for a client repository, so it is worth
stating plainly: the project ships its own gate suite, and the gates are
negative-controlled.

- `tool/verify_all.sh` — the seven fast gates in cost order, plus an opt-in
  Linux build gate, reporting `ok`, `FAIL`, or `FATAL` so that a gate which
  *could not run* is never mistaken for one that passed.
- `tool/baseline/gates.txt` — a recorded floor rather than a wish: 2507 tests
  and 98.25% line coverage, changed only by a deliberate, reviewed command.
- `tool/verify_purity.sh` — four architecture rules enforced mechanically.
- `tool/gates/citation_check.py` — every `*.tsx:NNN` prototype citation must
  still resolve to a line that says what the claim said it said.
- `tool/gates/orphan_widget_check.py` — a widget must be reachable from a page,
  catching the case where a component is built, wired, and tested but no screen
  ever instantiates it.
- `tool/verify_gates_selftest.sh` — plants a violation and proves each gate
  actually fires.
- `tool/verify_linux_build.sh` — runs `flutter doctor`, checks the four tools
  it does not, wipes the native build state, and asserts the bundle is not
  older than the newest source.

### Changed

Migrations and corrections to decisions made earlier in the build.

- **`Result<T>` is now an alias rather than a hand-written class.** The
  migration was breaking at every repository seam; the sealed exhaustiveness
  that the hand-written type provided was verified to survive the `typedef`.
- **Localization resolution moved to `context.l10n`** in five `build` methods,
  replacing the `X.of(Localizations.localeOf(ctx))` pattern. The manual
  locale re-dispatch stays: it is a corpus re-fetch, not a string resolution,
  and emptying it fails tests.
- **`flutter_animate` is pinned to `4.5.2` exactly**, with no caret, while every
  other dependency uses one.
- **The accent splits into a fill token and an ink token**, one pair per role.
  Only the light values differ; in dark the pairs are identical on purpose, so
  a change to one cannot silently alter the theme that was already right.
- **`ink3` is demoted to the two things WCAG exempts by name** — inactive
  components and pure decoration — and 21 text and icon runs were promoted to
  `ink2`.
- **`flutter build linux --release` left the gate list** and was replaced by
  `tool/verify_linux_build.sh`, after it reported success while compiling
  nothing.
- **`SealFab` returned to `/`** with two live destinations, and no additional
  blur layer.

### Fixed

Defects found by review, by mutation, and by the gates themselves.

- **A password was being printed.** `AuthPasswordChanged` interpolated the
  reader's typed password into its `toString`, writing it into every log line
  and every failed assertion. Secret masking is now enforced by a *structural*
  test that scans `lib/` for any class holding a password field, rather than by
  a list someone has to remember to extend.
- **Six controls were readable but not activatable**, and two goldens were dark
  copies of their light counterparts rather than distinct captures.
- **A double sign-in crashed the app**, and a documented wildcard-route
  invariant turned out to be false.
- **Sign-in could resume by accident**, behind a caching seam that 1200 tests
  could not see.
- **The home screen reported four things the backend did not say**, and the
  reading screen silenced the reader in two ways.
- **The Arabic arm of three shipped screens rendered tofu while the suite was
  green.** Testing a widget in English never renders a glyph the face lacks.
- **Typed text sat 14px above its hint, and a scrim covered the verses.**
- **The leaderboard card was written, DI-wired, given an overflow matrix and a
  21-test view suite, and no page instantiated it.** Three suites were green,
  correct about their own subject, and together could not tell whether the
  feature had shipped. Placing it then exposed Arabic tofu on the first screen
  every reader lands on.
- **The role decoder's test set could not detect a decoder that accepts a wider
  set than the protocol declares** — the exact fault the type exists to
  prevent — and a round-trip assertion closed over its own output.
- **Coverage was 97.22%** because four value classes had never been compared
  with each other.
- **`ErrorView` asserted on a failure path that a successful build never
  reaches.** The build was clean, `dart analyze` was clean, and the screen
  would have thrown the first time it actually failed.

### Removed

Code and dependencies taken out of the tree.

- **`equatable`.** It is not a direct dependency any more, and it is not
  transitive either — `pubspec.lock` carries zero occurrences of it. `Failure`
  and `Result<T>` were the last two types that needed an equality library, and
  both now hand-write their own.
- **The five hand-rolled `*Strings` localization tables**, replaced by ARB.
- **`EvaChip`**, along with its test suite, 8 goldens, and its design-system
  export. Both of the prototype's call sites were on the Library screen, which
  was cut at scope time, so the widget had no caller left by construction. It
  was built, golden-tested, and never placed — and every gate stayed green
  throughout, which is the reason a widget-reachability gate exists now.
- **The bare `flutter build linux --release` line from the verification gate
  list.**

> [!NOTE]
> Two screens in the original plan — **Library** and **Profile** — were cut
> before implementation rather than removed from a shipped release. The backend
> has no endpoints for either, so shipping them would have meant inventing
> screens. They are recorded here because a plan document still names them.
