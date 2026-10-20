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

## THE INVENTORY IS **ALL OF `lib/`**, AND THAT IS THE STRUCTURAL FIX

**The first version of this gate built its inventory out of the files under
`*/widgets/` and nothing else.** The filter was one line:

```python
    if "/widgets/" not in p.as_posix():
        continue
```

and it is the exact shape of decision 144. `GoldFlecks` lives in
`lib/core/design_system/effects/`, `EvaAnimate` in `lib/core/design_system/motion/`
and `EvaTypeScale` in `lib/core/design_system/tokens/` — **none of them under a
`widgets/` directory** — and all three were built, exported, fully tested and
placed on **no screen at all**. The gate could not see them, because the gate was
not looking where they were. A path filter is a proxy for "is a widget", and the
proxy was wrong for a third of the design system.

**The inventory is now every `.dart` file under `lib/`**, generated files excluded
(`.gr.dart`, `.freezed.dart`, `.config.dart` — the last two are not widgets and the
first is auto_route's own output). The `DECL` pattern still excludes everything
that is not a widget: a plain value class, a painter, an enum and an
`InheritedWidget` are all invisible here, which is correct.

**What the widening costs, and it is not nothing:** a page's own private widgets
are not in the inventory either, because `DECL` requires a public name — and that
is the right answer rather than a gap. A private widget cannot be constructed from
another file, so the only thing that can place it is the file it lives in, and a
file that declares a private widget and never constructs it is a class with no
caller, which the analyzer and review are for. **A public widget is in the
inventory whether or not anybody wanted it there**, and that is the point.

## WHAT COUNTS AS A ROOT, AND WHY THE PATH IS NOT IT

A root is a **page the app can actually navigate to**, and the check now says
that in two mechanical halves:

1. the file declares `@RoutePage()` **on a widget** — a class in that file
   that extends `StatelessWidget` or `StatefulWidget`; and
2. the route that declaration produces is **registered** in the app's route
   table — the generated route class's name appears there as
   `page: <Name>Route.page`.

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

## A BOGUS `@RoutePage()` IS A **FAILURE**, NOT A DIAGNOSTIC

**This is the second half of the clause above, and it used to exit 0.**

A file that carries `@RoutePage()` on something that is not a registered page
widget printed `NOT A ROOT` and the gate **passed**. The reasoning was "the
gate's subject is widgets that are built and never placed, and an annotation
nobody routes to places nothing". That reasoning is about the wrong question.
The annotation says "this is a screen the app can navigate to", and if the app
cannot navigate to it, then either the annotation is decoration (a mistake) or
the route registration was forgotten (a bigger mistake). **Both are defects,
and a gate that prints a diagnostic and exits 0 is a gate that cannot fail** —
the tree can be wrong and the gate says nothing.

So it is a **failure**, exit **1**, with the diagnostic text kept. The text is
kept because it is the receipt: it says *which* file, *which* class and *why*
it is not a page, and that is the difference between "the gate is red" and
"the gate is red and here is the thing to fix".

## THE ROUTER IS **DERIVED**, NOT NAMED, AND ITS ABSENCE IS **FATAL**

The registration half above needs the app's route table, and the first version
of this file reached for it by path:

```python
ROUTER = ROOT / "lib" / "app" / "router" / "app_router.dart"
```

**A rename or a move of that file silently turned the registration clause into
"no route is registered anywhere".** That is *safe* in direction — it reports
less rather than more — and it is **useless**: the clause's entire content is
"is this page's route in the router's table", and with the router unfindable
the answer is always no, so the clause cannot tell "this page is not
registered" from "the router moved". A clause that cannot tell those two apart
is not a clause.

**So the router is found by content**: the unique file under `lib/` that
declares `@AutoRouterConfig()` — auto_route's own marker for "this class is
the app's router", so the gate agrees with the framework about what a router
is rather than with a file name. A rename cannot break it and a move cannot
break it.

**And not finding it is FATAL (exit 2), never a silent pass.** Zero matches
means there is no route table to ask about; more than one means the gate would
have to guess which router is the app's, and a guess that happens to be wrong
turns every page into an orphan. Both are "the check could not run", which is
what exit 2 means, and both are reported with the file names.

## THE APP ROOT IS A ROOT TOO, AND IT IS **DERIVED** AS WELL

The widened inventory reaches the classes that are **above** the pages:
`EvangelionApp` (the app's root widget), `NeuralMotionScope` and
`SettingsScope` (the scopes `MaterialApp` sits inside). **No page constructs
any of them** — they are above the router, not below it — so without a second
root the widening would report three orphans that are on every single screen.

**The app root is the widget class that installs the app's tree**, and it is
found by content for the same reason the router is: `MaterialApp.router` is the
one place auto_route's `RouterConfig` enters the tree, so the widget class
enclosing that installation is the root of everything the reader sees.

Zero installations or more than one is **FATAL**, for the same reason the
router's is: without it there is no tree, and a gate that reports "nothing is
placed" over a tree it could not find is the worst outcome available.

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
       1 at least one widget is built, tested and never placed — OR an
         annotation claims a page the app does not have
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


# The app's router, found by CONTENT.
#
# auto_route's own marker for "this class is the app's router" is
# `@AutoRouterConfig()`, so finding the file that declares it agrees with the
# framework rather than with a file name. **A rename cannot break this and a
# move cannot break it**, which is the whole reason it replaced the literal
# `lib/app/router/app_router.dart`.
#
# **Comments are stripped before the search**, so a doc comment that merely
# mentions the annotation does not make a file the router.
_ROUTER_ANNOTATION = re.compile(r"@AutoRouterConfig\b")


def _find_router(files: list[Path], stripped: dict[Path, str]) -> tuple[Path | None, str]:
    """The file that declares the app's route table, and why not if there is none.

    **Derived, never named.** The literal this replaced made a renamed router
    read as "no route is registered anywhere", which is safe in direction and
    useless in content: the clause could no longer tell "this page is not
    registered" from "the router moved".

    Zero matches and more than one match are both **FATAL** at the call site:
    a gate that cannot find the table it asks questions of must not answer
    them, and a gate that has two tables must not choose between them.
    """
    hits = [p for p in files if _ROUTER_ANNOTATION.search(stripped[p])]
    if not hits:
        return None, (
            "no file under lib/ declares `@AutoRouterConfig()` — the app's route "
            "table could not be found, so 'is this page registered?' has no "
            "answer, and answering it 'no' for every page would be a false green"
        )
    if len(hits) > 1:
        names = ", ".join(sorted(p.relative_to(ROOT).as_posix() for p in hits))
        return None, (
            f"{len(hits)} files under lib/ declare `@AutoRouterConfig()` ({names}) "
            "— the gate does not guess which one is the app's router"
        )
    return hits[0], ""


# The app's widget tree, and where it is installed.
#
# `MaterialApp.router` is the ONE place auto_route's `RouterConfig` enters the
# tree, so the widget class that encloses that installation is the app's root
# widget: the one the process installs, and the one every screen lives under.
#
# It is found by content for the same reason the router is, and it exists
# because the widened inventory reaches the classes that are ABOVE the pages —
# `EvangelionApp`, `NeuralMotionScope`, `SettingsScope` — which no page
# constructs and every screen contains.
_APP_INSTALL = re.compile(r"\bMaterialApp\s*\.\s*router\s*\(")


def _find_app_root(
    files: list[Path], stripped: dict[Path, str], declared: dict[str, Path]
) -> tuple[str | None, str]:
    """The widget class the app's tree is installed in, and why not if none is.

    **The nearest enclosing widget class wins.** The installation is written
    inside a `State`'s `build`, and the `State` is not a widget — so the
    enclosing *widget* is the one the state belongs to.

    Zero installations and more than one are both **FATAL**: without the root
    there is no tree, and a gate that reports "nothing is placed" over a tree
    it could not find is the worst outcome available.
    """
    hits: list[tuple[Path, int]] = []
    for p in files:
        for m in _APP_INSTALL.finditer(stripped[p]):
            hits.append((p, m.start()))
    if not hits:
        return None, (
            "no file under lib/ installs `MaterialApp.router(` — the app's widget "
            "tree could not be found, so 'is this widget on a screen?' has no "
            "answer, and answering it 'no' for every widget would be a false "
            "green"
        )
    if len(hits) > 1:
        places = ", ".join(
            sorted(f"{p.relative_to(ROOT).as_posix()}" for p, _ in hits)
        )
        return None, (
            f"{len(hits)} files under lib/ install `MaterialApp.router(` ({places}) "
            "— the gate does not guess which one is the app's root"
        )
    path, offset = hits[0]
    name = None
    for m in DECL.finditer(stripped[path]):
        if m.start() < offset:
            name = m.group("name")
    if name is None or name not in declared:
        return None, (
            f"the app's tree is installed in {path.relative_to(ROOT).as_posix()}, "
            "but no widget class encloses the installation — the app's root "
            "widget could not be identified"
        )
    return name, ""


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
    stripped: dict[Path, str] = {p: strip_comments(t) for p, t in texts.items()}

    # name -> declaring file, and name -> set of names that construct it.
    #
    # **The inventory is ALL of `lib/`**, not the files under a `widgets/`
    # directory. The old filter hid `effects/`, `motion/` and `tokens/` — and
    # three widgets that were built, tested and placed on no screen at all
    # lived there. The file header has the receipt.
    declared: dict[str, Path] = {}
    for p, t in stripped.items():
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

    # The root set: **the pages the app can actually navigate to**, plus the
    # app's own root widget.
    #
    # A file is a page when it declares `@RoutePage()` **on a widget** and the
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
    router, why = _find_router(files, stripped)
    if router is None:
        print(f"FATAL: {why}", file=sys.stderr)
        return 2
    router_table = stripped[router]

    pages: list[str] = []
    page_files: dict[str, Path] = {}
    not_a_root: list[str] = []
    for p in files:
        for name, route_class, reason in _annotated_classes(texts[p]):
            if not reason:
                if _is_registered(route_class, router_table):
                    pages.append(name)
                    page_files[name] = p
                    continue
                reason = (
                    f"{route_class} is not registered in "
                    f"{router.relative_to(ROOT).as_posix()}'s route table"
                )
            not_a_root.append(f"{p.relative_to(ROOT).as_posix()}: {reason}")
    if not pages:
        print(
            "FATAL: no page files found — the app has no navigable screen, so "
            "'placed' has no meaning",
            file=sys.stderr,
        )
        return 2

    # The app's root widget: the tree every screen lives under. See the header.
    app_root, why = _find_app_root(files, stripped, declared)
    if app_root is None:
        print(f"FATAL: {why}", file=sys.stderr)
        return 2

    # A page is placed by definition — the app can navigate to it — and so is
    # the app's root widget, which is what the process installs.
    placed: set[str] = set(pages)
    placed.add(app_root)

    # Transitive closure: a placed widget places what it constructs.
    #
    # **A page is scanned in its OWN file**, not in whichever file `declared`
    # happens to name for it. The two are the same today — no two files under
    # `lib/` declare the same widget class name, measured — but `declared` keeps
    # the FIRST file it sees for a name, so a duplicate would have made the
    # page's own constructions invisible and the page's widgets would have
    # looked unplaced. The failure direction is loud, and this removes it.
    changed = True
    while changed:
        changed = False
        for name in list(placed):
            owner = page_files.get(name) or declared.get(name)
            if owner is None:
                continue
            t = texts[owner]
            for other in declared:
                if other in placed:
                    continue
                if constructs(t, other, name):
                    placed.add(other)
                    changed = True

    orphans = sorted(n for n in declared if n not in placed)

    # An allowlisted entry must actually be unplaced — otherwise the exemption has
    # rotted and is hiding nothing.
    stale_allow = sorted(n for n in ALLOWLIST if n in placed)

    allowed_orphans = [n for n in orphans if n in ALLOWLIST]
    real_orphans = [n for n in orphans if n not in ALLOWLIST]

    print(f"widget classes declared under lib/       : {len(declared)}")
    print(f"root pages (@RoutePage() on a widget)    : {len(pages)}")
    print(f"app root (installs MaterialApp.router)   : {app_root}")
    print(f"reachable from a root                    : {len(placed)}")
    print(f"not placed                              : {len(orphans)}"
          f"  (allowlisted {len(allowed_orphans)}, real {len(real_orphans)})")

    # A file that declares the annotation on something that is not a registered
    # page widget is **not** a root — and it is a **FAILURE**, not a note.
    #
    # It used to print `NOT A ROOT` and exit 0, and the reasoning was "the
    # gate's subject is widgets that are built and never placed, and an
    # annotation nobody routes to places nothing". That is the wrong question:
    # the annotation claims "this is a screen the app can navigate to", and if
    # the app cannot navigate to it then either the annotation is decoration or
    # the registration was forgotten. **Both are defects**, and a gate that
    # prints a diagnostic and exits 0 cannot fail.
    if not_a_root:
        print()
        for line in not_a_root:
            print(f"  NOT A ROOT  {line}")
        print()
        print("Each line above is an `@RoutePage()` that names either a class")
        print("that is not a page widget, or a route the router does not")
        print("register. Register the route, or take the annotation off.")
        print()

    if stale_allow:
        print()
        for n in stale_allow:
            print(f"  STALE ALLOWLIST  {n}  is allowlisted but IS placed — "
                  "remove the entry")
        print()

    if real_orphans:
        print()
        for n in real_orphans:
            print(f"  ORPHAN  {n}  ({declared[n].relative_to(ROOT).as_posix()})")
        print()
        print("Decision 144: a widget with a full test suite and no page that")
        print("instantiates it is invisible to every assertion that does not look")
        print("for it on the screen. Place it, delete it, or allowlist it WITH a")
        print("written reason — never suppress the failure.")
        print()

    # **Every failure is named in the one line that says the gate is red.**
    # Three sections can each be red at once, and a reader who has to guess
    # which one the exit code was about is reading the output wrong.
    failures: list[str] = []
    if not_a_root:
        failures.append(
            f"{len(not_a_root)} file(s) claim a page the app does not have"
        )
    if stale_allow:
        failures.append(f"{len(stale_allow)} allowlist entr(ies) are stale")
    if real_orphans:
        failures.append(
            f"{len(real_orphans)} widget(s) are built and never placed"
        )
    if failures:
        print(f"FAILED — {', and '.join(failures)}.")
        return 1

    print("PASSED — every widget is reachable from a root.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
