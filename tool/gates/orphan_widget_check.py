#!/usr/bin/env python3
"""orphan_widget_check.py — a widget built and tested but never placed on a screen.

## WHAT THIS IS FOR

AGENT_CONTEXT decision 144 records the defect this exists to make impossible:

> "`LeaderboardCard` was written, given a DI seam, a five-surface overflow matrix
> and a 21-test view suite — and **no page instantiated it**. ... Every §7 gate
> was green throughout."

Three suites were green and correct about their own subject: the view suite proved
the card renders (by instantiating it directly), the bloc test proved it fetches,
and the page test asserted the greeting, the wordmark, the flame and the panel. The
join between them was untested. The recorded lesson:

> "Three suites, all green, all correct about their own subject, and together they
> could not tell whether the feature shipped."

So the question this answers is not "is this widget tested" — it is **"does any
page's tree contain it"**, which is the only question none of those suites asked.

## THE TRANSITIVITY PROBLEM, AND WHY A NAIVE VERSION IS WRONG

A widget is placed if it is *reachable* from a page, not if it is *named* by one.
`SealFabTrigger` is built by `SealFab`, which `HomePage` places — so `SealFab`
places it, and a scan that only looked inside `presentation/pages/` would report
two false positives on its first run. An earlier hand-written version of this check
did exactly that: it listed `SealFabPill`, `SealFabTrigger`, `EvaInk`,
`EvaSectionHeader` and `PassageDropCap` as orphans, and every one of them is
placed.

So reachability is computed transitively: a widget is placed if any *placed* widget
constructs it, and the walk terminates on cycles.

## WHAT COUNTS AS "A WIDGET"

Only classes extending `StatelessWidget` or `StatefulWidget` from
`package:flutter/widgets.dart`. A plain value class, a painter, an inherited
widget or an enum is not a widget for this purpose — `EvaFocusRingScope` is one and
is correctly invisible here.

## WHAT COUNTS AS A ROOT, AND WHY THE PATH IS NOT IT

A root is a **page the app can actually navigate to**, and the check now says
that in two mechanical halves:

1. the file declares `@RoutePage()` **on a widget** — a class in that file
   that extends `StatelessWidget` or `StatefulWidget`; and
2. the route that declaration produces is **registered** in
   `lib/app/router/app_router.dart`'s route table — the generated route
   class's name appears there as `page: <Name>Route.page`.

Both halves are mechanical, and both are in this file's vocabulary already: the
first is the `DECL` pattern that builds the inventory below, and the second is
a plain source file.

### THE PATH HEURISTIC IS GONE, AND THIS IS THE RECEIPT

The root set used to be "files under `/presentation/pages/`" — a *proxy* for
"is a page" — plus, since Phase 6, "files that declare `@RoutePage()`". The
second clause is what let the dock shell in: `lib/app/router/dock_shell_page.dart`
is a page in the composition root, and it is deliberately **not** under any
feature's `pages/` directory, because it hosts three features' tabs and
AGENT_CONTEXT §3 forbids a feature importing another feature.

**But a proxy and a thing are not the same, and Phase 6 added the thing
without checking that it was a thing.** The clause read "the file *mentions*
the annotation", and so:

* a **plain class** carrying `@RoutePage()` — not a widget, and its route the
  router has never heard of — made its file a root; and
* any widget merely **named** in that file was then reported as **placed**,
  because a bare name in a root's text reads as a construction.

**Measured, not assumed.** `lib/features/probe/presentation/probe_holder.dart` —
a plain class with `@RoutePage()` on it, mentioning `ProbeWidget(` — made this
gate exit **0** with `ProbeWidget` on **no screen at all**. The
comment-stripping half of the same clause *did* work: the same file with the
annotation only in a doc comment was correctly red, exit 1. So the clause was
half a gate, and the half it had was the half that was already there.

**The root set is unchanged, and that is the receipt for the change.** Every
page in the tree declares `@RoutePage()` on a `StatelessWidget` and is
registered in the router's table, so the roots are the same files the proxy
found — and the report is what it was. The difference is that the set is now
**derived** rather than **guessed**: a page that stops being registered stops
being a root, which is the correct answer and the old proxy could not give it.

## WHAT IT DOES NOT CHECK

Whether the placed widget renders *the right data*, or appears in the right order,
or is visible at the viewport it matters at. It answers one question: is this class
in any screen's tree. That is the question decision 144 says nothing was asking.

Nor does it check that a registered page is a *good* page — that the route is
reachable in the router's stack rather than shadowed by an earlier entry, that
the page is one a reader would ever be shown, or that the widget it places is
the one the screen meant. It checks that a page is a root because a **widget**
claims to be one and the router **has** the route; what the route does when it
is pushed is auto_route's business and `app_router_test.dart`'s.

Exit:  0 every widget is placed (or is allowlisted with a written reason)
       1 at least one widget is built, tested and never placed
       2 the check could not run
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

DECL = re.compile(
    r"^(?:abstract\s+|final\s+|base\s+|sealed\s+)*"
    r"class\s+(?P<name>[A-Z][A-Za-z0-9_]*)"
    # The optional type-parameter list is NOT optional. `class SegmentedControl<T>
    # extends StatefulWidget` is a widget like any other, and an earlier version of
    # this pattern had no `(?:\s*<[^>]*>)?` and therefore matched no generic widget
    # at all — silently, with no error. `SegmentedControl` was reported as neither
    # placed nor orphaned for that reason. A gate that quietly skips a class of
    # declarations is the same defect as one that cannot fail.
    r"(?:\s*<[^>{]*>)?"
    r"\s+extends\s+(?:StatelessWidget|StatefulWidget)\b",
    re.M,
)

SKIP_SUFFIXES = (".gr.dart", ".freezed.dart", ".config.dart")

_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
_LINE_COMMENT = re.compile(r"//[^\n]*")


def strip_comments(text: str) -> str:
    """Remove `/* */` and `//` comments, preserving line structure.

    Doc comments matter here: a widget's own `///` prose naming its siblings is
    exactly the kind of text that makes a bare-name scan report a false pass.
    Newlines are preserved so a stripped file still reports the same line count,
    which keeps any reported `file:line` meaningful.
    """
    text = _BLOCK_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    text = _LINE_COMMENT.sub("", text)
    # Doc comments are `///` and get caught by the line rule above; a block form
    # `/** ... */` is caught by the block rule. Nothing else is stripped, so a
    # string literal containing a name would be a false negative — acceptable,
    # because this only ever errs toward reporting MORE, never fewer.
    return text


# The annotation that says "this file is a route page".
#
# auto_route_generator finds its pages by this annotation, so it is the same
# definition the framework itself uses — and the check's root set should agree
# with the generator's, or the two disagree about what a page is.
#
# **The arguments are captured** because auto_route lets a page name its own
# route (`@RoutePage(name: 'X')`), and the generated class is then `X` rather
# than the derived `FooRoute`. A derivation that ignored the argument would
# look for a class the generator never emits, and the file would stop being a
# root — the gate going red on a correct tree, which is at least loud, but it
# is a wrong answer and it is avoidable.
_ROUTE_PAGE = re.compile(r"@RoutePage\s*\(\s*(?P<args>[^()]*?)\s*\)")


# The class declaration an annotation is attached to.
#
# **The NEAREST declaration wins**, and that is the whole point. An annotation
# in front of a plain class binds to THAT class, and a widget class later in
# the same file belongs to nobody's annotation. An earlier version of this
# check asked only "is there a widget class *after* the annotation?", and a
# file whose annotation sat on a plain class answered YES whenever the file
# happened to contain a widget at all — which is how a plain class carrying
# the annotation became a root.
#
# `extends` is OPTIONAL here and the widget test is separate, because a plain
# class in Dart usually writes no `extends` at all — and a pattern that
# required one would skip straight past it to the next class in the file,
# which is the same bug wearing a different hat.
#
# The name may be private (`_Foo`): the annotation still binds to it, and a
# private class is not a page — the generated route class has to be nameable
# from the router, and a private page class is not.
_CLASS_HEADER = re.compile(
    r"^(?:abstract\s+|final\s+|base\s+|sealed\s+|mixin\s+)*"
    r"class\s+(?P<name>[_A-Z][A-Za-z0-9_]*)"
    r"(?:\s*<[^>{]*>)?"
    r"(?:\s+extends\s+(?P<super>[A-Za-z0-9_]+))?",
    re.M,
)


def _is_page_widget(header: str) -> bool:
    """Whether [header] declares a widget that can be a route page.

    **The gate's own [DECL]**, which is what the inventory below is built
    from, so "a widget" cannot mean two things in one file. A private class
    is not one for this purpose either, and for the same reason the route
    class is not: it has to be nameable from the router.
    """
    return DECL.match(header) is not None


def _capitalize(name: str) -> str:
    """auto_route's own `capitalize` (`auto_route_generator/lib/utils.dart:8`)."""
    if len(name) < 2:
        return name.upper()
    return name[0].upper() + name[1:]


