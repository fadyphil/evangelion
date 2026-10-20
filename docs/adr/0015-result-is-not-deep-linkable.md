# ADR-0015: Accept that `/result` cannot be deep-linked

- **Status:** accepted · **amended 2026-10-20** (the mechanism changed; the
  decision did not)
- **Date decided:** 2026-10-04
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §5 trap 11, recorded decisions 81, 85

> **AMENDED 2026-10-20, AND THE AMENDMENT IS ABOUT THE MECHANISM ONLY.**
>
> `/result` **retired to a modal** in Phase 6.2 of the Lumen redesign
> (`eva/redesign.html:718-727`), so there is no route, no `ResultRoute`, no
> `AppRoutes.result` and no `features/result/` directory any more. The result is
> a card over a veil, presented over the quiz.
>
> **The decision below still holds, and it holds more strongly.** The submit
> response is the only artifact the result renders and there is nothing to
> re-fetch it from, so the result **cannot be a destination** — a deep link, a
> URL, a notification or a shortcut cannot reach it. A modal is not addressable,
> so the property is now structural rather than enforced by a required route
> parameter.
>
> **What died with the route** is the *enforcement*: `app_router_test.dart`'s
> group that asserted `pushPath('/result')` fails was **deleted, not weakened**,
> because the invariant it pinned no longer has a subject. The body below is
> otherwise unchanged and still describes the codebase as it stood until
> 2026-10-20; where it names `ResultPage`, `ResultRoute` or
> `features/result/`, read `ResultSheet` and the quiz feature.

## Context

`docs/plans/08-build-phases.md` Phase 8 says `/result` "reads the submit response
held by `QuizBloc` and has no repository, no use case, and no API call of its own."
That is not a design preference — it is what §5 trap 11 measures.

## Decision

**`ResultPage` takes its `SubmitResult` as a required constructor parameter**
(`lib/features/result/presentation/pages/result_page.dart:60,62`), so `ResultRoute`
requires its `result` and **`pushPath('/result')` cannot build the page.** That is
accepted, tested, and not worked around.

**Why there is no other way in.** The submit response exists only as the `POST`'s
reply. There is **no `GET /readings/:id`** on the backend — §5 trap 11 is the proof —
so there is nothing to re-fetch it from, and `QuizBloc.lastResult`
(`quiz_bloc.dart:260`) is the **only** holder in the process. The response therefore
has to survive the reader leaving `/quiz`, and there are exactly two places it can
live.

**One of those two is closed.** `features/result/` importing `features/quiz/` is
Gate 2 — the same cross-feature wall `HomeCleared` could not cross in the other
direction. The alternative, reading `getIt<QuizBloc>()` from a result page, is a
**locator dependency on a feature this page must not know about**: the same
violation wearing an injection. So the value is **passed across the boundary**, and
the constraint becomes compile-enforced rather than documented.

**`app_router_test.dart` asserts the failure deliberately rather than working
around it** (`test/app/router/app_router_test.dart:442-500`, the group *"a cold push
of /result"*, expecting `false` with the router left on `/`). A workaround would have
meant either an optional parameter — so the screen could render with nothing in it,
which is the exact defect the requirement exists to prevent — or a second route for
the empty case, which is a seventh screen and §2 forbids.

## Alternatives considered

### `getIt<QuizBloc>()` inside `ResultPage`

- **Why not:** recorded decision 81's phrase is exact — *a locator dependency on a
  feature this page must not know about*. It is the forbidden import with the
  importing line moved to a different file, and it would make the screen's data
  source invisible at its constructor.

### `features/result/` imports `features/quiz/` for `QuizBloc`

- **Why not:** Gate 2, and a two-way dependency once `HomeCleared` is considered.
  `tool/verify_purity.sh` Gate 2 enforces it mechanically and `verify_all.sh`
  negative-controls it.

### Make `result` optional and render `EmptyState`

- **Why not:** this is precisely what the required parameter forbids, and decision 81
  records that a reader arriving at an empty result screen is a worse outcome than a
  navigation that did not happen.

### Persist the submit response somewhere and re-read it

- **Why not:** there is no endpoint to read it back from. §5 trap 10 records that **no
  successful submit has ever been observed** against any client-reachable reading, so
  a persistence layer would be a store nothing can refill.

## Consequences

### Better

- **The requirement is enforced by the compiler.** A `ResultPage` cannot be built
  without a result, and the only call site that builds one is `QuizPage`'s terminal
  `finish` arm — which `quiz_page_test.dart` drives with a real `QuizBloc`.
- **The failure is a named test rather than an accident**, so a future change that
  makes `/result` deep-linkable has to confront a red test that says *why*.

### Worse

- **`/result` is unreachable by URL, by deep link, and by any future notification
  or shortcut.** That is the cost, stated rather than discovered.
- **The real dead end is reachable, and it is rendered rather than hidden.** A reader
  whose every question is already answered reaches the last question with nothing to
  submit — so there is no `SubmitResult`, so per this ADR there is no result screen.
  Decision 85 makes `QuizCta.none` a real arm rendered as a **disabled `EvaButton`**
  whose visible label is still the prototype's transcribed string
  (`docs/plans/03-design-system.md` → `QuizScreen.tsx:127`) and whose *accessible*
  name carries the reason as a suffix. Hiding the button would make a missing
  feature indistinguishable from a missing control; leaving it enabled and letting
  the tap do nothing is §14's forbidden state.

### Neutral / noted

- **`ResultRoute` is guarded like every other route except `/login`**
  (`app_router.dart:251`), which is correct and slightly odd: the guard cannot have
  anything useful to say about a route that cannot be built.
- **`ResultPage` has no repository, no use case and no endpoint** — which is why
  `features/result/` has no bloc at all, and why it is the one screen in the app with
  no state machine.

## Traceability

- `AGENT_CONTEXT.md` §5 trap 11 (no `GET /readings/:id`; the submit response is the
  only artifact) and trap 10 (no successful submit has ever been observed)
- `AGENT_CONTEXT.md` recorded decision 81 (the required parameter, and the deliberate
  assertion of the failure), decision 85 (`QuizCta.none` rendered disabled with its
  reason)
- `lib/features/result/presentation/pages/result_page.dart:60,62`
- `lib/features/quiz/presentation/bloc/quiz_bloc.dart:260,318`
- `lib/app/router/app_router.dart:251`
- `test/app/router/app_router_test.dart:442-500`
- `docs/plans/08-build-phases.md` Phase 8 — the sentence this implements
- [`docs/SEAMS.md`](../SEAMS.md) Seam 5 ("`/result` is not deep-linkable")
- ADR-0012 (Gate 2 and what it forbids)
