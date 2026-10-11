# ADR-0021: Test-drive the domain; test alongside the widgets

- **Status:** accepted
- **Date decided:** 2026-10-02
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §6

## Context

Two different testing regimes run through this repository, and they were drawn by the
owner rather than by convention. The division is deliberate, and the exemption has
one hard edge that is easy to miss.

## Decision

### Red-first is required for

domain entities · `Result<T>` and `Failure` · use cases · API models and mappers ·
the **dual-shape error mapper** · the **header interceptor** · `FakeAuthRepository` ·
the settings repository · `evaScalerFor` · the token and motion tables · **every
cubit**, using `bloc_test` + `mocktail`.

Procedure per behaviour: **write the failing test; run it and confirm it fails for the
intended reason;** implement the minimum that passes; refactor with the test green.

**A valid red means it fails for the intended reason.** A test that fails to compile,
or that fails on an unrelated assertion, is not a red — it proves the toolchain works
and nothing else. Run it and read the failure message before writing the
implementation.

### Widget and screen work is explicitly exempt

The owner exempted UI from a test-first ceremony. Widgets and screens get **behaviour
tests, widget tests and golden tests written alongside the widget** — never a
test-first ritual.

**The exemption has one hard edge: domain logic must not be buried inside a widget.**
If a widget needs a conditional or a calculation, extract it to a cubit or a pure
function and TDD that instead. A widget that computes a streak or a completion ratio
inline is untested logic wearing a `build` method, and **no gate in this repository
can see it** — §6 is the only thing standing between that and shipping.

## The worked example: `splitDropCap`, and why it is a kernel function

`splitDropCap` in `lib/core/domain/entities/drop_cap_text.dart` is a pure function in
the shared kernel **precisely because two features need it** — §3's placement test,
and §6's edge, meeting in one file.

The rule it encodes is two lines long. **The defect was in not having one copy of it.**

`String.substring` indexes **UTF-16 code units**, not characters. A character above
U+FFFF is two of them, so `substring(0, 1)` on a string that *starts* with one
returns the **high surrogate alone** — measured `codeUnits == [55357]`. That is not a
truncated emoji; it is not a character at all. `RenderParagraph` then throws
`ArgumentError: string is not well-formed UTF-16` out of
`_RenderScaledInlineWidget.performLayout`, and **because the drop cap is a
`WidgetSpan` inside the first paragraph**, the throw takes the passage, the metadata
row and both CTAs with it.

**Phase 6 fixed the empty-string case at `/`. Phase 7 re-created the identical bug at
`/reading` in a new call site.** Two call sites of a two-line rule is one rule, and
one copy of it was wrong before the next reviewer noticed. The repair is
`trimmed.runes.first` — one shared function, on a **rune**.

The function is also **total**: `''` and `'   '` both give
`(letter: '', rest: '')`, so a caller that checks `letter.isEmpty` is asking the right
question — "did we choose a character?" — and there is no input for which it throws.
The one case it cannot repair is a `String` that arrived *already* malformed, and the
doc says so rather than claiming otherwise.

**A rule with two copies has one copy wrong before the next reviewer notices.**

## Consequences

### Better

- **The exemption does not create a blind spot, because the gate on it is §6 itself.**
  When a widget needed a conditional, the rule sent it to a cubit or a function — and
  the function is where the tests are.
- **The shared kernel earned its place on a measured bug, not on a principle.**
  `splitDropCap` is in `core/domain/` because two features call it; had `/reading`
  not shipped, it would have been `/`'s private helper.

### Worse

- **Widget tests are written after the widget, which means a design defect is visible
  only when someone writes the test.** Two recorded examples are the price: a double
  sign-in crashed the app (recorded decision 12's double-completion hazard), and
  `AuthPasswordChanged` printed the reader's typed password into every log line until
  §2.1's hazard-1 gate (`test/core/common/secret_masking_test.dart`) was written.
- **The "no `setState` per frame" rule is not checkable by reading a test** — it is a
  design obligation (ADR-0019) enforced by a review rather than by an assertion.

### Neutral / noted

- **Use `flutter test`, never `dart test`.** The plain Dart VM has no `dart:ui` and
  cannot compile Flutter SDK sources, so `dart test` **fails to load every test file**,
  including the pure-Dart ones, because each imports `flutter_test`. The consequence
  is not a red suite — it is a *misleading* one, and it is why the command in §7 is
  the one in `AGENTS.md`.
- **A bloc created in `setUp` does not drive a `testWidgets` tree.** `setUp` runs
  outside the test body's fake-async zone, so events land on a queue `tester.pump()`
  never drains: `bloc.state` is correct and `find.text(...)` returns **zero**. Every
  suite that mounts a bloc builds it **in the test body**, with `addTearDown(…close)`.
  That is why red-first and the widget exemption are two rules and not one.

## Traceability

- `AGENT_CONTEXT.md` §6, "Red-first — required for" and "Not red-first — widget and
  screen work"
- `AGENT_CONTEXT.md` §3 (the placement test that put `splitDropCap` in the kernel),
  §4 (no `dynamic`, no `print`), §7 (`flutter test`, never `dart test`)
- `lib/core/domain/entities/drop_cap_text.dart` — the function and its measured
  `[55357]` surrogate case
- `test/core/domain/entities/drop_cap_text_test.dart` — the pinned contract
- `test/flutter_test_config.dart` and `test/font_loading_test.dart` — why the runner
  must be `flutter test`
- [`docs/SEAMS.md`](../SEAMS.md) Seam 1 (`Result<T>` — hand-written equality that
  §6's red-first list protects), Seam 4 (building a bloc in the test body)
- ADR-0004 (the shared kernel), ADR-0012 (a test that walks an import graph)