def _route_class_name(page_class: str, args: str) -> str:
    """The route class auto_route generates for [page_class].

    **auto_route's own rule, not a guess.** `RoutePage`'s `replaceInRouteName`
    defaults to `'Page|Screen,Route'` (`auto_route_annotations.dart:40`), and
    the generator applies it as
    `className.replaceAll(RegExp(parts[0]), parts[1])`
    (`route_config.dart:75`), capitalising the result.

    A page may also name its own route — `@RoutePage(name: 'X')` — and then the
    generated class is `X`, so the argument is read first.
    """
    named = re.search(r"""\bname\s*:\s*['"]([^'"]+)['"]""", args)
    if named is not None:
        return _capitalize(named.group(1))
    return _capitalize(re.sub(r"Page|Screen", "Route", page_class))


def _annotated_classes(text: str) -> list[tuple[str, str, str]]:
    """Every `@RoutePage()` in [text], as (class, route class, why not).

    The third member is empty when the annotation really does declare a page
    widget; otherwise it says **why** it does not, because "this file is not a
    root" and "this file's annotation is decoration" are different answers and
    the difference is the whole gate.

    Matched against the **stripped** text, so a doc comment that merely
    mentions `@RoutePage()` — and this repository mentions it in prose in
    several places — does not make the file a root. A file that only *talks*
    about pages is not one.
    """
    code = strip_comments(text)
    found: list[tuple[str, str, str]] = []
    for m in _ROUTE_PAGE.finditer(code):
        args = m.group("args")
        header = _CLASS_HEADER.search(code, m.end())
        if header is None:
            found.append(("", "", "the annotation is not attached to a class"))
            continue
        name = header.group("name")
        if not _is_page_widget(header.group(0)):
            found.append(
                (
                    name,
                    "",
                    f"the annotation is attached to {name}, which is not a page "
                    "widget",
                )
            )
            continue
        found.append((name, _route_class_name(name, args), ""))
    return found


# The router's own route table. **The composition root's**, because that is
# where the app's routes are registered — AGENT_CONTEXT §3 puts the wiring
# there and nowhere else.
ROUTER = ROOT / "lib" / "app" / "router" / "app_router.dart"


def _router_table() -> str | None:
    """The router's source with its comments stripped, or None if unreadable.

    **Comments are stripped for the same reason the page files are.** The
    router explains itself in prose, and a doc comment naming a route class
    must not register a route that was never registered.
    """
    if not ROUTER.is_file():
        print(f"FATAL: no router at {ROUTER}", file=sys.stderr)
        return None
    return strip_comments(ROUTER.read_text(encoding="utf-8", errors="ignore"))


def _is_registered(route_class: str, table: str) -> bool:
    """Whether [route_class] is registered in the router's route table.

    **The idiom, not a bare name.** auto_route registers a page as
    `page: HomeRoute.page`, and the framework's own `AutoRoute` and
    `RedirectRoute` classes are in the same file — so a bare word search would
    accept a page whose derived name happened to collide with one of them.

    **An import prefix is allowed** (`page: _i3.HomeRoute.page`), because the
    router's own import of the generated library is unprefixed today and a
    prefixed one is not a different registration — it is the same registration
    spelled with more ceremony, and the gate must not become red over the
    spelling.
    """
    return (
        re.search(
            rf"page\s*:\s*(?:[A-Za-z_$][A-Za-z0-9_$]*\s*\.\s*)?"
            rf"{re.escape(route_class)}\s*\.\s*page",
            table,
        )
        is not None
    )


# Classes that are legitimately not placed on a page, each with the reason. An
# entry here is a PRODUCT decision, not a convenience — the same rule
# `text_contrast_gate_test.dart` applies to `knownSubstandard`: the list cannot
# grow silently.
ALLOWLIST: dict[str, str] = {
    # ## `WitnessSky` LEFT THIS LIST IN TASK 5.3, AND THIS COMMENT IS THE RECEIPT
    #
    # The entry read "Phase 3 Task 3.3 shipped the widget; Phase 5 places it …
    # Placing it here would mean inventing the reader's scroll observer, a router
    # entry and a settings row — all three of which the dispatch for this task
    # explicitly withholds", and its last line promised "the gate reports that, so
    # it cannot outlive its reason."
    #
    # `reading_page.dart` now does exactly that: the observer of
    # `eva/redesign.html:1211-1219` — threshold `.6`, one-shot per verse — is what
    # places the sky, with `lib/app/sky_scope.dart`'s handle carrying the lit set
    # across the feature boundary `/reading` may not cross (AGENT_CONTEXT §3). The
    # gate reported the entry stale; an allowlist row that has stopped being true
    # is a false green, not a harmless leftover, so the row is gone and this
    # paragraph is what remains of it.

    # ## `SealMonogram` LEFT THIS LIST IN TASK 5.6, AND THIS COMMENT IS THE
    # RECEIPT
    #
    # The entry read "Phase 5.1 rebuilt `/login` against
    # `eva/redesign.html:503-511`, whose brand block is a wordmark and a tagline
    # — the seal is one of the elements the redesign deleted from that screen.
    # The widget survives because Task 4.2 re-rolled its treatment to `.jorb`
    # (`eva/redesign.html:392-395`) and `/journey` draws that orb in Task 5.6;
    # between those two tasks it is genuinely unplaced."
    #
    # **Task 5.6 is that task.** `journey_page.dart` now constructs the orb
    # through `JourneyOrb` — the seal at 74px, the prototype's own number
    # (`eva/redesign.html:392`), with the reader's own monogram in it and not
    # the prototype's literal `M` (`:586`).
    #
    # The gate reported the entry stale, which is what the entry's own last
    # sentence promised: "Same mechanism as WitnessSky's entry: STALE the
    # moment any page constructs it." An allowlist row that has stopped being
    # true is a false green, not a harmless leftover — so the row is gone and
    # this paragraph is what remains of it, exactly as `WitnessSky`'s did.

    "HairlineDivider": (
        "Task 5.3 made this one real. Its last two call sites were "
        "`reading_header.dart` and `reading_controls.dart`, both of which the "
        "redesigned `/reading` deleted (`eva/redesign.html:540-560` has no "
        "header block and no settings row), so between Task 5.3 and the two "
        "tasks below it is genuinely unplaced. The prototype's own rules name "
        "both consumers: `eva/redesign.html:314` — `.brow{...border-bottom:1px "
        "solid rgba(255,255,255,.05)}` is the journey's book row (Task 5.6), and "
        "`:419`/`:439` — `.srow` and `.sact`, each with a `border-bottom:1px`, "
        "are the settings rows and the sheet actions (Task 5.7). Deleting the "
        "widget now would mean re-deriving it in two tasks with a second "
        "spelling. Same mechanism as the entries above: STALE the moment any "
        "page constructs it."
    ),
    "TextLink": (
        "Phase 5.2 rebuilt `/` against eva/redesign.html:513-538, and the "
        "redesign's home has no link-shaped control: the two cards are whole-box "
        "taps and the carousel's label row is two spans. The two widgets that "
        "placed it — `today_reading_panel.dart`'s continue link and "
        "`leaderboard_card.dart`'s see-all link — are both deleted, so between "
        "Phase 5.2 and Task 5.5 the widget is genuinely unplaced. It survives "
        "because `/communion` draws `leaderboardOpenFull` (the 'See all' link, "
        "Task 5.5) and `TextLink` is the component the design system owns for "
        "that shape; deleting it now would mean re-deriving it in 5.5 with a "
        "second spelling. Same mechanism as the two entries above: STALE the "
        "moment any page constructs it."
    ),
}


def dart_files() -> list[Path]:
    out: list[Path] = []
    for root in ("lib",):
        base = ROOT / root
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.dart")):
            if p.name.endswith(SKIP_SUFFIXES):
                continue
            out.append(p)
    return out


def main() -> int:
    files = dart_files()
    if not files:
        print("FATAL: no lib/ to scan", file=sys.stderr)
        return 2

    texts: dict[Path, str] = {}
    for p in files:
        texts[p] = p.read_text(encoding="utf-8", errors="ignore")

    # name -> declaring file, and name -> set of names that construct it
    declared: dict[str, Path] = {}
    for p, t in texts.items():
        if "/widgets/" not in p.as_posix():
            continue
        for m in DECL.finditer(t):
            declared.setdefault(m.group("name"), p)

    if not declared:
        print("FATAL: found zero widget classes — the pattern has rotted", file=sys.stderr)
        return 2

    def constructs(haystack: str, name: str, hay_name: str) -> bool:
        """True if `name` is CONSTRUCTED in `haystack`, by a class other than itself.

        Both exclusions are load-bearing, and neither was optional.

        **Comments.** A bare-name match reports false PLACES. This repository
        discusses `EvaChip` and `SegmentedControl` constantly — in design-system
        docs, in `language_sheet.dart`'s "why not a SegmentedControl" reasoning,
        in `leaderboard_page.dart` describing a window switcher it does not have —
        and every one is prose, not a construction. Both widgets are in fact built,
        tested (8 and 3 goldens) and never rendered.

        **Self.** A widget's own constructor declaration matches its own name:
        `const SegmentedControl({...})`. Without excluding that, every widget
        places ITSELF and the gate reports zero orphans forever — which is the
        decision-144 failure mode wearing a green tick.

        The self test is by NAME, not by file: `seal_fab.dart` declares `SealFab`,
        `SealFabTrigger` and `SealFabPill`, and `SealFab` really does construct the
        other two. An earlier version excluded by file and reported both of them
        as orphans, which is the opposite error and just as wrong.
        """
        code = strip_comments(haystack)
        if hay_name == name:
            return False
        # The type argument is part of a generic construction:
        # `SegmentedControl<AppThemeMode>(...)` at settings_page.dart:203. A
        # pattern that stopped at `(` missed every generic widget's call sites,
        # which is how `SegmentedControl` was first reported as an orphan when
        # it is on `/settings` today.
        return re.search(rf"\b{re.escape(name)}\s*(?:<[^;{{}}]*>)?\s*\(", code) is not None

    # The root set: **the pages the app can actually navigate to.**
    #
    # A file is a root when it declares `@RoutePage()` **on a widget** and the
    # route that declaration produces is **registered in the router's table**.
    # Both halves are mechanical, and both are in this file's vocabulary
    # already: the first is [DECL] and the second is a plain source file.
    #
    # **THE PATH HEURISTIC IS GONE** — "files under `/presentation/pages/`" was
    # a *proxy* for "is a page", and the module doc carries the receipt: the
    # root set is the same set of files the proxy found, and it is now derived
    # rather than guessed. `lib/app/router/dock_shell_page.dart` is in it
    # because the annotation is on a widget and `DockShellRoute` is in the
    # router — not because of where the file lives.
    #
    # **The comment stripping matters here**, and it always did. A doc comment
    # that *mentions* `@RoutePage()` — and plenty of them do, because this
    # repository explains itself in prose — must not make a file a root, or a
    # widget that no page places would be reported as placed by a sentence.
    router_table = _router_table()
    if router_table is None:
        return 2

    pages: list[Path] = []
    not_a_root: list[str] = []
    for p in files:
        for _, route_class, reason in _annotated_classes(texts[p]):
            if not reason:
                if _is_registered(route_class, router_table):
                    pages.append(p)
                    break
                reason = (
                    f"{route_class} is not registered in "
                    "lib/app/router/app_router.dart's route table"
                )
            not_a_root.append(f"{p.relative_to(ROOT).as_posix()}: {reason}")
    if not pages:
        print("FATAL: no page files found — nothing is 'placed' by definition", file=sys.stderr)
        return 2

    placed: set[str] = set()
    for p in pages:
        t = texts[p]
        for name, owner in declared.items():
            if constructs(t, name, "<page> " + p.name):
                placed.add(name)

    # Transitive closure: a placed widget places what it constructs.
    changed = True
    while changed:
        changed = False
        for name in list(placed):
            owner = declared[name]
            t = texts[owner]
            for other, other_owner in declared.items():
                if other in placed:
                    continue
                if constructs(t, other, name):
                    placed.add(other)
                    changed = True

    orphans = sorted(n for n in declared if n not in placed)

    # An allowlisted entry must actually be unplaced — otherwise the exemption has
    # rotted and is hiding nothing.
    stale = sorted(n for n in ALLOWLIST if n in placed)
    for n in stale:
        print(f"  STALE    {n} is allowlisted but IS placed — remove the entry")
    stale_allow = [n for n in stale if n in ALLOWLIST]

    allowed_orphans = [n for n in orphans if n in ALLOWLIST]
    real_orphans = [n for n in orphans if n not in ALLOWLIST]

    print(f"widget classes declared under */widgets/ : {len(declared)}")
    print(f"root pages (@RoutePage() on a widget)    : {len(pages)}")
    print(f"reachable from a page                   : {len(placed)}")
    print(f"not placed                              : {len(orphans)}"
          f"  (allowlisted {len(allowed_orphans)}, real {len(real_orphans)})")

    # A file that declares the annotation on something that is not a registered
    # page widget is **not** a root — and it is worth saying out loud, because
    # "this file is not a root" and "this file's annotation is decoration" are
    # different answers, and the difference is what this gate is for.
    #
    # **It is a diagnostic and not a failure.** The gate's subject is widgets
    # that are built and never placed, and an annotation nobody routes to
    # places nothing. What it must not do is *hide*: the clause that used to
    # make such a file a root is what let a widget be reported as placed while
    # it was on no screen at all, and that is the failure this gate exists to
    # make impossible.
    if not_a_root:
        print()
        for line in not_a_root:
            print(f"  NOT A ROOT  {line}")
        print()

    if stale_allow:
        print()
        for n in stale_allow:
            print(f"  STALE ALLOWLIST  {n}")
        print()
        print(f"FAILED — {len(stale_allow)} allowlist entr(ies) are stale.")
        return 1

    if real_orphans:
        print()
        for n in real_orphans:
            print(f"  ORPHAN  {n}  ({declared[n].relative_to(ROOT).as_posix()})")
        print()
        print(f"FAILED — {len(real_orphans)} widget(s) are built and never placed.")
        print("Decision 144: a widget with a full test suite and no page that")
        print("instantiates it is invisible to every assertion that does not look")
        print("for it on the screen. Place it, delete it, or allowlist it WITH a")
        print("written reason — never suppress the failure.")
        return 1

    print("PASSED — every widget is reachable from a page.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
